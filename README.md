## About

Ansible roles for deploying my home computers and servers.

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

## Usage Examples

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
