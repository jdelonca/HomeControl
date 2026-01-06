#!/bin/bash
# set_display_tv.sh
# Sets display output to TV only (disables other monitors)
#
# IMPORTANT: You need to identify your display outputs first!
# Run: xrandr --query
# Look for output names like HDMI-1, DP-1, eDP-1, etc.
# 
# Adjust the variables below to match your setup:

# Configuration - EDIT THESE VALUES
TV_OUTPUT="HDMI-1"          # Your TV's output name (e.g., HDMI-1, HDMI-A-0)
MONITOR_OUTPUT="DP-1"       # Your small monitor's output name
TV_RESOLUTION="1920x1080"   # TV resolution
TV_REFRESH="60"             # TV refresh rate

# Get the display (for headless SSH access)
export DISPLAY=:0
export XAUTHORITY=/home/$USER/.Xauthority

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Switching to TV display mode..."

# Disable the small monitor, enable TV as primary
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
