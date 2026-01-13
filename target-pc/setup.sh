#!/bin/bash
# ============================================================================
# PC Control Target PC - Automated Setup Script
# ============================================================================
# This script installs and configures the target PC (gaming PC) to be
# controlled remotely via Wake-on-LAN, SSH, and HDMI-CEC.
#
# Run this on your TARGET PC (the PC you want to control)
# ============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     PC Control Target PC - Automated Setup Script     ║${NC}"
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

# Check if running in graphical session
if [ -z "$DISPLAY" ]; then
    echo -e "${YELLOW}Warning: No graphical session detected${NC}"
    echo "Some display configuration features require a running X session."
    echo "You can continue, but display scripts may need manual testing."
    read -p "$(echo -e ${GREEN}Continue anyway? [Y/n]: ${NC})" continue_anyway
    if [[ "$continue_anyway" =~ ^[Nn]$ ]]; then
        exit 1
    fi
fi

# ============================================================================
# Step 1: Gather Configuration
# ============================================================================

print_section "Step 1: Configuration"

echo "Please provide the following information:"
echo

prompt_input "Scripts installation directory" "$HOME/pc-control-scripts" SCRIPTS_DIR

# Check for network interface
echo
echo -e "${YELLOW}Detecting network interfaces...${NC}"
INTERFACES=$(ip link show | grep -E "^[0-9]+:" | grep -v "lo:" | cut -d: -f2 | tr -d ' ')
echo "Available interfaces:"
echo "$INTERFACES"
echo

DEFAULT_INTERFACE=$(echo "$INTERFACES" | head -n1)
prompt_input "Primary network interface (for Wake-on-LAN)" "$DEFAULT_INTERFACE" NETWORK_INTERFACE

# Get MAC address
MAC_ADDRESS=$(ip link show "$NETWORK_INTERFACE" | grep -oP '(?<=link/ether )\S+')
echo -e "${GREEN}✓ Detected MAC address: $MAC_ADDRESS${NC}"

# Detect displays
if [ -n "$DISPLAY" ]; then
    echo
    echo -e "${YELLOW}Detecting display outputs...${NC}"
    DISPLAYS=$(xrandr --query 2>/dev/null | grep " connected" | cut -d' ' -f1)
    echo "Available displays:"
    echo "$DISPLAYS"
    echo

    DISPLAY_ARRAY=($DISPLAYS)
    if [ ${#DISPLAY_ARRAY[@]} -ge 2 ]; then
        prompt_input "TV output name" "${DISPLAY_ARRAY[0]}" TV_OUTPUT
        prompt_input "Monitor output name" "${DISPLAY_ARRAY[1]}" MONITOR_OUTPUT
    else
        prompt_input "TV output name" "HDMI-1" TV_OUTPUT
        prompt_input "Monitor output name" "DP-1" MONITOR_OUTPUT
    fi

    prompt_input "TV resolution" "1920x1080" TV_RESOLUTION
    prompt_input "TV refresh rate" "60" TV_REFRESH
    prompt_input "Monitor resolution" "1920x1080" MONITOR_RESOLUTION
    prompt_input "Monitor refresh rate" "60" MONITOR_REFRESH

    prompt_input "DISPLAY variable" ":0" DISPLAY_VAR
else
    echo -e "${YELLOW}Cannot auto-detect displays without X session${NC}"
    prompt_input "TV output name" "HDMI-1" TV_OUTPUT
    prompt_input "Monitor output name" "DP-1" MONITOR_OUTPUT
    prompt_input "TV resolution" "1920x1080" TV_RESOLUTION
    prompt_input "TV refresh rate" "60" TV_REFRESH
    prompt_input "Monitor resolution" "1920x1080" MONITOR_RESOLUTION
    prompt_input "Monitor refresh rate" "60" MONITOR_REFRESH
    prompt_input "DISPLAY variable" ":0" DISPLAY_VAR
fi

# ============================================================================
# Step 2: System Dependencies
# ============================================================================

print_section "Step 2: Installing System Dependencies"

echo "Installing required packages..."
sudo apt update
sudo apt install -y ethtool cec-utils

echo -e "${GREEN}✓ System dependencies installed${NC}"

# ============================================================================
# Step 3: Wake-on-LAN Configuration
# ============================================================================

print_section "Step 3: Configuring Wake-on-LAN"

# Check current WoL status
echo "Checking current Wake-on-LAN status..."
WOL_STATUS=$(sudo ethtool "$NETWORK_INTERFACE" | grep "Wake-on:" | awk '{print $2}')
echo "Current Wake-on-LAN status: $WOL_STATUS"

if [ "$WOL_STATUS" != "g" ]; then
    echo "Enabling Wake-on-LAN..."

    # Enable temporarily
    sudo ethtool -s "$NETWORK_INTERFACE" wol g

    # Make persistent with systemd-networkd
    echo "Creating persistent WoL configuration..."
    sudo tee /etc/systemd/network/10-wol.link > /dev/null << EOF
[Match]
MACAddress=$MAC_ADDRESS

[Link]
WakeOnLan=magic
EOF

    sudo systemctl restart systemd-networkd

    echo -e "${GREEN}✓ Wake-on-LAN enabled${NC}"
else
    echo -e "${GREEN}✓ Wake-on-LAN already enabled${NC}"
fi

# Verify WoL is enabled
NEW_WOL_STATUS=$(sudo ethtool "$NETWORK_INTERFACE" | grep "Wake-on:" | awk '{print $2}')
if [ "$NEW_WOL_STATUS" = "g" ]; then
    echo -e "${GREEN}✓ Wake-on-LAN verified${NC}"
else
    echo -e "${YELLOW}⚠ Wake-on-LAN status: $NEW_WOL_STATUS (expected: g)${NC}"
    echo "You may need to enable Wake-on-LAN in BIOS/UEFI settings"
fi

# ============================================================================
# Step 4: CEC Utilities Check
# ============================================================================

print_section "Step 4: Checking HDMI-CEC Support"

if ls /dev/cec* &> /dev/null; then
    echo -e "${GREEN}✓ CEC device found:${NC}"
    ls -l /dev/cec*

    echo "Testing CEC connection..."
    if timeout 5 bash -c 'echo "scan" | cec-client -s -d 1' &> /dev/null; then
        echo -e "${GREEN}✓ CEC is working${NC}"
    else
        echo -e "${YELLOW}⚠ CEC device exists but scan failed${NC}"
        echo "Make sure your TV has CEC enabled (Anynet+, SimpLink, etc.)"
    fi
else
    echo -e "${YELLOW}⚠ No CEC device found${NC}"
    echo "Most Intel GPUs don't support CEC natively."
    echo "You may need a Pulse-Eight USB-CEC adapter for TV control."
fi

# ============================================================================
# Step 5: Install Scripts
# ============================================================================

print_section "Step 5: Installing Control Scripts"

# Create scripts directory
echo "Creating scripts directory..."
mkdir -p "$SCRIPTS_DIR"

SCRIPT_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts"

# Create set_display_tv.sh
echo "Creating set_display_tv.sh..."
cat > "$SCRIPTS_DIR/set_display_tv.sh" << 'EOFSCRIPT'
#!/bin/bash
# set_display_tv.sh - Auto-configured by setup script

# Configuration
TV_OUTPUT="__TV_OUTPUT__"
MONITOR_OUTPUT="__MONITOR_OUTPUT__"
TV_RESOLUTION="__TV_RESOLUTION__"
TV_REFRESH="__TV_REFRESH__"

# Auto-detect display and X authority
if [ -z "$DISPLAY" ]; then
    export DISPLAY=__DISPLAY_VAR__
fi
if [ -z "$XAUTHORITY" ]; then
    if [ -f "/run/user/$(id -u)/gdm/Xauthority" ]; then
        export XAUTHORITY="/run/user/$(id -u)/gdm/Xauthority"
    elif [ -f "$HOME/.Xauthority" ]; then
        export XAUTHORITY="$HOME/.Xauthority"
    fi
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Switching to TV display mode..."
xrandr --output "$TV_OUTPUT" --mode "$TV_RESOLUTION" --rate "$TV_REFRESH" --primary \
       --output "$MONITOR_OUTPUT" --off

if [ $? -eq 0 ]; then
    echo "tv" > "$SCRIPT_DIR/current_display_mode"
    echo "Display switched to TV mode successfully"
    exit 0
else
    echo "Failed to switch display"
    exit 1
fi
EOFSCRIPT

# Substitute variables
sed -i "s|__TV_OUTPUT__|$TV_OUTPUT|g" "$SCRIPTS_DIR/set_display_tv.sh"
sed -i "s|__MONITOR_OUTPUT__|$MONITOR_OUTPUT|g" "$SCRIPTS_DIR/set_display_tv.sh"
sed -i "s|__TV_RESOLUTION__|$TV_RESOLUTION|g" "$SCRIPTS_DIR/set_display_tv.sh"
sed -i "s|__TV_REFRESH__|$TV_REFRESH|g" "$SCRIPTS_DIR/set_display_tv.sh"
sed -i "s|__DISPLAY_VAR__|$DISPLAY_VAR|g" "$SCRIPTS_DIR/set_display_tv.sh"

# Create set_display_monitor.sh
echo "Creating set_display_monitor.sh..."
cat > "$SCRIPTS_DIR/set_display_monitor.sh" << 'EOFSCRIPT'
#!/bin/bash
# set_display_monitor.sh - Auto-configured by setup script

# Configuration
TV_OUTPUT="__TV_OUTPUT__"
MONITOR_OUTPUT="__MONITOR_OUTPUT__"
MONITOR_RESOLUTION="__MONITOR_RESOLUTION__"
MONITOR_REFRESH="__MONITOR_REFRESH__"

# Auto-detect display and X authority
if [ -z "$DISPLAY" ]; then
    export DISPLAY=__DISPLAY_VAR__
fi
if [ -z "$XAUTHORITY" ]; then
    if [ -f "/run/user/$(id -u)/gdm/Xauthority" ]; then
        export XAUTHORITY="/run/user/$(id -u)/gdm/Xauthority"
    elif [ -f "$HOME/.Xauthority" ]; then
        export XAUTHORITY="$HOME/.Xauthority"
    fi
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Switching to monitor display mode..."
xrandr --output "$MONITOR_OUTPUT" --mode "$MONITOR_RESOLUTION" --rate "$MONITOR_REFRESH" --primary \
       --output "$TV_OUTPUT" --off

if [ $? -eq 0 ]; then
    echo "monitor" > "$SCRIPT_DIR/current_display_mode"
    echo "Display switched to monitor mode successfully"
    exit 0
else
    echo "Failed to switch display"
    exit 1
fi
EOFSCRIPT

# Substitute variables
sed -i "s|__TV_OUTPUT__|$TV_OUTPUT|g" "$SCRIPTS_DIR/set_display_monitor.sh"
sed -i "s|__MONITOR_OUTPUT__|$MONITOR_OUTPUT|g" "$SCRIPTS_DIR/set_display_monitor.sh"
sed -i "s|__MONITOR_RESOLUTION__|$MONITOR_RESOLUTION|g" "$SCRIPTS_DIR/set_display_monitor.sh"
sed -i "s|__MONITOR_REFRESH__|$MONITOR_REFRESH|g" "$SCRIPTS_DIR/set_display_monitor.sh"
sed -i "s|__DISPLAY_VAR__|$DISPLAY_VAR|g" "$SCRIPTS_DIR/set_display_monitor.sh"

# Copy or create remaining scripts
echo "Creating CEC control scripts..."

# tv_on.sh
cat > "$SCRIPTS_DIR/tv_on.sh" << 'EOFSCRIPT'
#!/bin/bash
# Turn on TV via HDMI-CEC
echo "Turning on TV..."
echo "on 0" | cec-client -s -d 1
EOFSCRIPT

# tv_off.sh
cat > "$SCRIPTS_DIR/tv_off.sh" << 'EOFSCRIPT'
#!/bin/bash
# Turn off TV via HDMI-CEC
echo "Turning off TV..."
echo "standby 0" | cec-client -s -d 1
EOFSCRIPT

# launch_steam.sh
cat > "$SCRIPTS_DIR/launch_steam.sh" << 'EOFSCRIPT'
#!/bin/bash
# Launch Steam in Big Picture mode

# Auto-detect display
if [ -z "$DISPLAY" ]; then
    export DISPLAY=__DISPLAY_VAR__
fi

# Auto-detect XAUTHORITY
if [ -z "$XAUTHORITY" ]; then
    if [ -f "/run/user/$(id -u)/gdm/Xauthority" ]; then
        export XAUTHORITY="/run/user/$(id -u)/gdm/Xauthority"
    elif [ -f "$HOME/.Xauthority" ]; then
        export XAUTHORITY="$HOME/.Xauthority"
    fi
fi

echo "Launching Steam in Big Picture mode..."

# Find Steam executable
STEAM_PATH=$(command -v steam)
if [ -z "$STEAM_PATH" ]; then
    echo "ERROR: Steam executable not found in PATH"
    exit 1
fi

# Check if Steam is already running
if pgrep -x "steam" > /dev/null; then
    echo "Steam is already running, switching to Big Picture mode"
    "$STEAM_PATH" steam://open/bigpicture &
else
    # Ensure D-Bus session is available (critical for Steam from systemd)
    if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
        DBUS_FILE="/run/user/$(id -u)/bus"
        if [ -S "$DBUS_FILE" ]; then
            export DBUS_SESSION_BUS_ADDRESS="unix:path=$DBUS_FILE"
        fi
    fi

    # Launch Steam with systemd-run for proper session integration
    if command -v systemd-run &> /dev/null; then
        systemd-run --user --scope --quiet \
            env DISPLAY="$DISPLAY" \
                XAUTHORITY="$XAUTHORITY" \
                DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
            "$STEAM_PATH" -bigpicture
    else
        nohup "$STEAM_PATH" -bigpicture >/dev/null 2>&1 </dev/null &
        disown
    fi
    echo "Steam launched"
fi
EOFSCRIPT

sed -i "s|__DISPLAY_VAR__|$DISPLAY_VAR|g" "$SCRIPTS_DIR/launch_steam.sh"

# wol_startup_handler.sh
cat > "$SCRIPTS_DIR/wol_startup_handler.sh" << 'EOFSCRIPT'
#!/bin/bash
# WoL Startup Handler - Detects WoL wake and configures TV mode + Steam

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WOL_FLAG="/tmp/wol_wake_flag"
LOG_FILE="$HOME/.pc-control-startup.log"

echo "[$(date)] WoL startup handler started" >> "$LOG_FILE"

# Check if WoL flag exists
if [ -f "$WOL_FLAG" ]; then
    echo "[$(date)] WoL flag detected - configuring TV mode" >> "$LOG_FILE"

    # Wait for X server to be ready
    sleep 5

    # Switch to TV display
    bash "$SCRIPT_DIR/set_display_tv.sh" >> "$LOG_FILE" 2>&1

    # Turn on TV
    bash "$SCRIPT_DIR/tv_on.sh" >> "$LOG_FILE" 2>&1

    # Launch Steam
    sleep 2
    bash "$SCRIPT_DIR/launch_steam.sh" >> "$LOG_FILE" 2>&1

    # Remove flag
    rm "$WOL_FLAG"

    echo "[$(date)] WoL setup complete" >> "$LOG_FILE"
else
    echo "[$(date)] No WoL flag - normal startup" >> "$LOG_FILE"
fi
EOFSCRIPT

# Make all scripts executable
chmod +x "$SCRIPTS_DIR"/*.sh

echo -e "${GREEN}✓ Scripts installed to $SCRIPTS_DIR${NC}"

# ============================================================================
# Step 6: Startup Handler Service
# ============================================================================

print_section "Step 6: Configuring Startup Handler"

echo "Which startup method would you like to use?"
echo "  1) Systemd user service (recommended for most systems)"
echo "  2) Desktop autostart (for older systems or specific desktop environments)"
echo
read -p "$(echo -e ${GREEN}Select [1-2]: ${NC})" startup_method

mkdir -p ~/.config/systemd/user/
mkdir -p ~/.config/autostart/

if [ "$startup_method" = "1" ] || [ -z "$startup_method" ]; then
    echo "Setting up systemd user service..."

    cat > ~/.config/systemd/user/wol-startup-handler.service << EOF
[Unit]
Description=WoL Startup Handler - Configure TV mode and Steam when woken via WoL
After=graphical-session.target

[Service]
Type=oneshot
RemainAfterExit=no
ExecStart=/bin/bash -c 'export DISPLAY=$DISPLAY_VAR; export XAUTHORITY=\${XAUTHORITY:-/run/user/\$(id -u)/gdm/Xauthority}; $SCRIPTS_DIR/wol_startup_handler.sh'

[Install]
WantedBy=graphical-session.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable wol-startup-handler.service

    echo -e "${GREEN}✓ Systemd user service configured${NC}"

else
    echo "Setting up desktop autostart..."

    cat > ~/.config/autostart/wol-startup-handler.desktop << EOF
[Desktop Entry]
Type=Application
Name=WoL Startup Handler
Exec=$SCRIPTS_DIR/wol_startup_handler.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

    chmod +x ~/.config/autostart/wol-startup-handler.desktop

    echo -e "${GREEN}✓ Desktop autostart configured${NC}"
fi

# ============================================================================
# Step 7: Passwordless Sudo for Shutdown
# ============================================================================

print_section "Step 7: Configuring Passwordless Shutdown"

echo "For remote shutdown to work, we need to allow passwordless sudo"
echo "for the 'systemctl poweroff' command."
echo
read -p "$(echo -e ${GREEN}Configure passwordless sudo for shutdown? [Y/n]: ${NC})" configure_sudo

if [[ ! "$configure_sudo" =~ ^[Nn]$ ]]; then
    SUDOERS_FILE="/etc/sudoers.d/pc-control-shutdown"
    echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl poweroff" | sudo tee "$SUDOERS_FILE" > /dev/null
    sudo chmod 0440 "$SUDOERS_FILE"

    # Test sudo configuration
    if sudo -n systemctl status >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Passwordless sudo configured${NC}"
    else
        echo -e "${YELLOW}⚠ Could not verify sudo configuration${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Skipped sudo configuration${NC}"
    echo "You'll need to configure this manually for remote shutdown to work."
fi

# ============================================================================
# Step 8: Testing
# ============================================================================

print_section "Step 8: Testing Configuration"

echo "Running basic tests..."

# Test WoL status
echo -n "Wake-on-LAN status... "
WOL_CHECK=$(sudo ethtool "$NETWORK_INTERFACE" | grep "Wake-on:" | awk '{print $2}')
if [ "$WOL_CHECK" = "g" ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ ($WOL_CHECK)${NC}"
fi

# Test script execution
if [ -n "$DISPLAY" ]; then
    echo -n "Display switching test... "
    if bash "$SCRIPTS_DIR/set_display_monitor.sh" &> /dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠ (may need manual configuration)${NC}"
    fi
fi

# Test CEC
echo -n "CEC support... "
if ls /dev/cec* &> /dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}⚠ (USB-CEC adapter may be needed)${NC}"
fi

# ============================================================================
# Setup Complete
# ============================================================================

print_section "Setup Complete!"

echo -e "${GREEN}Target PC has been configured successfully!${NC}"
echo
echo -e "${BLUE}Configuration Summary:${NC}"
echo "  Scripts directory: $SCRIPTS_DIR"
echo "  Network interface: $NETWORK_INTERFACE"
echo "  MAC address: $MAC_ADDRESS"
echo "  TV output: $TV_OUTPUT ($TV_RESOLUTION@${TV_REFRESH}Hz)"
echo "  Monitor output: $MONITOR_OUTPUT ($MONITOR_RESOLUTION@${MONITOR_REFRESH}Hz)"
echo
echo -e "${BLUE}Important Information:${NC}"
echo -e "  MAC Address: ${YELLOW}$MAC_ADDRESS${NC}"
echo "  (You'll need this for the control server setup)"
echo
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Test the scripts manually:"
echo "     ${YELLOW}bash $SCRIPTS_DIR/set_display_tv.sh${NC}"
echo "     ${YELLOW}bash $SCRIPTS_DIR/set_display_monitor.sh${NC}"
echo "  2. Test CEC control (if available):"
echo "     ${YELLOW}bash $SCRIPTS_DIR/tv_on.sh${NC}"
echo "  3. Run the setup script on your CONTROL SERVER"
echo "  4. Test Wake-on-LAN from the control server"
echo "  5. Ensure PC is connected via Ethernet (not Wi-Fi)"
echo "  6. Enable Wake-on-LAN in BIOS/UEFI if not already enabled"
echo
echo -e "${YELLOW}BIOS Configuration:${NC}"
echo "  Don't forget to enable Wake-on-LAN in your BIOS/UEFI settings!"
echo "  Look for 'Wake on LAN' or 'Wake on PCI/PCIE' in Power Management"
echo
echo -e "${GREEN}Setup complete! 🚀${NC}"
