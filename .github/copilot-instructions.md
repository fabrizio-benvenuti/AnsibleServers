# Copilot instructions for this repo (AnsibleServers)

## What this repo is
- An Ansible mono-repo that configures a Raspberry Pi and two NAS servers via playbooks `raspberry.yml` and `setup.yml` using host inventory in `inventory.ini`.
- Roles provide the building blocks: `common` (Tailscale), `netplan` (static networking), `cups` (CUPS print server), `AP` (hostapd + dnsmasq + iptables NAT), `wake_on_lan` (Flask web UI + timers), `n8n_docker` (n8n + Traefik via Docker Compose), and `zfs` (pool/datasets).

## How it’s structured (files to know)
- Top-level: `ansible.cfg` (become via su; prompts for become password), `inventory.ini` (3 hosts under [servers]).
- Vars: `group_vars/all/vault.yml` (Ansible Vault secrets), `host_vars/*` (per-host, e.g., ZFS pool layout for server1/2).
- Playbooks:
  - `raspberry.yml` -> roles: `common, netplan, wake_on_lan, AP, n8n_docker` on host `raspberrypi`.
  - Now also includes `cups` for print server setup.
  - `setup.yml` -> role: `zfs` on hosts `server1,server2`.
- Roles pattern: each role’s `tasks/main.yml` imports task files and assigns matching `tags` (e.g., `roles/netplan/tasks/main.yml` tags `configure_netplan`). Handlers live in `handlers/main.yml`.

## Run and debug (commands you’ll actually use)
- Use vault and become: pass `--ask-vault-pass`. `ansible.cfg` sets `ask_become_pass=true` and `become_method=su`.
- Run Raspberry Pi playbook (all roles):
  ```bash
  ansible-playbook -i inventory.ini raspberry.yml --ask-vault-pass
  ```
- Target a role by tag (pattern used across roles):
  ```bash
  ansible-playbook -i inventory.ini raspberry.yml --ask-vault-pass -t configure_netplan
  ```
- Run NAS setup for a single host:
  ```bash
  ansible-playbook -i inventory.ini setup.yml --ask-vault-pass --limit server1
  ```

## Conventions and cross-cutting patterns
- Tagging: imported task filenames are the tags you can target (e.g., `configure_dnsmasq`, `configure_hostapd`, `configure_ip_NAT`, `install_and_setup`, `configure_services`, `configure_webserver`, `n8n`, `docker`, `tailscale`).
  - New: `cups` role uses `install_and_configure` (run with `-t install_and_configure`).
    - `cups_manage_server_conf` lets you skip templating `cupsd.conf` if you want to manage it manually via the web UI.
- Host-specific files: netplan copies `roles/netplan/files/etc/netplan/99-netplan-<inventory_hostname>.yaml` to `/etc/netplan/` and then notifies handler to `netplan apply` and restart `systemd-networkd`.
- Vault: sensitive vars live in `group_vars/all/vault.yml`. The wake-on-lan templates expect `web_users` and `flask_secret_key`. The inventory references `ansible_become_password_*` from vault.
- Idempotency nuances that affect re-runs:
  - `AP` role appends iptables rules via `shell`. Re-running can duplicate rules; current role relies on `iptables-persistent` and a final `iptables-save` handler.
  - `common/tailscale.yml` performs `tailscale up` and prints a login URL via `debug`; you must authorize the device in the browser once.

## Role-specific integration notes (where to look)
- AP (Wi‑Fi hotspot + DHCP):
  - Dnsmasq: `roles/AP/files/etc/dnsmasq.conf`, resolv: `roles/AP/files/etc/resolv.conf`.
  - Hostapd: template `roles/AP/templates/etc/hostapd/hostapd.conf.j2` requires `ap_ssid` and `ap_password`.
- Wake-on-LAN web UI:
  - Python app templated to `/opt/webserver` (`templates/app.py.j2`, `auth.py.j2`); static and Jinja templates under `roles/wake_on_lan/files/opt/webserver/`.
  - Systemd service `webserver.service` is created and enabled; SSL cert/key copied from role files to `/opt/webserver` (mode 0600).
  - Power scripts and timers under `roles/wake_on_lan/files/etc/systemd/system/*.service|*.timer` and `/init/power_{on,off}.sh`.
- n8n + Traefik:
  - Templates in `roles/n8n_docker/templates/{compose.yaml.j2,env.j2}`. Override defaults in `roles/n8n_docker/defaults/main.yml` via host/group vars as needed (domain/subdomain/timezone/ports/user).
- ZFS:
  - Uses `host_vars/server*.yml` to define `zfs_pools` and child `datasets`. Tasks import pools, create datasets, set mountpoints/ownership, and ensure mount at boot.
 - CUPS:
   - Role at `roles/cups` installs `cups`, templates `etc/cups/cupsd.conf.j2`, and restarts the service via handler.
   - Defaults (`roles/cups/defaults/main.yml`): `cups_listen_all` (true for Port 631 on all interfaces), `cups_allow_from` (e.g., `@LOCAL`, `192.168.1.0/24`), `cups_server_admin`, and `cups_admin_user` (added to `lpadmin`).
   - Target just CUPS with: `ansible-playbook -i inventory.ini raspberry.yml --ask-vault-pass -t install_and_configure`.
    - Install drivers without managing printers: set `cups_printers: []` and rely on `cups_extra_packages` (e.g., `printer-driver-splix`); set `cups_manage_server_conf: false` to keep `cupsd.conf` manual.

## Adding or modifying hosts (follow this repo’s pattern)
- Add host to `inventory.ini` with `ansible_user`, `ansible_ssh_private_key_file`, and an `ansible_become_password_*` reference.
- Provide `host_vars/<host>.yml` as needed (e.g., `zfs_pools`), and create a matching netplan file under `roles/netplan/files/etc/netplan/99-netplan-<host>.yaml`.

## Safe edits for agents
- Preserve tag names and handler names (automation relies on them).
- Prefer Ansible modules over `shell` when changing behavior; but if you touch iptables in `AP`, keep the current append/save behavior unless explicitly refactoring the role.
- When extending wake-on-lan, keep file ownerships `fabrizio:fabrizio` and paths under `/opt/webserver` consistent with current tasks.
