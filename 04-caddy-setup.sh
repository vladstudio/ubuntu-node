#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- User Input ---
read -p "Enter the domain name for your application (e.g., myapp.example.com): " DOMAIN_NAME
if [ -z "$DOMAIN_NAME" ]; then
    echo "--- Domain name cannot be empty. Exiting."
    exit 1
fi

DEFAULT_NODE_PORT="3000"
read -p "Enter the port your Node.js app will listen on [default: $DEFAULT_NODE_PORT]: " NODE_PORT
NODE_PORT=${NODE_PORT:-$DEFAULT_NODE_PORT}

# Validate port is a number
if ! [[ "$NODE_PORT" =~ ^[0-9]+$ ]]; then
    echo "--- Invalid port number. Exiting."
    exit 1
fi

# --- WWW Handling Input ---
echo "How should the 'www' subdomain (www.$DOMAIN_NAME) be handled?"
echo "  1) Redirect www.$DOMAIN_NAME to $DOMAIN_NAME (Recommended)"
echo "  2) Redirect $DOMAIN_NAME to www.$DOMAIN_NAME"
echo "  3) Serve both www.$DOMAIN_NAME and $DOMAIN_NAME (No redirect)"
echo "  4) Only serve $DOMAIN_NAME (Ignore www)"
read -p "Enter choice [1]: " WWW_CHOICE
WWW_CHOICE=${WWW_CHOICE:-1}

echo "--- Starting Caddy Setup for $DOMAIN_NAME proxying to localhost:$NODE_PORT ---"

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

# Generate Caddyfile based on www choice
CADDYFILE_CONTENT=""
case $WWW_CHOICE in
    1) # Redirect www to non-www
        CADDYFILE_CONTENT="
$DOMAIN_NAME {
    encode zstd gzip
    reverse_proxy localhost:$NODE_PORT
}

www.$DOMAIN_NAME {
    redir https://$DOMAIN_NAME{uri} permanent
}
"
        ;;
    2) # Redirect non-www to www
        CADDYFILE_CONTENT="
www.$DOMAIN_NAME {
    encode zstd gzip
    reverse_proxy localhost:$NODE_PORT
}

$DOMAIN_NAME {
    redir https://www.$DOMAIN_NAME{uri} permanent
}
"
        ;;
    3) # Serve both www and non-www
        CADDYFILE_CONTENT="
$DOMAIN_NAME, www.$DOMAIN_NAME {
    encode zstd gzip
    reverse_proxy localhost:$NODE_PORT
}
"
        ;;
    4) # Serve only non-www
        CADDYFILE_CONTENT="
$DOMAIN_NAME {
    encode zstd gzip
    reverse_proxy localhost:$NODE_PORT
}
"
        ;;
    *)
        echo "--- Invalid choice. Exiting. ---"
        exit 1
        ;;
esac


# Write the configuration to Caddyfile
echo "$CADDYFILE_CONTENT" | sudo tee /etc/caddy/Caddyfile > /dev/null

# --- Ensure Firewall Rules ---
echo "--- Ensuring UFW allows HTTP and HTTPS traffic..."
# These should already be allowed by 01-initial-setup.sh, but we double-check
sudo ufw allow http
sudo ufw allow https
sudo ufw status verbose | grep -E '80/tcp|443/tcp' || echo "Warning: Ports 80/443 might not be open in UFW."

# --- Validate and Reload Caddy ---
echo "--- Validating Caddy configuration..."
# Use sudo to run as root, necessary for reading /etc/caddy/Caddyfile
if sudo caddy validate --config /etc/caddy/Caddyfile; then
    echo "--- Caddy configuration validation successful."
    echo "--- Reloading Caddy service..."
    sudo systemctl reload caddy
else
    echo "--- ERROR: Caddy configuration validation failed. Please check /etc/caddy/Caddyfile manually. Caddy service was not reloaded."
    exit 1
fi

echo "--- Caddy Setup Complete ---"
echo "Caddy is configured to serve $DOMAIN_NAME (and potentially www.$DOMAIN_NAME based on your choice) and reverse proxy to your Node.js app on localhost:$NODE_PORT."
echo "IMPORTANT:"
echo "1. Ensure your DNS 'A' and/or 'AAAA' records for '$DOMAIN_NAME' (and 'www.$DOMAIN_NAME' if applicable) point to this server's public IP address."
echo "2. Make sure your Node.js application is running and listening on port $NODE_PORT on localhost (127.0.0.1)."
echo "3. Caddy will automatically obtain and renew SSL certificates via Let's Encrypt."
echo "4. Check Caddy logs (e.g., /var/log/caddy/$DOMAIN_NAME.log) for details."
echo

exit 0
