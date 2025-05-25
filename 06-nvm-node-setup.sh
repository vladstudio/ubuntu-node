#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "--- Installing/Updating NVM (Node Version Manager)..."
# Check if NVM is already installed by checking if NVM_DIR is set
if [ -z "$NVM_DIR" ]; then
    export NVM_DIR="$HOME/.nvm"
fi

# Download and run NVM install script if directory doesn't exist
if [ ! -d "$NVM_DIR" ]; then
    echo "--- Fetching latest NVM version tag from GitHub..."
    # Use curl to get the latest release tag, then grep/sed to extract it
    LATEST_NVM_TAG=$(curl -s "https://api.github.com/repos/nvm-sh/nvm/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

    if [ -z "$LATEST_NVM_TAG" ]; then
        LATEST_NVM_TAG="v0.39.7" # Fallback to a known stable version
    fi

    INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/nvm-sh/nvm/$LATEST_NVM_TAG/install.sh"
    echo "--- Installing NVM from $INSTALL_SCRIPT_URL..."
    curl -o- "$INSTALL_SCRIPT_URL" | bash

    # Source NVM immediately for the rest of this script
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
else
    echo "--- NVM already installed."
    # Source NVM if already installed but not sourced
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
fi
nvm --version

# --- Install Node.js LTS ---
echo "--- Installing latest Node.js LTS version..."
nvm install --lts
nvm use --lts
nvm alias default 'lts/*' # Set default for future shells
node -v
npm -v

# --- Create apps directory ---
APPS_BASE_DIR="$HOME/apps"
mkdir -p "$APPS_BASE_DIR"
echo "--- Created apps directory: $APPS_BASE_DIR"

echo
echo "--- --------------------------"
echo "--- NVM and Node.js LTS Setup Complete! ---"
echo "--- Node.js version: $(node -v)"
echo "--- NPM version: $(npm -v)"
echo "--- Apps will be deployed to: $APPS_BASE_DIR"
echo "--- Next step: Run ./07-add-app.sh to deploy your first application"
echo "--- --------------------------"
echo

exit 0