# Ubuntu Node.js Server Setup Scripts

This collection of scripts automates the setup of a fresh Ubuntu server for self-hosting a Node.js application using NVM, Caddy, and Git for deployment.

## Scripts Overview

1.  **`01-initial-setup.sh`**:
    *   Performs initial server hardening.
    *   Updates system packages.
    *   Installs essential tools (`git`, `wget`, `curl`, `fail2ban`, `unattended-upgrades`).
    *   Configures `unattended-upgrades` for automatic security updates.
    *   Removes Apache if present.
    *   Sets up UFW firewall rules (allows SSH, HTTP, HTTPS).
    *   Creates a new non-root user with `sudo` privileges.
    *   Enables `fail2ban`.
    *   Limits systemd journal size to 1GB.

2.  **`02-locale-setup.sh`**:
    *   Configures the system locale for optimal UTF-8 compatibility.
    *   Prompts for the desired locale (defaults to `en_US.UTF-8`).

3.  **`03-ssh-setup.sh`**:
    *   Sets up passwordless SSH authentication using a provided public key for the *current user*.
    *   Hardens the SSH server configuration (`/etc/ssh/sshd_config`) by disabling password login and root login.

4.  **`04-caddy-setup.sh`**:
    *   Installs the Caddy web server.
    *   Prompts for a domain name and the Node.js application port.
    *   Configures Caddy as a reverse proxy for the domain, pointing to the Node.js app.
    *   Automatically handles HTTPS certificate acquisition and renewal via Let's Encrypt.

5.  **`05-nvm-node-app.sh`**:
    *   Installs NVM (Node Version Manager) using the latest available version.
    *   Installs the latest LTS (Long-Term Support) version of Node.js.
    *   Prompts for Git repository details, build/start commands, and paths.
    *   Clones the application repository.
    *   Performs an initial build.
    *   Sets up a `systemd` user service to manage the Node.js application (auto-start, auto-restart).
    *   Creates a Git `post-merge` hook to automatically rebuild and restart the application when changes are pulled using `git pull`.

## Usage Instructions

**Prerequisites:**
*   A fresh Ubuntu server instance.
*   Root access or a user with `sudo` privileges for the initial steps.
*   Your SSH public key ready to be pasted.
*   The Git repository URL for your Node.js application.

**Steps:**

1.  **Upload Scripts:** Copy all the `.sh` scripts to the server (e.g., using `scp`).
2.  **Make Executable:** Log in as `root` (or a user with `sudo`) and make the scripts executable:
    ```bash
    chmod +x *.sh
    ```
3.  **Run Initial Setup (as root):**
    ```bash
    ./01-initial-setup.sh
    ```
    *   Follow the prompt to enter a username for the new non-root user.
    *   Set a password for the new user when prompted.
4.  **Log in as New User:** Log out from the `root` session and log back in as the newly created non-root user:
    ```bash
    ssh <new_username>@<your_server_ip>
    ```
5.  **Run Remaining Scripts (as the new user):** Execute the scripts in order. They will use `sudo` internally where necessary.
    ```bash
    ./02-locale-setup.sh # Optional: Configure locale
    ./03-ssh-setup.sh # Configure SSH key login (paste your PUBLIC key)
    ./04-caddy-setup.sh # Configure Caddy reverse proxy
    ./05-nvm-node-app.sh # Install NVM/Node, deploy app
    ```
    *   Follow the prompts within each script (e.g., providing domain names, Git URLs, build commands, etc.).

**Post-Setup:**

*   Your Node.js application should now be running, managed by `systemd`, and accessible via the domain configured in the Caddy script (assuming DNS is set up correctly).
*   To deploy updates, SSH into the server as the non-root user, navigate to the application directory (`cd <CLONE_PATH>`), and run `git pull`. The `post-merge` hook will handle the rebuild and restart.
*   Check the output of each script for any errors or warnings.
*   Monitor application logs using `journalctl --user -u <SERVICE_NAME> -f`.
*   Monitor Caddy logs (path specified in `04-caddy-setup.sh`).
