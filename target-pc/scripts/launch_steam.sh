#!/bin/bash
# launch_steam.sh
# Launch Steam in Big Picture mode
#
# This script launches Steam with Big Picture mode, suitable for TV/couch gaming

# Get the display (for headless SSH access)
export DISPLAY=:0

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

echo "Using Steam at: $STEAM_PATH"

# Check if Steam is already running
if pgrep -x "steam" > /dev/null; then
    echo "Steam is already running"

    # Try to switch to Big Picture mode
    # This uses Steam's URL handler
    "$STEAM_PATH" steam://open/bigpicture &
else
    # Launch Steam with Big Picture mode
    # Need to ensure we're running in the user's D-Bus session
    # This is critical for Steam to work properly from systemd
    if [ -n "$DBUS_SESSION_BUS_ADDRESS" ]; then
        echo "D-Bus session available: $DBUS_SESSION_BUS_ADDRESS"
    else
        echo "WARNING: No D-Bus session address set"
        # Try to detect it
        DBUS_FILE="/run/user/$(id -u)/bus"
        if [ -S "$DBUS_FILE" ]; then
            export DBUS_SESSION_BUS_ADDRESS="unix:path=$DBUS_FILE"
            echo "Set D-Bus to: $DBUS_SESSION_BUS_ADDRESS"
        fi
    fi

    # Launch Steam with Big Picture mode
    # Use systemd-run if available for proper session integration
    if command -v systemd-run &> /dev/null; then
        echo "Using systemd-run for clean session launch"
        systemd-run --user --scope --quiet \
            env DISPLAY="$DISPLAY" \
                XAUTHORITY="$XAUTHORITY" \
                DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
            "$STEAM_PATH" -bigpicture
    else
        # Fallback: Use nohup with explicit file descriptors
        echo "Using direct launch"
        nohup "$STEAM_PATH" -bigpicture >/dev/null 2>&1 </dev/null &
        disown
    fi

    echo "Steam launched"
fi

exit 0
