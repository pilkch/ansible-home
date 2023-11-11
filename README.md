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
ansible-vault create host_vars/myhost/vault.yml
```
OR
```bash
ansible-vault edit host_vars/myhost/vault.yml
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
ansible-playbook -i inventories/network_home.ini -l homeassistant.network.home -K playbooks/setup-podman-and-services.yml
ansible-playbook -i inventories/network_home.ini -l chris_linux_computer -K playbooks/setup-podman-and-services.yml
```

```bash
ansible-playbook -i inventories/network_home.ini -l chris_linux_computer -K playbooks/setup-developer.yml
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

## Notes

The ansible doesn't deploy the docker compose files for Gitlab, vaultwarden, etc.
