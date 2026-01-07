#!/bin/bash
# ============================================================================
# PC Control Server - Automated Setup Script
# ============================================================================
# This script installs and configures the Flask control server that manages
# your remote PC through Wake-on-LAN, SSH, and various control commands.
#
# Run this on your CONTROL SERVER (always-on host)
# ============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     PC Control Server - Automated Setup Script        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo

# Function to print section headers
print_section() {
    echo
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to prompt for input with default value
prompt_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"

    if [ -n "$default" ]; then
        read -p "$(echo -e ${GREEN}$prompt [${YELLOW}$default${GREEN}]: ${NC})" input
        eval $var_name="${input:-$default}"
    else
        while [ -z "${!var_name}" ]; do
            read -p "$(echo -e ${GREEN}$prompt: ${NC})" input
            eval $var_name="$input"
        done
    fi
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Error: Do not run this script as root!${NC}"
    echo "Run as your normal user. The script will use sudo when needed."
    exit 1
fi

# ============================================================================
# Step 1: Gather Configuration
# ============================================================================

print_section "Step 1: Configuration"

echo "Please provide the following information about your setup:"
echo

echo -e "${YELLOW}Target PC Information:${NC}"
prompt_input "Target PC MAC address (format: AA:BB:CC:DD:EE:FF)" "" TARGET_MAC
prompt_input "Target PC IP address" "192.168.1.100" TARGET_IP
prompt_input "Target PC SSH username" "$USER" TARGET_USER
prompt_input "Target PC SSH port" "22" TARGET_SSH_PORT

echo
echo -e "${YELLOW}Network Settings:${NC}"
# Auto-detect broadcast IP if possible
DEFAULT_BROADCAST=$(ip -4 addr show | grep -oP '(?<=brd )\S+' | head -n1)
prompt_input "Network broadcast address" "${DEFAULT_BROADCAST:-192.168.1.255}" BROADCAST_IP

echo
echo -e "${YELLOW}Installation Settings:${NC}"
prompt_input "Install directory" "/var/www/pc-control" INSTALL_DIR
prompt_input "Service user" "$USER" SERVICE_USER
prompt_input "Scripts path on target PC" "/home/$TARGET_USER/pc-control-scripts" SCRIPTS_PATH

echo
echo -e "${YELLOW}SSH Key Settings:${NC}"
DEFAULT_SSH_KEY="$HOME/.ssh/pc_control_key"
prompt_input "SSH private key path" "$DEFAULT_SSH_KEY" SSH_KEY_PATH

# Check if SSH key exists
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo -e "${YELLOW}SSH key not found at $SSH_KEY_PATH${NC}"
    read -p "$(echo -e ${GREEN}Generate new SSH key? [Y/n]: ${NC})" generate_key
    if [[ ! "$generate_key" =~ ^[Nn]$ ]]; then
        GENERATE_SSH_KEY=true
    else
        echo -e "${RED}Error: SSH key is required. Please create one manually.${NC}"
        exit 1
    fi
fi

# ============================================================================
# Step 2: System Dependencies
# ============================================================================

print_section "Step 2: Installing System Dependencies"

echo "Installing required packages..."
sudo apt update
sudo apt install -y python3 python3-pip python3-venv nginx

echo -e "${GREEN}✓ System dependencies installed${NC}"

# ============================================================================
# Step 3: SSH Key Setup
# ============================================================================

print_section "Step 3: SSH Key Configuration"

if [ "$GENERATE_SSH_KEY" = true ]; then
    echo "Generating SSH key pair..."
    mkdir -p "$(dirname "$SSH_KEY_PATH")"
    ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -C "pc-control@$(hostname)"
    echo -e "${GREEN}✓ SSH key generated${NC}"

    echo
    echo -e "${YELLOW}Important: Copy the public key to your target PC${NC}"
    echo "Run this command now (in another terminal if needed):"
    echo -e "${BLUE}ssh-copy-id -i ${SSH_KEY_PATH}.pub $TARGET_USER@$TARGET_IP${NC}"
    echo
    read -p "$(echo -e ${GREEN}Press Enter once you've copied the SSH key...${NC})"
fi

# Test SSH connection
echo "Testing SSH connection..."
if ssh -i "$SSH_KEY_PATH" -o BatchMode=yes -o ConnectTimeout=5 "$TARGET_USER@$TARGET_IP" "echo 'SSH connection successful'" 2>/dev/null; then
    echo -e "${GREEN}✓ SSH connection successful${NC}"
else
    echo -e "${RED}✗ SSH connection failed${NC}"
    echo "Please ensure:"
    echo "  1. Target PC is online"
    echo "  2. SSH key has been copied to target PC"
    echo "  3. SSH service is running on target PC"
    read -p "$(echo -e ${YELLOW}Continue anyway? [y/N]: ${NC})" continue_anyway
    if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# ============================================================================
# Step 4: Application Installation
# ============================================================================

print_section "Step 4: Installing Flask Application"

# Create install directory
echo "Creating installation directory..."
sudo mkdir -p "$INSTALL_DIR"
sudo chown "$SERVICE_USER:www-data" "$INSTALL_DIR"

# Copy application files
echo "Copying application files..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -r "$SCRIPT_DIR"/* "$INSTALL_DIR/"

# Create virtual environment
echo "Setting up Python virtual environment..."
cd "$INSTALL_DIR"
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
echo "Installing Python packages..."
pip install --upgrade pip
pip install -r requirements.txt

deactivate

echo -e "${GREEN}✓ Application installed${NC}"

# ============================================================================
# Step 5: Configure Application
# ============================================================================

print_section "Step 5: Configuring Application"

echo "Updating configuration in app.py..."

# Create a backup
cp "$INSTALL_DIR/app.py" "$INSTALL_DIR/app.py.backup"

# Update CONFIG dictionary
sed -i "s|\"target_mac\": \".*\"|\"target_mac\": \"$TARGET_MAC\"|" "$INSTALL_DIR/app.py"
sed -i "s|\"target_ip\": \".*\"|\"target_ip\": \"$TARGET_IP\"|" "$INSTALL_DIR/app.py"
sed -i "s|\"target_user\": \".*\"|\"target_user\": \"$TARGET_USER\"|" "$INSTALL_DIR/app.py"
sed -i "s|\"ssh_key_path\": \".*\"|\"ssh_key_path\": \"$SSH_KEY_PATH\"|" "$INSTALL_DIR/app.py"
sed -i "s|\"ssh_port\": .*|\"ssh_port\": $TARGET_SSH_PORT,|" "$INSTALL_DIR/app.py"
sed -i "s|\"broadcast_ip\": \".*\"|\"broadcast_ip\": \"$BROADCAST_IP\"|" "$INSTALL_DIR/app.py"
sed -i "s|\"scripts_path\": \".*\"|\"scripts_path\": \"$SCRIPTS_PATH\"|" "$INSTALL_DIR/app.py"

echo -e "${GREEN}✓ Configuration updated${NC}"

# ============================================================================
# Step 6: Systemd Service
# ============================================================================

print_section "Step 6: Setting up Systemd Service"

echo "Creating systemd service..."

# Update service file
cat > /tmp/pc-control.service << EOF
[Unit]
Description=PC Control Flask Application
After=network.target

[Service]
User=$SERVICE_USER
Group=www-data
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$INSTALL_DIR/venv/bin"
ExecStart=$INSTALL_DIR/venv/bin/gunicorn \\
    --workers 2 \\
    --bind unix:$INSTALL_DIR/pc-control.sock \\
    --timeout 120 \\
    -m 007 \\
    wsgi:app
Restart=always
RestartSec=5
NoNewPrivileges=yes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
EOF

sudo mv /tmp/pc-control.service /etc/systemd/system/pc-control.service

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable pc-control
sudo systemctl start pc-control

# Check service status
if sudo systemctl is-active --quiet pc-control; then
    echo -e "${GREEN}✓ Service started successfully${NC}"
else
    echo -e "${RED}✗ Service failed to start${NC}"
    echo "Check status with: sudo systemctl status pc-control"
fi

# ============================================================================
# Step 7: Nginx Configuration
# ============================================================================

print_section "Step 7: Configuring Nginx"

echo "Creating nginx configuration..."

cat > /tmp/nginx-pc-control << EOF
server {
    listen 80;
    server_name _;

    access_log /var/log/nginx/pc-control-access.log;
    error_log /var/log/nginx/pc-control-error.log;

    location / {
        proxy_pass http://unix:$INSTALL_DIR/pc-control.sock;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # Increase timeout for WoL operations
        proxy_read_timeout 180s;
        proxy_connect_timeout 180s;
        proxy_send_timeout 180s;
    }

    location /static {
        alias $INSTALL_DIR/static;
        expires 30d;
    }
}
EOF

sudo mv /tmp/nginx-pc-control /etc/nginx/sites-available/pc-control

# Enable site
sudo ln -sf /etc/nginx/sites-available/pc-control /etc/nginx/sites-enabled/

# Test nginx configuration
if sudo nginx -t 2>/dev/null; then
    echo -e "${GREEN}✓ Nginx configuration valid${NC}"
    sudo systemctl reload nginx
    echo -e "${GREEN}✓ Nginx reloaded${NC}"
else
    echo -e "${RED}✗ Nginx configuration error${NC}"
    sudo nginx -t
fi

# ============================================================================
# Step 8: Firewall Configuration
# ============================================================================

print_section "Step 8: Firewall Configuration"

if command -v ufw &> /dev/null; then
    echo "Detected UFW firewall"
    read -p "$(echo -e ${GREEN}Configure UFW to allow HTTP (port 80)? [Y/n]: ${NC})" configure_ufw
    if [[ ! "$configure_ufw" =~ ^[Nn]$ ]]; then
        sudo ufw allow 80/tcp
        echo -e "${GREEN}✓ Firewall configured${NC}"
    fi
else
    echo -e "${YELLOW}UFW not detected. Please configure your firewall manually if needed.${NC}"
fi

# ============================================================================
# Step 9: Testing
# ============================================================================

print_section "Step 9: Testing Installation"

echo "Running basic tests..."

# Test WoL packet sending
echo -n "Testing WoL packet generation... "
if "$INSTALL_DIR/venv/bin/python3" -c "from wakeonlan import send_magic_packet; print('OK')" 2>/dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

# Test SSH connection from app context
echo -n "Testing SSH connection... "
if ssh -i "$SSH_KEY_PATH" -o BatchMode=yes -o ConnectTimeout=5 "$TARGET_USER@$TARGET_IP" "exit" 2>/dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

# ============================================================================
# Setup Complete
# ============================================================================

print_section "Setup Complete!"

echo -e "${GREEN}PC Control Server has been installed successfully!${NC}"
echo
echo -e "${BLUE}Configuration Summary:${NC}"
echo "  Installation directory: $INSTALL_DIR"
echo "  Service user: $SERVICE_USER"
echo "  Target PC: $TARGET_USER@$TARGET_IP"
echo "  Target MAC: $TARGET_MAC"
echo "  SSH key: $SSH_KEY_PATH"
echo
echo -e "${BLUE}Access your control panel:${NC}"
echo -e "  Local:  ${YELLOW}http://localhost/${NC}"
echo -e "  Network: ${YELLOW}http://$SERVER_IP/${NC}"
echo
echo -e "${BLUE}Useful Commands:${NC}"
echo "  View service status:  ${YELLOW}sudo systemctl status pc-control${NC}"
echo "  View service logs:    ${YELLOW}sudo journalctl -u pc-control -f${NC}"
echo "  Restart service:      ${YELLOW}sudo systemctl restart pc-control${NC}"
echo "  View nginx logs:      ${YELLOW}sudo tail -f /var/log/nginx/pc-control-*.log${NC}"
echo
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Run the setup script on your TARGET PC"
echo "  2. Configure passwordless sudo for shutdown (see SETUP_GUIDE.md)"
echo "  3. Test the web interface"
echo "  4. Consider setting up HTTPS for production use"
echo
echo -e "${GREEN}Happy controlling! 🎮${NC}"
