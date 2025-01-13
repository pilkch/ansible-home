#!/bin/bash -xe

source ./scripts/yaml_helpers.sh

function print_usage {
  echo "Usage: ./scripts/generate_self_signed_certificates.sh"
  echo "Generates self signed certificates for the various services and adds them to the encrypted ansible ./inventories/group_vars/all/vault.yml file"
  echo ""
  echo "Edit ./inventories/group_vars/all/all.yml to reflect your environment"
  echo "./scripts/generate_self_signed_certificates.sh"
  echo "You will be asked to enter your vault password"
  echo ""
  echo "Note: This will only generate certificate variables for certificate variables that don't exist in the vault already. To regenerate a particular set of certificates variables, delete them from the encrypted ansible vault file, then run generate_self_signed_certificates.sh again."
}

function check_and_generate_self_signed_certificates {
  local VARIABLE_NAME_CERTIFICATE="$1"
  local VARIABLE_NAME_PRIVATE_KEY="$2"
  local VARIABLE_NAME_FQDN="$3"

  local CERT_COMMON_NAME=$(yq ".$VARIABLE_NAME_FQDN" "./inventories/group_vars/all/all.yml")
  echo "CERT_COMMON_NAME=\"$CERT_COMMON_NAME\""

  # If the certificate variables aren't present yet then generate and add them
  if ! yq -e ".$VARIABLE_NAME_CERTIFICATE" "$VAULT_FILE_DECRYPTED" || ! yq -e ".$VARIABLE_NAME_PRIVATE_KEY" "$VAULT_FILE_DECRYPTED" ; then
    # Create a config file for generating this certificate
    CERT_CONFIG_FILE="$TEMP_FOLDER/certificates.conf"
    cp -f "$CERT_CONFIG_TEMPLATE_FILE" "$CERT_CONFIG_FILE"
    echo "commonName = $CERT_COMMON_NAME" >> "$CERT_CONFIG_FILE"

    # Generate our certificate
    CERT_FILE_PATH="$TEMP_FOLDER/$VARIABLE_NAME_CERTIFICATE.crt"
    PRIVATE_KEY_FILE_PATH="$TEMP_FOLDER/$VARIABLE_NAME_PRIVATE_KEY.key"
    openssl req -new -newkey rsa:4096 -x509 -sha256 -days 365 -nodes -config "$CERT_CONFIG_FILE" -out "$CERT_FILE_PATH" -keyout "$PRIVATE_KEY_FILE_PATH"

    # Set the variables in the yaml file from the certificate and private key files contents
    set_yaml_value_from_file_contents $VAULT_FILE_DECRYPTED $VARIABLE_NAME_CERTIFICATE $CERT_FILE_PATH
    set_yaml_value_from_file_contents $VAULT_FILE_DECRYPTED $VARIABLE_NAME_PRIVATE_KEY $PRIVATE_KEY_FILE_PATH
  fi
}

function generate_all_self_signed_certificates {
  echo "Generate self signed certificates"

  # NOTE: The variables we are adding are mostly only useful when you want a pair because a specific client wants to connect to a specific server, such as syslog-ng forwarding to another syslog-ng server via TLS

  check_and_generate_self_signed_certificates syslogng_server_certificate syslogng_server_private_key syslogng_fqdn
}

function decrypt_generate_encrypt {
  # Assume failure
  local RESULT=1

  # Decrypt the vault file
  ansible-vault decrypt --vault-password-file "$VAULT_PASSWORD_FILE" --output "$VAULT_FILE_DECRYPTED" "$ENCYPTED_VAULT_FILE"
  if [ ! -f "$VAULT_FILE_DECRYPTED" ]; then
    echo "Error decrypting vault file"
  else
    # Generate self signed certificates
    if ! generate_all_self_signed_certificates; then
      echo "Error generating self signed certificates"
    else
      # Encrypt the vault file
      ansible-vault encrypt --vault-password-file "$VAULT_PASSWORD_FILE" --output "$ENCYPTED_VAULT_FILE" "$VAULT_FILE_DECRYPTED"
      if [ ! -f "$ENCYPTED_VAULT_FILE" ]; then
        echo "Error encrypting vault file"
      else
        RESULT=0
      fi
    fi
  fi

  return $RESULT
}


FIRST_ARGUMENT="$1"
if [ "$FIRST_ARGUMENT" != "" ]; then
  # Print the usage and exit
  print_usage
  exit 0
fi

ENCYPTED_VAULT_FILE=./inventories/group_vars/all/vault.yml
TEMP_FOLDER=./.generate_self_signed_certificates_temp
VAULT_FILE_DECRYPTED="$TEMP_FOLDER/vault.decrypted.yml"
VAULT_PASSWORD_FILE="$TEMP_FOLDER/vault_password_file.txt"
CERT_CONFIG_TEMPLATE_FILE="./scripts/certificates.conf.template"

# Check that yq is installed
if ! command -v yq 2>&1 >/dev/null
then
    echo "yq is not installed"
    exit 1
fi

# Check if we actually have a vault file
if [ ! -e "$ENCYPTED_VAULT_FILE" ]; then
  echo "Vault file \"$ENCYPTED_VAULT_FILE\" not found, please create a vault file first"
  exit 1
fi

# Recreate the temporary directory
rm -rf "$TEMP_FOLDER" || true
mkdir -p "$TEMP_FOLDER" || true

# Ask for the vault password
echo -n Password: 
read -s VAULT_PASSWORD
echo

# Create a password file (Eww)
echo "$VAULT_PASSWORD" > "$VAULT_PASSWORD_FILE"

# Clear the vault password from memory (Maybe there is a more thorough way of doing this?)
VAULT_PASSWORD=""

# Make a backup of the vault file (We don't want to trash the user's data)
DATE=$(date '+%Y%m%d')
cp "$ENCYPTED_VAULT_FILE" "$ENCYPTED_VAULT_FILE.backup$DATE"

# Decrypt the vault file, generate the self signed certificates and encrypt the vault file again
decrypt_generate_encrypt
FINAL_RESULT=$?

# Delete the decrypted vault file and vault password file
rm -rf "$TEMP_FOLDER"

exit $FINAL_RESULT
