## About

Ansible roles for deploying my home computers and servers.

## Setup

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

## Usage

```bash
ansible-playbook -i inventories/network_home.ini -l myhost --ask-vault-pass developer.yml
```
