#!/bin/bash
# launch_steam.sh
# Launch Steam in Big Picture mode
#
# This script launches Steam with Big Picture mode, suitable for TV/couch gaming

# Get the display (for headless SSH access)
export DISPLAY=:0
export XAUTHORITY=/home/$USER/.Xauthority

echo "Launching Steam in Big Picture mode..."

# Check if Steam is already running
if pgrep -x "steam" > /dev/null; then
    echo "Steam is already running"
    
    # Try to switch to Big Picture mode
    # This uses Steam's URL handler
    steam steam://open/bigpicture &
else
    # Launch Steam with Big Picture mode
    # The -bigpicture flag starts Steam directly in Big Picture mode
    # The -silent flag prevents the login dialog from appearing
    
    # Detach the process so it continues running after SSH session ends
    nohup steam -bigpicture > /dev/null 2>&1 &
    
    echo "Steam launched in Big Picture mode"
fi

exit 0
