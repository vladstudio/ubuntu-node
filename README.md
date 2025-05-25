# Ubuntu Node.js Server Setup Scripts

Automates setting up a fresh Ubuntu 24.04+ server for self-hosting multiple Node.js apps using NVM, Caddy, and Git deployment.

Find the scripts at: https://github.com/vladstudio/ubuntu-node

## Scripts Overview

1.  **`01-initial-setup.sh`**: Initial hardening (user, UFW, fail2ban), essential tools (`git`, `curl`, etc.), unattended upgrades, journald limit, Apache removal.
2.  **`02-locale-setup.sh`**: Configures system locale (UTF-8).
3.  **`03-ssh-setup.sh`**: Sets up SSH key login for the current user, hardens SSHD.
4.  **`04-caddy-setup.sh`**: Installs Caddy, prompts for domain/port and www handling (redirect/serve both/ignore www), configures modular reverse proxy with automatic HTTPS.
5.  **`05-generate-deploy-key.sh`**: Helper script to generate an SSH key pair for accessing private Git repositories and configure the SSH client. Run *before* script 06 if using a private repo.
6.  **`06-nvm-node-setup.sh`**: Installs NVM & Node LTS, creates apps directory structure. Run once per server.
7.  **`07-add-app.sh`**: Deploys Node.js apps with automatic port assignment, isolated directory structure, and independent service management. Use for first app and all additional apps.

## Usage Instructions

**Prerequisites:**
*   Fresh Ubuntu 24.04+ server.
*   Root/sudo access initially.
*   Your personal SSH public key (for script `03-ssh-setup.sh`).
*   Node.js app Git repo URL (use SSH URL for private repos).

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
4.  **Setup locale (optional):**
    ```bash
    cd ~/ubuntu-node # Or the name of the cloned directory
    ./02-locale-setup.sh
    sudo reboot
    ```

5.  **Run Remaining Scripts:**
    ```bash
    cd ~/ubuntu-node # Or the name of the cloned directory
    ./03-ssh-setup.sh      # Paste YOUR PERSONAL PUBLIC key when prompted
    ./04-caddy-setup.sh    # Enter domain for main app, Node.js port

    # --- If using a private github repo ---
    # --- Run this script BEFORE deploying apps ---
    ./05-generate-deploy-key.sh

    # --- Setup Node.js Environment ---
    ./06-nvm-node-setup.sh # Installs NVM & Node LTS

    # --- Deploy Your First App ---
    ./07-add-app.sh        # Enter app name, domain, Git URL, etc.
    ```
    *Follow prompts in each script.*

**Post-Setup:**

*   Apps run via systemd services (`sudo systemctl status <service_name>`).
*   Deploy updates: `ssh` in as the user, `cd <CLONE_PATH>`, `git pull`.
*   Logs: `sudo journalctl -u <service_name> -f` and `/var/log/caddy/<domain_name>.log`.

## Multi-App Management

**Adding Additional Apps:**

After completing the initial setup (scripts 01-06), use script 07 to deploy additional apps:

```bash
./07-add-app.sh # Follow prompts for app name, domain, Git repo
```

**App Structure:**
*   All apps: `~/apps/<app-name>/` (from script 07)
*   Each app gets: unique port (3000+), systemd service (`app-<name>`), Caddy config

**Management Commands:**
*   List all apps: `ls ~/apps/`
*   View app status: `sudo systemctl status app-<name>`
*   View app logs: `sudo journalctl -u app-<name> -f`
*   View Caddy logs: `tail -f /var/log/caddy/<domain>.log`
*   Update app: `cd ~/apps/<app-name> && git pull`

**Port Management:**
*   Ports are auto-assigned starting from 3000
*   Port allocation tracked in `~/.app-ports`
*   Each app binds to its assigned port via environment variable
