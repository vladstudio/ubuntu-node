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

echo "Installing essential tools (git, wget, curl, fail2ban)..."
sudo apt install -y git wget curl fail2ban micro

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

echo "Fetching public IP address..."
# Use curl (installed earlier) to get the public IP; provide fallback
SERVER_IP=$(curl -s ifconfig.me || echo "your_server_ip")
echo "Detected public IP: $SERVER_IP"

echo "--- Initial Server Setup Complete ---"
echo "IMPORTANT: To continue, log out and log back in as the new user '$NEW_USERNAME'."
echo "Example: ssh $NEW_USERNAME@$SERVER_IP"

exit 0
