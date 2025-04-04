# Ubuntu Node.js Server Setup Scripts

Automates setting up a fresh Ubuntu server for self-hosting Node.js apps using NVM, Caddy, and Git deployment.

Find the scripts at: https://github.com/vladstudio/ubuntu-node

## Scripts Overview

1.  **`01-initial-setup.sh`**: Initial hardening (user, UFW, fail2ban), essential tools (`git`, `curl`, etc.), unattended upgrades, journald limit, Apache removal.
2.  **`02-locale-setup.sh`**: Configures system locale (UTF-8).
3.  **`03-ssh-setup.sh`**: Sets up SSH key login for the current user, hardens SSHD.
4.  **`04-caddy-setup.sh`**: Installs Caddy, prompts for domain/port and www handling (redirect/serve both/ignore www), configures reverse proxy with automatic HTTPS.
5.  **`05-nvm-node-app.sh`**: Installs NVM & Node LTS, clones Git repo, sets up systemd user service, adds `post-merge` hook for auto-rebuild/restart on `git pull`.

## Usage Instructions

**Prerequisites:** Fresh Ubuntu server, root/sudo access initially, SSH public key, Node.js app Git repo URL.

**Steps:**

1.  **Download & Prepare (as root):**
    ```bash
    apt update && apt install -y git
    git clone https://github.com/vladstudio/ubuntu-node.git
    cd ubuntu-node
    chmod +x *.sh
    ```
2.  **Run Initial Setup (as root):**
    ```bash
    ./01-initial-setup.sh # Follow prompts for new username/password
    ```
3.  **Log out, then log in as the new user:**
    ```bash
    ssh <new_username>@<server_ipv4_address> # Script 01 attempts to show the IPv4
    ```
4.  **Run Remaining Scripts:**
    ```bash
    cd ~/ubuntu-node # Or the name of the cloned directory
    ./02-locale-setup.sh # Optional
    ./03-ssh-setup.sh    # Paste PUBLIC key when prompted
    ./04-caddy-setup.sh    # Enter domain, Node.js port
    ./05-nvm-node-app.sh # Enter Git URL, paths, commands
    ```
    *Follow prompts in each script.*

**Post-Setup:**

*   App runs via systemd user service (`systemctl --user status <service_name>`).
*   Deploy updates: `ssh` in as the user, `cd <CLONE_PATH>`, `git pull`.
*   Logs: `journalctl --user -u <service_name> -f` and `/var/log/caddy/<domain_name>.log`.
