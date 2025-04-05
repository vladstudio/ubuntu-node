#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- User Input ---
echo "--- This script configures SSH key authentication for the current user ($(whoami))."
echo "--- Please paste the entire content of your PUBLIC SSH key (e.g., id_rsa.pub)."
echo "--- Usually can be obtained with cat ~/.ssh/id_rsa.pub"
read -p "Public Key: " PUBLIC_KEY
if [ -z "$PUBLIC_KEY" ]; then
    echo "--- Public key cannot be empty. Exiting."
    exit 1
fi

# Basic validation of the key format (starts with ssh-rsa, ssh-ed25519, etc.)
if ! [[ "$PUBLIC_KEY" =~ ^ssh-(rsa|ed25519|ecdsa) ]]; then
    echo "--- Invalid public key format detected. Key should start with 'ssh-rsa', 'ssh-ed25519', etc. Exiting."
    exit 1
fi

# --- Setup SSH Key Authentication ---
echo "--- Configuring SSH key for current user ($(whoami))..."
SSH_DIR="$HOME/.ssh"
AUTH_KEYS_FILE="$SSH_DIR/authorized_keys"

# Create .ssh directory if it doesn't exist
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Add the public key to authorized_keys
echo "$PUBLIC_KEY" >> "$AUTH_KEYS_FILE"

# Set correct permissions for authorized_keys
chmod 600 "$AUTH_KEYS_FILE"

# --- Harden SSH Configuration ---
echo "--- Hardening SSH configuration (/etc/ssh/sshd_config)..."
SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP_FILE="/etc/ssh/sshd_config.backup_$(date +%F_%T)"

# Backup original config
echo "--- Backing up current sshd_config to $BACKUP_FILE..."
sudo cp "$SSHD_CONFIG" "$BACKUP_FILE"

# Function to update or add SSH config settings
update_sshd_config() {
    local key="$1"
    local value="$2"
    local config_file="$3"
    # Check if the key exists (commented or uncommented) and update/uncomment
    if sudo grep -qE "^\s*#?\s*${key}\s+" "$config_file"; then
        sudo sed -i -E "s/^\s*#?\s*(${key})\s+.*/\1 ${value}/" "$config_file"
        echo "--- Updated SSH config: $key $value"
    else
        # Add the key-value pair if it doesn't exist
        echo "$key $value" | sudo tee -a "$config_file" > /dev/null
        echo "--- Added SSH config: $key $value"
    fi
}

# Apply hardening settings
update_sshd_config "PermitRootLogin" "no" "$SSHD_CONFIG"
update_sshd_config "PasswordAuthentication" "no" "$SSHD_CONFIG"
update_sshd_config "PubkeyAuthentication" "yes" "$SSHD_CONFIG"
update_sshd_config "ChallengeResponseAuthentication" "no" "$SSHD_CONFIG"
update_sshd_config "UsePAM" "no" "$SSHD_CONFIG" # Often needed when disabling passwords
update_sshd_config "MaxAuthTries" "3" "$SSHD_CONFIG"
update_sshd_config "LoginGraceTime" "60" "$SSHD_CONFIG"
# Ensure Protocol 2 is used (usually default)
# update_sshd_config "Protocol" "2" "$SSHD_CONFIG" # Uncomment if needed, but often default

# --- Validate and Restart SSH ---
echo "--- Validating SSH configuration..."
sudo sshd -t
if [ $? -ne 0 ]; then
    echo "--- ERROR: SSH configuration validation failed. Restoring backup from $BACKUP_FILE."
    sudo cp "$BACKUP_FILE" "$SSHD_CONFIG"
    echo "--- Backup restored. Please check sshd_config manually. Exiting."
    exit 1
fi

echo "--- Restarting SSH service..."
sudo systemctl restart sshd

# --- Get Public IP ---
echo "--- Fetching public IPv4 address..."
# Use curl -4 to force IPv4 (curl installed in 01-initial-setup.sh); provide fallback
SERVER_IP=$(curl -4 -s ifconfig.me || echo "your_server_ip")

echo
echo "--- --------------------------"
echo "--- SSH Setup Complete ---"
echo "Password authentication is now disabled. Ensure you can log in as user '$(whoami)' using your SSH key:"
echo "ssh -i /path/to/your/private_key $(whoami)@$SERVER_IP"
echo "If you encounter issues, the original sshd_config was backed up to $BACKUP_FILE."
echo "--- --------------------------"
echo
exit 0
