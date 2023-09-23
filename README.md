## About

Ansible roles for deploying my home computers and servers.

## Setup for Git Developer Roles

1. Set your git email and user name in inventories/group_vars/developer.yml
```yaml
---
git_config_email: <your git email here>
git_config_user_name: "<your name here>"
```
2. Create or edit a vault for each host which needs the git certificate and key
```bash
ansible-vault create host_vars/myhost/git_vault.yml
```
OR
```bash
ansible-vault edit host_vars/myhost/git_vault.yml
```
3. Add the certificate and private keys as variables:
```yaml
---
git_certificate: |
  -----BEGIN CERTIFICATE-----
  ...
  -----END CERTIFICATE-----

git_private_key: |
  -----BEGIN PRIVATE KEY-----
  ...
  -----END PRIVATE KEY-----
```

## Usage Examples

```bash
ansible-playbook -i inventories/network_home.ini -l fileserver.network.home -K playbooks/setup-server.yml
ansible-playbook -i inventories/network_home.ini -l homeassistant.network.home -K playbooks/setup-server.yml
```

```bash
ansible-playbook -i inventories/network_home.ini -l chris_linux_computer -K playbooks/setup-developer.yml
```

## Debugging

Show the output of a user container:
```bash
journalctl -f
```

Start, stop, or check the status a user container:
```bash
systemctl --user start/stop/status homeassistant-container
```

Check the groups that a user is in (Note: dialot for access to /dev/ttyUSB0 or /dev/ttyACM0):
```bash
$ groups
homeassistant wheel dialout
```

## Notes

The ansible doesn't deploy the docker compose files for Gitlab, vaultwarden, etc.
