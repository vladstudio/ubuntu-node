#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "--- Starting Caddy Setup ---"

# --- Install Caddy ---
# Check if Caddy is already installed
if ! command -v caddy &> /dev/null; then
    echo "--- Installing Caddy web server..."
    sudo apt update
    sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null
    sudo apt update
    sudo apt install -y caddy
else
    echo "--- Caddy is already installed."
    # Ensure it's the latest version
    sudo apt update
    sudo apt install --only-upgrade -y caddy
fi
caddy version

# --- Configure Caddyfile ---
echo "--- Configuring Caddyfile (/etc/caddy/Caddyfile)..."

# Create conf.d directory for modular configs
CADDY_CONF_DIR="/etc/caddy/conf.d"
sudo mkdir -p "$CADDY_CONF_DIR"

# Create main Caddyfile that imports all configs
MAIN_CADDYFILE_CONTENT="# Main Caddyfile - imports all app configurations
import $CADDY_CONF_DIR/*.conf
"

# Write the main Caddyfile
echo "$MAIN_CADDYFILE_CONTENT" | sudo tee /etc/caddy/Caddyfile > /dev/null


# --- Ensure Firewall Rules ---
echo "--- Ensuring UFW allows HTTP and HTTPS traffic..."
# These should already be allowed by 01-initial-setup.sh, but we double-check
sudo ufw allow http
sudo ufw allow https
sudo ufw status verbose | grep -E '80/tcp|443/tcp' || echo "Warning: Ports 80/443 might not be open in UFW."


echo "--- Validating Caddy configuration..."
# Use sudo to run as root, necessary for reading /etc/caddy/Caddyfile
if sudo caddy validate --config /etc/caddy/Caddyfile; then
    echo "--- Caddy configuration validation successful."
    echo "--- Creating Caddy logs directory..."
    sudo mkdir -p /var/log/caddy
    sudo chown caddy:caddy -R /var/log/caddy
    sudo chmod 755 -R /var/log/caddy
    echo "--- Reloading Caddy service..."
    sudo systemctl reload caddy
else
    echo "--- ERROR: Caddy configuration validation failed. Please check /etc/caddy/Caddyfile manually. Caddy service was not reloaded."
    exit 1
fi

echo
echo "--- --------------------------"
echo "--- Caddy Setup Complete ---"
echo "Caddy web server is installed and configured with:"
echo "- Main configuration: /etc/caddy/Caddyfile"
echo "- App configurations directory: /etc/caddy/conf.d/"
echo "- Log directory: /var/log/caddy/"
echo "NEXT STEPS:"
echo "1. Run script 07-add-app.sh to deploy your first Node.js application"
echo "2. Caddy will automatically obtain and renew SSL certificates via Let's Encrypt"
echo "--- --------------------------"
echo

exit 0
