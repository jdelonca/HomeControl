#!/bin/bash
# wol_startup_handler.sh
# This script runs at startup and checks if the PC was woken via WoL
# If the WoL flag exists, it applies TV mode configuration and launches Steam
#
# Installation:
#   1. Copy this script to your scripts directory
#   2. Make it executable: chmod +x wol_startup_handler.sh
#   3. Set up autostart (see below)

# Configuration - EDIT THESE
SCRIPTS_DIR="/home/your_username/pc-control-scripts"
WOL_FLAG="/tmp/wol_wake_flag"
LOG_FILE="/tmp/wol_startup.log"

# Delay to ensure display server is ready
STARTUP_DELAY=10

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log "WoL startup handler started"

# Wait for display server to be ready
sleep "$STARTUP_DELAY"

# Check if WoL flag exists
if [ -f "$WOL_FLAG" ]; then
    log "WoL flag detected - applying TV gaming mode"
    
    # Remove the flag file (one-time use)
    rm -f "$WOL_FLAG"
    
    # Set display to TV mode
    log "Setting display to TV mode..."
    "$SCRIPTS_DIR/set_display_tv.sh" >> "$LOG_FILE" 2>&1
    
    # Wait a moment for display to settle
    sleep 2
    
    # Turn on TV via HDMI-CEC
    log "Turning on TV via CEC..."
    "$SCRIPTS_DIR/tv_on.sh" >> "$LOG_FILE" 2>&1
    
    # Wait for TV to fully power on
    sleep 5
    
    # Launch Steam in Big Picture mode
    log "Launching Steam..."
    "$SCRIPTS_DIR/launch_steam.sh" >> "$LOG_FILE" 2>&1
    
    log "WoL gaming mode setup complete"
else
    log "No WoL flag detected - normal startup"
fi

exit 0
