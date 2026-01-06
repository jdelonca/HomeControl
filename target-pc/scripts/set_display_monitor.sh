#!/bin/bash
# set_display_monitor.sh
# Sets display output to small monitor only (disables TV)
#
# IMPORTANT: Adjust the variables below to match your setup
# Run: xrandr --query to see your display outputs

# Configuration - EDIT THESE VALUES
TV_OUTPUT="HDMI-1"              # Your TV's output name
MONITOR_OUTPUT="DP-1"           # Your small monitor's output name  
MONITOR_RESOLUTION="1920x1080"  # Monitor resolution
MONITOR_REFRESH="60"            # Monitor refresh rate

# Get the display (for headless SSH access)
# Auto-detect the DISPLAY and XAUTHORITY
if [ -z "$DISPLAY" ]; then
    export DISPLAY=:1
fi
if [ -z "$XAUTHORITY" ]; then
    # Try GDM location first (most common for GNOME)
    if [ -f "/run/user/$(id -u)/gdm/Xauthority" ]; then
        export XAUTHORITY="/run/user/$(id -u)/gdm/Xauthority"
    elif [ -f "$HOME/.Xauthority" ]; then
        export XAUTHORITY="$HOME/.Xauthority"
    fi
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Switching to monitor display mode..."

# Disable TV, enable monitor as primary
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
