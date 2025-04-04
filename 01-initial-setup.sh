#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- User Input ---
read -p "Enter the username for the new non-root user: " NEW_USERNAME
if [ -z "$NEW_USERNAME" ]; then
    echo "Username cannot be empty. Exiting."
    exit 1
fi

echo "--- Starting Initial Server Setup ---"

echo "Updating system packages..."
sudo apt update
sudo apt upgrade -y

echo "Installing essential tools (git, wget, curl, fail2ban, unattended-upgrades)..."
sudo apt install -y git wget curl fail2ban micro unattended-upgrades

echo "Configuring automatic security updates..."
sudo dpkg-reconfigure --priority=low unattended-upgrades

# Check if apache2 service exists and is active before trying to remove
if systemctl list-units --type=service --all | grep -q 'apache2.service'; then
    echo "Removing Apache..."
    sudo systemctl stop apache2
    sudo apt purge -y apache2 apache2-utils
    sudo apt autoremove -y
fi

# Check if user already exists
if id "$NEW_USERNAME" &>/dev/null; then
    echo "User '$NEW_USERNAME' already exists. Skipping creation."
else
    echo "Creating new user '$NEW_USERNAME'..."
    sudo adduser --disabled-password --gecos "" "$NEW_USERNAME"
    echo "Set password for user '$NEW_USERNAME':"
    sudo passwd "$NEW_USERNAME"
    sudo usermod -aG sudo "$NEW_USERNAME"

    # --- Move scripts to new user's home directory ---
    echo "Moving setup scripts to /home/$NEW_USERNAME/ubuntu-node..."
    # Assuming the script is run from the cloned 'ubuntu-node' directory
    SCRIPT_DIR_NAME=$(basename "$PWD") # Should be 'ubuntu-node'
    TARGET_DIR="/home/$NEW_USERNAME/$SCRIPT_DIR_NAME"
    # Move the current directory (where the script is running from)
    sudo mv "$PWD" "/home/$NEW_USERNAME/"
    # Change ownership to the new user
    sudo chown -R "$NEW_USERNAME:$NEW_USERNAME" "$TARGET_DIR"
    echo "Scripts moved and ownership set for $NEW_USERNAME."
fi

echo "Configuring UFW firewall..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH # Allow SSH (port 22)
sudo ufw allow http    # Allow HTTP (port 80)
sudo ufw allow https   # Allow HTTPS (port 443)
echo "y" | sudo ufw enable
sudo ufw status

echo "Enabling and starting Fail2ban..."
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
sudo systemctl status fail2ban --no-pager

# --- Configure Journald Size Limit ---
echo "Configuring systemd journal size limit..."
JOURNALD_CONF="/etc/systemd/journald.conf"
# Check if SystemMaxUse is already set (commented or uncommented)
if sudo grep -qE "^\s*#?\s*SystemMaxUse=" "$JOURNALD_CONF"; then
    # Uncomment and set the value
    sudo sed -i -E "s/^\s*#?\s*(SystemMaxUse=).*/\11G/" "$JOURNALD_CONF"
    echo "Set SystemMaxUse=1G in $JOURNALD_CONF"
else
    # Add the setting if it doesn't exist at all
    echo "[Journal]" | sudo tee -a "$JOURNALD_CONF" > /dev/null
    echo "SystemMaxUse=1G" | sudo tee -a "$JOURNALD_CONF" > /dev/null
    echo "Added SystemMaxUse=1G to $JOURNALD_CONF"
fi
# Restart journald service to apply changes
sudo systemctl restart systemd-journald
echo "Systemd journald service restarted."

echo "Fetching public IPv4 address..."
# Use curl -4 to force IPv4; provide fallback
SERVER_IP=$(curl -4 -s ifconfig.me || echo "your_server_ip")
echo "Detected public IPv4: $SERVER_IP"

echo "--- Initial Server Setup Complete ---"
echo "IMPORTANT: To continue, log out and log back in as the new user '$NEW_USERNAME'."
echo "Example: ssh $NEW_USERNAME@$SERVER_IP"

exit 0
