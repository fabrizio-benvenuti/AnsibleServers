Role to install and run n8n with Docker Compose (Traefik) on Debian/Raspbian hosts.

This role will:
- Install Docker Engine and Docker Compose (plugin) using APT where possible.
- Ensure the configured user is in the docker group.
- Create a project directory under /opt/n8n-compose with .env and compose.yaml from templates.
- Provide a systemd service to ensure docker compose is started on boot.

Notes:
- This role assumes the host has network access to Docker repositories and that APT is the package manager.
- Adjust variables in defaults/main.yml to suit your environment (DOMAIN_NAME, SUBDOMAIN, SSL_EMAIL, N8N_USER).
