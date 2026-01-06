#!/bin/bash
# tv_off.sh
# Turn off TV (standby) via HDMI-CEC
#
# Prerequisites:
#   - Install cec-utils: sudo apt install cec-utils
#   - Your GPU must support CEC (check with: ls /dev/cec*)

echo "Turning off TV via HDMI-CEC..."

# Method 1: Using cec-client (libcec)
if command -v cec-client &> /dev/null; then
    # The 'standby 0' command puts device 0 (TV) into standby
    echo 'standby 0' | cec-client -s -d 1
    echo "TV standby command sent via cec-client"
    exit 0
fi

# Method 2: Using cec-ctl (kernel CEC framework)
if command -v cec-ctl &> /dev/null; then
    CEC_DEV=$(ls /dev/cec* 2>/dev/null | head -1)
    
    if [ -n "$CEC_DEV" ]; then
        cec-ctl -d "$CEC_DEV" --standby -t0
        echo "TV standby command sent via cec-ctl"
        exit 0
    fi
fi

echo "Error: No CEC client available. Install cec-utils or v4l-utils."
exit 1
