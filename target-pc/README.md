# PC Control Target PC - Setup

This directory contains the scripts and configuration for the target PC (the gaming PC you want to control).

## Automated Setup (Recommended)

```bash
./setup.sh
```

The script will guide you through the entire setup process, including:
- Auto-detecting network interfaces and displays
- Installing system dependencies (ethtool, cec-utils)
- Configuring Wake-on-LAN
- Generating customized control scripts
- Setting up the startup handler
- Configuring passwordless shutdown

## What You'll Need

Before running the setup script:

1. **Be logged into a graphical session** (for display auto-detection)
2. **Know your display outputs** (or let the script auto-detect them)
   - Run `xrandr --query` to see available outputs
3. **Connect via Ethernet** (Wake-on-LAN requires wired connection)

## After Setup

**IMPORTANT**: Don't forget to enable Wake-on-LAN in BIOS/UEFI!

1. **Note your MAC address** (displayed at the end of setup)
   - You'll need this when setting up the control server

2. **Test the scripts:**
   ```bash
   cd ~/pc-control-scripts
   ./set_display_tv.sh      # Switch to TV
   ./set_display_monitor.sh # Switch to monitor
   ./tv_on.sh               # Turn on TV (if CEC supported)
   ```

3. **Enable WoL in BIOS:**
   - Reboot and enter BIOS (usually F2, F12, or DEL)
   - Find Power Management settings
   - Enable "Wake on LAN" or "Wake on PCI/PCIE"

## What Gets Installed

After setup, you'll have:

- **Scripts directory:** `~/pc-control-scripts/`
  - `set_display_tv.sh` - Switch to TV display
  - `set_display_monitor.sh` - Switch to monitor display
  - `tv_on.sh` - Turn TV on via CEC
  - `tv_off.sh` - Turn TV off via CEC
  - `launch_steam.sh` - Launch Steam in Big Picture mode
  - `wol_startup_handler.sh` - Startup automation handler
  - `current_display_mode` - Current display mode (auto-generated)

- **Startup service:** `~/.config/systemd/user/wol-startup-handler.service`
  - Automatically runs on login
  - Checks for WoL flag and configures TV mode + launches Steam

- **Sudoers file:** `/etc/sudoers.d/pc-control-shutdown`
  - Allows passwordless `sudo systemctl poweroff`

## Manual Setup

If you prefer manual setup or need to troubleshoot, see [SETUP_GUIDE.md](../SETUP_GUIDE.md) in the repository root.

## Troubleshooting

### Display switching not working

1. **Check X display access:**
   ```bash
   export DISPLAY=:0
   xrandr --query
   ```

2. **Verify display output names:**
   ```bash
   xrandr --query | grep " connected"
   ```
   Update the scripts if output names are different.

3. **Check XAUTHORITY:**
   ```bash
   echo $XAUTHORITY
   # Should be something like /run/user/1000/gdm/Xauthority
   ```

### Wake-on-LAN not working

1. **Check WoL status:**
   ```bash
   sudo ethtool enp3s0 | grep Wake-on
   # Should show: Wake-on: g
   ```

2. **Enable WoL in BIOS/UEFI** (most common issue!)

3. **Ensure Ethernet connection** (not Wi-Fi)

### CEC not working

1. **Check for CEC device:**
   ```bash
   ls /dev/cec*
   ```

2. **Test CEC:**
   ```bash
   echo 'scan' | cec-client -s -d 1
   ```

3. **Note:** Most Intel GPUs don't support CEC. You may need a Pulse-Eight USB-CEC adapter.

### Startup handler not running

1. **Check systemd user service:**
   ```bash
   systemctl --user status wol-startup-handler
   ```

2. **Enable the service:**
   ```bash
   systemctl --user enable wol-startup-handler
   ```

3. **View logs:**
   ```bash
   cat ~/.pc-control-startup.log
   ```
