#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- User Input ---
read -p "Enter the Git repository URL for your Node.js application: " GIT_REPO_URL
if [ -z "$GIT_REPO_URL" ]; then
    echo "--- Git repository URL cannot be empty. Exiting."
    exit 1
fi

DEFAULT_CLONE_PATH="$HOME/app"
read -p "Enter the full path where the repository should be cloned [default: $DEFAULT_CLONE_PATH]: " CLONE_PATH
CLONE_PATH=${CLONE_PATH:-$DEFAULT_CLONE_PATH}

DEFAULT_BUILD_COMMAND="npm install && npm run build"
read -p "Enter the command to build the application [default: '$DEFAULT_BUILD_COMMAND']: " BUILD_COMMAND
BUILD_COMMAND=${BUILD_COMMAND:-$DEFAULT_BUILD_COMMAND}

DEFAULT_BUILD_OUTPUT_DIR="dist"
read -p "Enter the relative path to the build output directory within the repo [default: $DEFAULT_BUILD_OUTPUT_DIR]: " BUILD_OUTPUT_DIR
BUILD_OUTPUT_DIR=${BUILD_OUTPUT_DIR:-$DEFAULT_BUILD_OUTPUT_DIR}

DEFAULT_START_COMMAND="node $BUILD_OUTPUT_DIR/server/entry.js"
read -p "Enter the command to start the built application (relative to clone path) [default: '$DEFAULT_START_COMMAND']: " START_COMMAND
START_COMMAND=${START_COMMAND:-$DEFAULT_START_COMMAND}

DEFAULT_SERVICE_NAME="my-node-app"
read -p "Enter a name for the systemd service [default: $DEFAULT_SERVICE_NAME]: " SERVICE_NAME
SERVICE_NAME=${SERVICE_NAME:-$DEFAULT_SERVICE_NAME}

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

# --- Clone Repository ---
if [ -d "$CLONE_PATH" ]; then
    echo "--- Directory $CLONE_PATH already exists. Skipping clone."
    # Optionally, add logic here to pull latest changes if dir exists
else
    echo "--- Cloning repository from $GIT_REPO_URL into $CLONE_PATH..."
    git clone "$GIT_REPO_URL" "$CLONE_PATH"
fi

# --- Initial Build ---
echo "--- Performing initial build..."
cd "$CLONE_PATH"
# Ensure NVM is available for the build command
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use default # Use the default (LTS) version
eval "$BUILD_COMMAND" # Use eval to handle commands with '&&'


# --- Setup Systemd User Service ---
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SYSTEMD_USER_DIR/$SERVICE_NAME.service"
echo "--- Setting up systemd service '$SERVICE_NAME' at $SERVICE_FILE..."

mkdir -p "$SYSTEMD_USER_DIR"

# Create the service file content
# Note: We use /bin/bash -ic to ensure NVM is loaded correctly from .bashrc/.profile
# Alternatively, explicitly source NVM as shown below. Explicit sourcing is often more reliable.
SERVICE_FILE_CONTENT="[Unit]
Description=Node.js Application Service ($SERVICE_NAME)
After=network.target

[Service]
Environment=NODE_ENV=production
Type=simple
User=$(whoami)
WorkingDirectory=$CLONE_PATH
ExecStart=/bin/bash -c 'export NVM_DIR=\"$HOME/.nvm\" && [ -s \"\$NVM_DIR/nvm.sh\" ] && \\. \"\$NVM_DIR/nvm.sh\" && nvm use default && $START_COMMAND'
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
"
echo "$SERVICE_FILE_CONTENT" > "$SERVICE_FILE"

echo "--- Reloading systemd user daemon, enabling and starting service..."
/usr/bin/systemctl --user daemon-reload
/usr/bin/systemctl --user enable "$SERVICE_NAME"
/usr/bin/systemctl --user restart "$SERVICE_NAME" # ensure it starts fresh

echo "--- Enabling systemd lingering for user $(whoami)..."
sudo /usr/bin/loginctl enable-linger "$(whoami)"

# --- Setup Git post-merge Hook ---
HOOK_DIR="$CLONE_PATH/.git/hooks"
HOOK_FILE="$HOOK_DIR/post-merge"
echo "--- Setting up Git hook at $HOOK_FILE..."

mkdir -p "$HOOK_DIR"

HOOK_CONTENT="#!/bin/bash
echo '--- Running post-merge hook ---'
export NVM_DIR=\"$HOME/.nvm\"
[ -s \"\$NVM_DIR/nvm.sh\" ] && \\. \"\$NVM_DIR/nvm.sh\"

cd \"$CLONE_PATH\" || exit 1

nvm use default

echo '--- Running build command...'
eval \"$BUILD_COMMAND\"

echo '--- Restarting systemd service...'
/usr/bin/systemctl --user restart \"$SERVICE_NAME\"

echo '--- post-merge hook finished ---'
exit 0
"

echo "$HOOK_CONTENT" > "$HOOK_FILE"
chmod +x "$HOOK_FILE"

echo 
echo "--- Your application '$SERVICE_NAME' is now running and managed by systemd."
echo "Service Status: systemctl --user status $SERVICE_NAME"
echo "Service Logs: journalctl --user -u $SERVICE_NAME -f"
echo "To deploy updates:"
echo "1. Commit your changes locally."
echo "2. SSH into the server."
echo "3. Navigate to the application directory: cd $CLONE_PATH"
echo "4. Pull the latest changes: git pull"
echo "The post-merge hook will automatically rebuild and restart the application."
echo
exit 0
