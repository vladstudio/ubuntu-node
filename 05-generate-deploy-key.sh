#!/bin/bash

# This script helps generate an SSH key pair for deploying code from a private repository (e.g., GitHub).
# It should be run as the user who will own the application code and run the deployment script (05-nvm-node-app.sh).

echo "--- SSH Deploy Key Generation ---"

# --- User Input ---
DEFAULT_KEY_FILENAME="$HOME/.ssh/deploy_key"
read -p "Enter filename for the new SSH key pair [default: $DEFAULT_KEY_FILENAME]: " KEY_FILENAME
KEY_FILENAME=${KEY_FILENAME:-$DEFAULT_KEY_FILENAME}

DEFAULT_KEY_COMMENT="deploy-key-$(hostname)-$(date +%F)"
read -p "Enter a comment for the SSH key [default: $DEFAULT_KEY_COMMENT]: " KEY_COMMENT
KEY_COMMENT=${KEY_COMMENT:-$DEFAULT_KEY_COMMENT}

# --- Generate Key Pair ---
SSH_DIR=$(dirname "$KEY_FILENAME")
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [ -f "$KEY_FILENAME" ]; then
    echo "Key file '$KEY_FILENAME' already exists. Skipping generation."
else
    echo "Generating ED25519 key pair..."
    # Generate key without passphrase
    ssh-keygen -t ed25519 -C "$KEY_COMMENT" -f "$KEY_FILENAME" -N "" # -N "" ensures no passphrase
    chmod 600 "$KEY_FILENAME"
    chmod 644 "$KEY_FILENAME.pub"
    echo "Key pair generated:"
    echo "  Private key: $KEY_FILENAME"
    echo "  Public key:  $KEY_FILENAME.pub"
fi

# --- Display Public Key ---
echo ""
echo "--- Add Public Key to GitHub Deploy Keys ---"
echo "Copy the following public key and add it as a 'Deploy key' in your private repository's settings on GitHub."
echo "Go to: GitHub Repo > Settings > Deploy keys > Add deploy key"
echo "IMPORTANT: Leave 'Allow write access' UNCHECKED."
echo ""
echo "Public Key Content:"
cat "$KEY_FILENAME.pub"
echo ""
echo "---------------------------------------------"
read -p "Press Enter after you have added the public key to GitHub..."

# --- Configure SSH Client (Optional) ---
read -p "Do you want to automatically configure ~/.ssh/config to use this key for github.com? (y/N): " CONFIGURE_SSH
if [[ "$CONFIGURE_SSH" =~ ^[Yy]$ ]]; then
    SSH_CONFIG_FILE="$HOME/.ssh/config"
    echo "Configuring $SSH_CONFIG_FILE..."

    # Create config file if it doesn't exist
    touch "$SSH_CONFIG_FILE"
    chmod 600 "$SSH_CONFIG_FILE"

    # Check if github.com host entry already exists
    if grep -qE "^\s*Host\s+github.com\s*$" "$SSH_CONFIG_FILE"; then
        echo "Host entry for github.com already exists in $SSH_CONFIG_FILE."
        echo "Please manually ensure it uses 'IdentityFile $KEY_FILENAME'."
    else
        # Add the configuration block
        CONFIG_BLOCK="
Host github.com
  HostName github.com
  User git
  IdentityFile $KEY_FILENAME
  IdentitiesOnly yes
"
        echo "$CONFIG_BLOCK" >> "$SSH_CONFIG_FILE"
        echo "Added github.com configuration to $SSH_CONFIG_FILE."
    fi
else
    echo "Skipping automatic SSH client configuration."
    echo "You may need to manually specify the key using 'ssh -i $KEY_FILENAME ...' or configure ~/.ssh/config yourself."
fi

# --- Test Connection ---
echo ""
echo "--- Testing SSH Connection to GitHub ---"
echo "Attempting to authenticate with GitHub using the new key..."
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    echo "SUCCESS: SSH connection to GitHub using the deploy key is working."
else
    echo "WARNING: SSH connection test failed. Check GitHub deploy key setup and SSH configuration."
fi

# --- Final Reminder ---
echo ""
echo "--- Important Reminder ---"
echo "When running script '05-nvm-node-app.sh', make sure to use the SSH URL for your repository:"
echo "Example: git@github.com:your_username/your_repo.git"
echo ""
echo "--- Deploy Key Setup Helper Finished ---"

exit 0
