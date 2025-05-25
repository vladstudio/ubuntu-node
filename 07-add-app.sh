#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
APPS_BASE_DIR="$HOME/apps"
CADDY_CONF_DIR="/etc/caddy/conf.d"
PORT_CONFIG_FILE="$HOME/.app-ports"

# --- Helper Functions ---
get_next_available_port() {
    local start_port=3000
    local max_port=3100
    
    # Create port config file if it doesn't exist
    touch "$PORT_CONFIG_FILE"
    
    for ((port=$start_port; port<=$max_port; port++)); do
        # Check if port is already allocated
        if ! grep -q "^$port$" "$PORT_CONFIG_FILE" 2>/dev/null; then
            # Check if port is actually in use
            if ! netstat -ln 2>/dev/null | grep -q ":$port "; then
                echo "$port"
                return 0
            fi
        fi
    done
    
    echo "--- ERROR: No available ports found between $start_port and $max_port. Exiting."
    exit 1
}

allocate_port() {
    local port=$1
    echo "$port" >> "$PORT_CONFIG_FILE"
    sort -n "$PORT_CONFIG_FILE" -o "$PORT_CONFIG_FILE"
}

# --- User Input ---
read -p "Enter a name for this app (alphanumeric, hyphens, underscores only): " APP_NAME
if [ -z "$APP_NAME" ]; then
    echo "--- App name cannot be empty. Exiting."
    exit 1
fi

# Validate app name
if ! [[ "$APP_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "--- Invalid app name '$APP_NAME'. Please use only alphanumeric characters, underscore, or hyphen. Exiting."
    exit 1
fi

read -p "Enter the domain name for this app (e.g., app1.example.com): " DOMAIN_NAME
if [ -z "$DOMAIN_NAME" ]; then
    echo "--- Domain name cannot be empty. Exiting."
    exit 1
fi

read -p "Enter the Git repository URL for your Node.js application: " GIT_REPO_URL
if [ -z "$GIT_REPO_URL" ]; then
    echo "--- Git repository URL cannot be empty. Exiting."
    exit 1
fi

# --- App Directory Setup ---
APP_DIR="$APPS_BASE_DIR/$APP_NAME"
if [ -d "$APP_DIR" ]; then
    echo "--- ERROR: App directory $APP_DIR already exists. Please choose a different app name or remove the existing directory. Exiting."
    exit 1
fi

echo "--- Creating app directory structure..."
mkdir -p "$APPS_BASE_DIR"

# --- Port Assignment ---
echo "--- Assigning port for $APP_NAME..."
APP_PORT=$(get_next_available_port)
allocate_port "$APP_PORT"
echo "--- Assigned port: $APP_PORT"

# --- Build and Start Commands ---
DEFAULT_BUILD_COMMAND="npm install && npm run build"
read -p "Enter the command to build the application [default: '$DEFAULT_BUILD_COMMAND']: " BUILD_COMMAND
BUILD_COMMAND=${BUILD_COMMAND:-$DEFAULT_BUILD_COMMAND}

DEFAULT_BUILD_OUTPUT_DIR="dist"
read -p "Enter the relative path to the build output directory within the repo [default: $DEFAULT_BUILD_OUTPUT_DIR]: " BUILD_OUTPUT_DIR
BUILD_OUTPUT_DIR=${BUILD_OUTPUT_DIR:-$DEFAULT_BUILD_OUTPUT_DIR}

DEFAULT_START_COMMAND="node $BUILD_OUTPUT_DIR/server/entry.js"
read -p "Enter the command to start the built application (relative to clone path) [default: '$DEFAULT_START_COMMAND']: " START_COMMAND
START_COMMAND=${START_COMMAND:-$DEFAULT_START_COMMAND}

# --- WWW Handling Input ---
echo "How should the 'www' subdomain (www.$DOMAIN_NAME) be handled?"
echo "  1) Redirect www.$DOMAIN_NAME to $DOMAIN_NAME (Recommended)"
echo "  2) Redirect $DOMAIN_NAME to www.$DOMAIN_NAME"
echo "  3) Serve both www.$DOMAIN_NAME and $DOMAIN_NAME (No redirect)"
echo "  4) Only serve $DOMAIN_NAME (Ignore www)"
read -p "Enter choice [1]: " WWW_CHOICE
WWW_CHOICE=${WWW_CHOICE:-1}

echo "--- Starting deployment of $APP_NAME on $DOMAIN_NAME:$APP_PORT ---"

# --- Clone Repository ---
echo "--- Cloning repository from $GIT_REPO_URL into $APP_DIR..."
git clone "$GIT_REPO_URL" "$APP_DIR"

# --- Load NVM ---
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

if ! command -v nvm &> /dev/null; then
    echo "--- ERROR: NVM not found. Please run 06-nvm-node-setup.sh first or install NVM manually. Exiting."
    exit 1
fi

# --- Optional .env file creation ---
read -p "Do you want to create an environment file (.env) in $APP_DIR? [y/N]: " CREATE_ENV_CHOICE
if [[ "$CREATE_ENV_CHOICE" =~ ^[Yy]$ ]]; then
    DEFAULT_ENV_FILENAME=".env"
    read -p "Enter the filename for the environment file [default: $DEFAULT_ENV_FILENAME]: " ENV_FILENAME
    ENV_FILENAME=${ENV_FILENAME:-$DEFAULT_ENV_FILENAME}
    ENV_FILE_PATH="$APP_DIR/$ENV_FILENAME"
    GITIGNORE_PATH="$APP_DIR/.gitignore"

    echo "--- Creating environment file $ENV_FILE_PATH..."
    # Add PORT environment variable
    echo "PORT=$APP_PORT" > "$ENV_FILE_PATH"
    
    touch "$GITIGNORE_PATH"
    if ! grep -qxF "$ENV_FILENAME" "$GITIGNORE_PATH"; then
        echo "$ENV_FILENAME" >> "$GITIGNORE_PATH"
        echo "--- Added $ENV_FILENAME to $GITIGNORE_PATH."
    fi

    echo "--- Environment file created with PORT=$APP_PORT."
    echo "--- You can edit $ENV_FILE_PATH to add more environment variables."
    read -p "--- Press Enter to continue or Ctrl+C to edit the file manually:"
fi

# --- Initial Build ---
echo "--- Performing initial build..."
cd "$APP_DIR"
nvm use default
eval "$BUILD_COMMAND"

# --- Setup Systemd Service ---
SERVICE_NAME="app-$APP_NAME"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
echo "--- Setting up systemd service '$SERVICE_NAME'..."

SERVICE_FILE_CONTENT="[Unit]
Description=$APP_NAME Node.js Application
After=network.target

[Service]
Environment=NODE_ENV=production
Environment=PORT=$APP_PORT
Type=simple
User=$(whoami)
Group=$(id -gn $(whoami))
WorkingDirectory=$APP_DIR
ExecStart=/bin/bash -c 'export NVM_DIR=\"\$HOME/.nvm\" && [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\" && nvm use default && $START_COMMAND'
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
"

echo "--- Writing service file $SERVICE_FILE (requires sudo)..."
echo "$SERVICE_FILE_CONTENT" | sudo tee "$SERVICE_FILE" > /dev/null

echo "--- Enabling and starting service..."
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl start "$SERVICE_NAME"

# --- Setup Git post-merge Hook ---
HOOK_DIR="$APP_DIR/.git/hooks"
HOOK_FILE="$HOOK_DIR/post-merge"
echo "--- Setting up Git hook..."

mkdir -p "$HOOK_DIR"

HOOK_CONTENT="#!/bin/bash
echo '--- Running post-merge hook for $APP_NAME ---'
export NVM_DIR=\"\$HOME/.nvm\"
[ -s \"\$NVM_DIR/nvm.sh\" ] && \\. \"\$NVM_DIR/nvm.sh\"

cd \"$APP_DIR\" || exit 1

nvm use default

echo '--- Running build command...'
eval \"$BUILD_COMMAND\"

echo '--- Restarting systemd service...'
sudo systemctl restart \"$SERVICE_NAME\"

echo '--- post-merge hook finished ---'
exit 0
"

echo "$HOOK_CONTENT" > "$HOOK_FILE"
chmod +x "$HOOK_FILE"

# --- Setup Caddy Configuration ---
echo "--- Setting up Caddy configuration..."

# Create conf.d directory if it doesn't exist
sudo mkdir -p "$CADDY_CONF_DIR"

# Generate Caddy config based on www choice
CADDY_CONFIG_FILE="$CADDY_CONF_DIR/$APP_NAME.conf"
CADDY_CONFIG_CONTENT=""

case $WWW_CHOICE in
    1) # Redirect www to non-www
        CADDY_CONFIG_CONTENT="$DOMAIN_NAME {
    encode zstd gzip
    reverse_proxy http://localhost:$APP_PORT {
        header_up Host {upstream_hostport}
    }
    log {
        output file /var/log/caddy/$DOMAIN_NAME.log
    }
}

www.$DOMAIN_NAME {
    redir https://$DOMAIN_NAME{uri} permanent
    log {
        output file /var/log/caddy/www.$DOMAIN_NAME.log
    }
}"
        ;;
    2) # Redirect non-www to www
        CADDY_CONFIG_CONTENT="www.$DOMAIN_NAME {
    encode zstd gzip
    reverse_proxy http://localhost:$APP_PORT {
        header_up Host {upstream_hostport}
    }
    log {
        output file /var/log/caddy/www.$DOMAIN_NAME.log
    }
}

$DOMAIN_NAME {
    redir https://www.$DOMAIN_NAME{uri} permanent
    log {
        output file /var/log/caddy/$DOMAIN_NAME.log
    }
}"
        ;;
    3) # Serve both www and non-www
        CADDY_CONFIG_CONTENT="$DOMAIN_NAME, www.$DOMAIN_NAME {
    encode zstd gzip
    reverse_proxy http://localhost:$APP_PORT {
        header_up Host {upstream_hostport}
    }
    log {
        output file /var/log/caddy/$DOMAIN_NAME.log
    }
}"
        ;;
    4) # Serve only non-www
        CADDY_CONFIG_CONTENT="$DOMAIN_NAME {
    encode zstd gzip
    reverse_proxy http://localhost:$APP_PORT {
        header_up Host {upstream_hostport}
    }
    log {
        output file /var/log/caddy/$DOMAIN_NAME.log
    }
}"
        ;;
esac

echo "$CADDY_CONFIG_CONTENT" | sudo tee "$CADDY_CONFIG_FILE" > /dev/null

# --- Update main Caddyfile to import configs ---
MAIN_CADDYFILE="/etc/caddy/Caddyfile"
IMPORT_LINE="import $CADDY_CONF_DIR/*.conf"

# Check if import line already exists
if ! sudo grep -qF "$IMPORT_LINE" "$MAIN_CADDYFILE" 2>/dev/null; then
    echo "--- Adding import directive to main Caddyfile..."
    echo "$IMPORT_LINE" | sudo tee -a "$MAIN_CADDYFILE" > /dev/null
fi

# --- Validate and Reload Caddy ---
echo "--- Validating Caddy configuration..."
if sudo caddy validate --config "$MAIN_CADDYFILE"; then
    echo "--- Reloading Caddy..."
    sudo systemctl reload caddy
else
    echo "--- ERROR: Caddy configuration validation failed. Please check the configuration manually."
    exit 1
fi

echo
echo "--- --------------------------"
echo "--- App '$APP_NAME' Successfully Deployed! ---"
echo "--- Domain: $DOMAIN_NAME"
echo "--- Port: $APP_PORT"
echo "--- Directory: $APP_DIR"
echo "--- Service: $SERVICE_NAME"
echo "--- Service Status: sudo systemctl status $SERVICE_NAME"
echo "--- Service Logs: sudo journalctl -u $SERVICE_NAME -f"
echo "--- Caddy Logs: tail -f /var/log/caddy/$DOMAIN_NAME.log"
echo "--- To deploy updates:"
echo "---   cd $APP_DIR && git pull"
echo "--- --------------------------"
echo

exit 0