#!/bin/bash
# tv_on.sh
# Turn on TV via HDMI-CEC and switch to this HDMI input

echo "Turning on TV via HDMI-CEC..."

if command -v cec-client &> /dev/null; then
    # Power on TV
    echo 'on 0' | cec-client -s -d 1

    # Wait for TV to power on and be ready
    sleep 5

    # Make this device the active source (switches TV to this HDMI input)
    echo 'as' | cec-client -s -d 1

    echo "TV powered on and input switched"
    exit 0
fi

echo "Error: cec-client not found. Install with: sudo apt install cec-utils"
exit 1
