## About

Ansible roles for deploying my home computers and servers.

## Data Flows

```mermaid
flowchart TD
    GLR(Gitlab Runner<br/>- podman build myimage:latest<br/>- podman push myimage:latest) --> |podman push myimage:latest| GL(Gitlab)

    A(Ansible) --> H(Host<br/>- podman pull myimage:latest<br/>- quadlet myimage:latest)
    GL --> |podman pull myimage:latest| H
```

## Initial State

Generally these playbooks require that the target physical or virtual machine has:
1. Fedora or Fedora Server installed
2. Has a user for ansible to use
3. The user is in the wheel group
4. IP address has been set up
5. openssh has been enabled and allowed through the firewall
5. SSH keys have been set up for the ansible controller to SSH to the host

## Setup for Git Developer Roles

1. Set your git email and user name in inventories/group_vars/developer.yml
```yaml
---
git_config_email: <your git email here>
git_config_user_name: "<your name here>"
```
2. Create your own vault file from example-vault.yml:
```bash
cp ./example-vault.yml ./inventories/group_vars/all/vault.yml
export EDITOR=vim
ansible-vault create ./inventories/group_vars/all/vault.yml
```
3. Edit the variables in the vault to match your own:
```bash
ansible-vault edit ./inventories/group_vars/all/vault.yml
```
All the parts that say "changeme" or "ChangeMe" are placeholder values, for example certificate and private keys:
```yaml
home_assistant_ca_bundle_certificate: |
  -----BEGIN CERTIFICATE-----
  changeme
  -----END CERTIFICATE-----

home_assistant_private_key: |
  -----BEGIN RSA PRIVATE KEY-----
  changeme
  -----END RSA PRIVATE KEY-----
```
You don't have to set up every single variable, only the services you plan on using.

## Machine Preparation

I run this ansible generally against physical machines, but it should work fine for VMs too.
Preparation:
1. Install Fedora Workstation manually (TODO: I really need to boot from HTTPS with kickstart scripts)
2. Set a static IP
3. Create a user for ansible and add it to the sudo group
4. Turn on SSH and add a firewall rule for SSH
5. Set up SSH keys with ssh-copy-id and test SSH from the ansible controller to the machine
6. Update inventory/network_home.ini to match your machine, IP address, ansible user

## Certificates

### Self-signed Certificates

1. Generate self-signed certificates and add them to the encrypted vault.yml:
```bash
./scripts/generate_self_signed_certificates.sh
```

### Let's Encrypt Certificates

For some of the more sensitive services I use Let's Encrypt with certbot and a cloudflare domain, but it is quite manual because I have to generate certificates, add them to the ansible, then redeploy the service.

**NOTE: Only some services require this, I only use it for Gitlab, VaultWarden, and Home Assistant**

#### Setup

On the machine that you edit your ansible on:
```bash
sudo dnf install python3 pip3 python3-virtualenv augeas-libs
virtualenv --python=python3 myenv
pip install certbot certbot-dns-cloudflare cloudflare
```

#### Certificate Generation/Renewal

Create an ini file for your certificates:
scripts/lets_encrypt/certbot-mydomain.com.ini
```bash
dns_cloudflare_api_token = REPLACE WITH API TOKEN FROM https://dash.cloudflare.com/profile/api-tokens YOU WANT A "Zone.DNS" TOKEN FOR YOUR DOMAIN
```

Generate the certificates:
```bash
./scripts/generate_lets_encrypt_certificate.sh homeassistant.mydomain.com home_assistant_ca_bundle_certificate home_assistant_private_key
```

## Usage Examples

```bash
sudo dnf install ansible ansible-collection-containers-podman
```

```bash
ansible-playbook -i inventories/network_home.ini -l chris_linux_computer -K --ask-vault-pass playbooks/setup-desktop.yml
```

```bash
ansible-playbook -i inventories/network_home.ini -l fileserver.network.home -K --ask-vault-pass playbooks/setup-server.yml
ansible-playbook -i inventories/network_home.ini -l homeassistant.iluo.xyz -K --ask-vault-pass playbooks/setup-server.yml
```

```bash
ansible-playbook -i inventories/network_home.ini -l homeassistant.iluo.xyz -K --ask-vault-pass playbooks/setup-podman-and-services.yml
ansible-playbook -i inventories/network_home.ini -l chris_linux_computer -K --ask-vault-pass playbooks/setup-podman-and-services.yml
```

## Debugging Podman Containers

Check the service file that was generated and check that podman is being called correctly:
```bash
cat .config/systemd/user/homeassistant-container.service
```

Show the output of a user container:
```bash
journalctl -f
```
OR
```bash
podman logs -f gitlab
```

Start, stop, or check the status a user container:
```bash
systemctl --user start/stop/status homeassistant-container
```

Check the groups that a user is in (Note: dialout for access to /dev/ttyUSB0 or /dev/ttyACM0):
```bash
$ groups
homeassistant wheel dialout
```

Show the output of a user service:
```bash
journalctl --user -f -u homeassistant-container
```

Debugging Home Assistant configuration changes:
```bash
systemctl --user restart homeassistant-container
tail -F srv/homeassistant/config/home-assistant.log
```

For docker-compose.yml containers, start it manually:
```bash
/usr/bin/podman-compose up --remove-orphans
```

For docker-compose.yml containers, start it manually with verbose logging:
```bash
/usr/bin/podman-compose --verbose up --remove-orphans
```

## General Podman Container Administration

When upgrading the version or changing the settings of a container you can just run the `playbooks/setup-podman-and-services.yml` playbook, but I prefer to stop the container manually and perform a backup before redeploying it, for example:
```bash
ssh vaultwarden@<ip>
$ systemctl --user stop vaultwarden-container
$ (cd srv && zip -r vaultwarden20231104.zip ./vaultwarden)
```
Now you can run the `playbooks/setup-podman-and-services.yml` playbook to upgrade the version or update the settings.

## Vaultwarden Administration

When the admin page is enabled you can log in here to change the configuration:
```
https://vaultwarden.network.home:4443/admin
```

## Gitlab Administration

Get the initial root (Administrator) user password for the gitlab web interface (As the gitlab container user):
```bash
$ podman exec -it gitlab grep 'Password:' /etc/gitlab/initial_root_password
Password: e3bvA0wciJup5epRQKX31pDE+H6hp3dZBY8llbpF3bY=
```

**NOTE: When updating the gitlab version remember to upgrade between the official upgrade paths as documented in roles/podman_gitlab/defaults/main.yml**

## Home Assistant Administration

Reset Home Assistant user password by execing into the container, changing the password, exiting and restarting the container:
```bash
podman exec -ti homeassistant /bin/bash
$ hass --script auth --config /config change_password chris mytemporarypassword
$ exit
systemctl --user restart homeassistant-container
```
Then log in via the web interface and change it to a real password (This ensures that the real password is not added to the bash history, even temporarily).
