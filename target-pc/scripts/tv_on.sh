#!/bin/bash
# tv_on.sh
# Turn on TV via HDMI-CEC
#
# Prerequisites:
#   - Install cec-utils: sudo apt install cec-utils
#   - Your GPU must support CEC (check with: ls /dev/cec*)
#   - If no CEC device exists, you may need a Pulse-Eight USB-CEC adapter
#
# Alternative using cec-ctl (v4l-utils):
#   sudo apt install v4l-utils
#   cec-ctl --playback --image-view-on

echo "Turning on TV via HDMI-CEC..."

# Method 1: Using cec-client (libcec) - most common
# The 'on 0' command sends power on to device 0 (TV is always address 0)
if command -v cec-client &> /dev/null; then
    echo 'on 0' | cec-client -s -d 1
    
    # Also make this device the active source so TV switches input
    sleep 1
    echo 'as' | cec-client -s -d 1
    
    echo "TV power on command sent via cec-client"
    exit 0
fi

# Method 2: Using cec-ctl (kernel CEC framework)
if command -v cec-ctl &> /dev/null; then
    # Find CEC device
    CEC_DEV=$(ls /dev/cec* 2>/dev/null | head -1)
    
    if [ -n "$CEC_DEV" ]; then
        # Configure as playback device and send image view on
        cec-ctl -d "$CEC_DEV" --playback --image-view-on -t0
        echo "TV power on command sent via cec-ctl"
        exit 0
    fi
fi

echo "Error: No CEC client available. Install cec-utils or v4l-utils."
exit 1
