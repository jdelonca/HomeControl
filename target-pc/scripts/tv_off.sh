#!/bin/bash
# tv_off.sh
# Turn off TV (standby) via HDMI-CEC

echo "Turning off TV via HDMI-CEC..."

if command -v cec-client &> /dev/null; then
    # Put TV into standby mode
    echo 'standby 0' | cec-client -s -d 1
    echo "TV standby command sent"
    exit 0
fi

echo "Error: cec-client not found. Install with: sudo apt install cec-utils"
exit 1
