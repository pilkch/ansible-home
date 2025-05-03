#!/bin/bash -xe

source ./scripts/yaml_helpers.sh

function print_usage {
  echo "Usage: ./scripts/generate_lets_encrypt_certificate.sh VAULT_PASSWORD_FILE HOST_FQDN VARIABLE_NAME_CERTIFICATE VARIABLE_NAME_PRIVATE_KEY"
  echo "Generates Let's Encrypt certificates for a single services and add it to the encrypted ansible ./inventories/group_vars/all/vault.yml file"
  echo ""
  echo "Example:"
  echo "./scripts/generate_lets_encrypt_certificate.sh ./vault-password.txt homeassistant.mydomain.com home_assistant_ca_bundle_certificate home_assistant_private_key"
  echo ""
  echo "Note: This will request certificates via certbot and add them to the vault, overwriting them if they already exist."
}

function generate_certbot_certificates {
  CERT_FILE_PATH="letsencrypt/config/live/$DOMAIN/fullchain.pem"
  PRIVATE_KEY_FILE_PATH="letsencrypt/config/live/$DOMAIN/privkey.pem"
  if [ -f "" ]; then
    EXISTING_CERT_MD5=$(md5sum "$CERT_FILE_PATH" | cut -d' ' -f1)
    EXISTING_KEY_MD5=$(md5sum "$PRIVATE_KEY_FILE_PATH" | cut -d' ' -f1)
  fi

  certbot certonly --non-interactive --dns-cloudflare --dns-cloudflare-credentials ./scripts/lets_encrypt/certbot-$DOMAIN.ini --config-dir ./letsencrypt/config --work-dir ./letsencrypt/working --logs-dir ./letsencrypt/logs -d $HOST_FQDN

  NEW_CERT_MD5=$(md5sum "$CERT_FILE_PATH" | cut -d' ' -f1)
  NEW_KEY_MD5=$(md5sum "$PRIVATE_KEY_FILE_PATH" | cut -d' ' -f1)

  # If the new certificate or private has changed then update the vault
  if [ "$NEW_CERT_MD5" != "$EXISTING_CERT_MD5" ] || [ "$NEW_KEY_MD5" != "$EXISTING_KEY_MD5" ]; then
    # Set the variables in the yaml file from the certificate and private key files contents
    set_yaml_value_from_file_contents $VAULT_FILE_DECRYPTED $VARIABLE_NAME_CERTIFICATE $CERT_FILE_PATH
    set_yaml_value_from_file_contents $VAULT_FILE_DECRYPTED $VARIABLE_NAME_PRIVATE_KEY $PRIVATE_KEY_FILE_PATH
  else
    echo "New keys were not generated, not changing the vault"
  fi
}

function decrypt_generate_encrypt {
  # Assume failure
  local RESULT=1

  # Decrypt the vault file
  ansible-vault decrypt --vault-password-file "$VAULT_PASSWORD_FILE" --output "$VAULT_FILE_DECRYPTED" "$VAULT_FILE_ENCRYPTED"
  if [ ! -f "$VAULT_FILE_DECRYPTED" ]; then
    echo "Error decrypting vault file"
  else
    PREVIOUS_VAULT_MD5=$(md5sum "$VAULT_FILE_DECRYPTED" | cut -d' ' -f1)

    # Generate certbot certificates
    if ! generate_certbot_certificates; then
      echo "Error generating certbot certificates"
    else
      NEW_VAULT_MD5=$(md5sum "$VAULT_FILE_DECRYPTED" | cut -d' ' -f1)
      if [ "$NEW_VAULT_MD5" == "$PREVIOUS_VAULT_MD5" ]; then
        # No changes, treat this as success
        RESULT=0
      else
        # There have been updates, so we need to encrypt the new vault file
        ansible-vault encrypt --vault-password-file "$VAULT_PASSWORD_FILE" --output "$VAULT_FILE_ENCRYPTED" "$VAULT_FILE_DECRYPTED"
        if [ ! -f "$VAULT_FILE_ENCRYPTED" ]; then
          echo "Error encrypting vault file"
        else
          RESULT=0
        fi
      fi
    fi
  fi

  return $RESULT
}

VAULT_PASSWORD_FILE="$1"
HOST_FQDN="$2"
VARIABLE_NAME_CERTIFICATE="$3"
VARIABLE_NAME_PRIVATE_KEY="$4"

if [ "$HOST_FQDN" == "" ] || [ "$VAULT_PASSWORD_FILE" == "" ] || [ "$VARIABLE_NAME_CERTIFICATE" == "" ] || [ "$VARIABLE_NAME_PRIVATE_KEY" == "" ]; then
  # Print the usage and exit
  print_usage
  exit 1
fi

# Get the domain (Everything after the first dot)
DOMAIN=${HOST_FQDN#*.}

if [ "$DOMAIN" == "" ]; then
  # Print the usage and exit
  print_usage
  exit 1
fi

VAULT_FILE_ENCRYPTED=./inventories/group_vars/all/vault.yml
TEMP_FOLDER=./.generate_certbot_certificates_temp
VAULT_FILE_DECRYPTED="$TEMP_FOLDER/vault.decrypted.yml"

# Check that certbot is installed
if ! command -v certbot 2>&1 >/dev/null
then
  echo "certbot is not installed"
  exit 1
fi

# Check if we actually have certbot ini file
if [ ! -e "./scripts/lets_encrypt/certbot-$DOMAIN.ini" ]; then
  echo "ini file \"./scripts/lets_encrypt/certbot-$DOMAIN.ini\" not found, please create an ini file first"
  exit 1
fi

# Check that yq is installed
if ! command -v yq 2>&1 >/dev/null
then
    echo "yq is not installed"
    exit 1
fi

# Check if we actually have a vault file
if [ ! -e "$VAULT_FILE_ENCRYPTED" ]; then
  echo "Vault file \"$VAULT_FILE_ENCRYPTED\" not found, please create a vault file first"
  exit 1
fi

# Recreate the temporary directory
rm -rf "$TEMP_FOLDER" || true
mkdir -p "$TEMP_FOLDER" || true

# Make a backup of the vault file (We don't want to trash the user's data)
DATE=$(date '+%Y%m%d')
cp "$VAULT_FILE_ENCRYPTED" "$VAULT_FILE_ENCRYPTED.backup$DATE"

# Decrypt the vault file, generate the certbot certificates and encrypt the vault file again
decrypt_generate_encrypt
FINAL_RESULT=$?

# Delete the decrypted vault file
rm -rf "$TEMP_FOLDER"

exit $FINAL_RESULT
