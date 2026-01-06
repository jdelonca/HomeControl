# PC Control System - Setup Guide

A complete solution for remotely controlling your Linux PC:
- Wake-on-LAN with automatic TV mode + Steam launch
- Remote shutdown
- Display switching (TV / Monitor modes)
- TV power control via HDMI-CEC

## Architecture

```
┌─────────────────────┐          ┌─────────────────────┐
│   Control Server    │   SSH    │     Target PC       │
│  (Always-on host)   │ ───────► │   (Gaming PC)       │
│                     │          │                     │
│  - Flask app        │   WoL    │  - Display scripts  │
│  - nginx            │ ───────► │  - CEC control      │
│  - Web interface    │  Magic   │  - Steam            │
│                     │  Packet  │  - Startup handler  │
└─────────────────────┘          └─────────────────────┘
         ▲
         │ HTTP
         │
    ┌────┴────┐
    │ Browser │
    │ (Phone) │
    └─────────┘
```

---

## Part 1: Target PC Setup

### 1.1 Enable Wake-on-LAN

#### BIOS/UEFI Settings
1. Enter BIOS (usually F2, F12, or DEL at boot)
2. Find Power Management or Advanced settings
3. Enable "Wake on LAN" or "Wake on PCI/PCIE"
4. Save and exit

#### Linux Configuration
```bash
# Install ethtool
sudo apt install ethtool

# Check current WoL status (look for "Wake-on: g")
sudo ethtool enp3s0  # Replace with your interface name

# Find your interface name
ip link show

# Enable WoL temporarily
sudo ethtool -s enp3s0 wol g

# Make WoL persistent via systemd-networkd
# Create file: /etc/systemd/network/10-wol.link
sudo tee /etc/systemd/network/10-wol.link << 'EOF'
[Match]
# Use your MAC address
MACAddress=XX:XX:XX:XX:XX:XX

[Link]
WakeOnLan=magic
EOF

# Restart networkd
sudo systemctl restart systemd-networkd
```

#### Alternative: NetworkManager
```bash
# Enable WoL via nmcli
nmcli connection show  # Find your connection name
nmcli connection modify "Wired connection 1" 802-3-ethernet.wake-on-lan magic
```

### 1.2 Install CEC Utilities

```bash
# For HDMI-CEC control
sudo apt install cec-utils

# Check if your system has CEC support
ls /dev/cec*

# If no CEC device found, check dmesg
dmesg | grep -i cec

# Test CEC (scan for devices)
echo 'scan' | cec-client -s -d 1
```

**Note**: Most Intel GPUs don't support CEC natively. You may need a Pulse-Eight USB-CEC adapter.

### 1.3 Install Scripts on Target PC

```bash
# Create scripts directory
mkdir -p ~/pc-control-scripts
cd ~/pc-control-scripts

# Copy the scripts from the target-pc/scripts/ directory in this repository
# (set_display_tv.sh, set_display_monitor.sh, tv_on.sh, tv_off.sh,
#  launch_steam.sh, wol_startup_handler.sh)

# Make them executable
chmod +x *.sh

# IMPORTANT: Edit each script to match your display configuration!
# Run this to see your display outputs:
xrandr --query
```

### 1.4 Configure Display Scripts

Edit `set_display_tv.sh` and `set_display_monitor.sh`:

```bash
# Find your display outputs
xrandr --query | grep " connected"

# Example output:
# HDMI-1 connected 1920x1080+0+0
# DP-1 connected 1920x1080+1920+0

# Update the scripts with your actual output names
```

### 1.5 Setup Startup Handler

#### Option A: Systemd User Service (Recommended)
```bash
# Create systemd user directory
mkdir -p ~/.config/systemd/user/

# Copy the service file from target-pc/ directory
cp wol-startup-handler.service ~/.config/systemd/user/

# Edit paths in the service file
nano ~/.config/systemd/user/wol-startup-handler.service

# Enable the service
systemctl --user enable wol-startup-handler.service
```

#### Option B: Desktop Autostart
```bash
# Create autostart directory
mkdir -p ~/.config/autostart/

# Copy the desktop file
cp wol-startup-handler.desktop ~/.config/autostart/

# Edit paths
nano ~/.config/autostart/wol-startup-handler.desktop
```

### 1.6 Configure Passwordless Sudo for Shutdown

```bash
# Edit sudoers
sudo visudo

# Add this line (replace your_username):
your_username ALL=(ALL) NOPASSWD: /usr/bin/systemctl poweroff
```

### 1.7 Get Target PC Information

```bash
# MAC address (needed for WoL)
ip link show | grep ether

# IP address
ip addr show | grep "inet "
```

---

## Part 2: Control Server Setup

### 2.1 Prerequisites

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install python3 python3-pip python3-venv nginx -y
```

### 2.2 Setup SSH Key Authentication

```bash
# On the CONTROL SERVER, generate SSH key
ssh-keygen -t ed25519 -f ~/.ssh/pc_control_key -N ""

# Copy key to TARGET PC
ssh-copy-id -i ~/.ssh/pc_control_key your_username@192.168.1.100

# Test connection (should work without password)
ssh -i ~/.ssh/pc_control_key your_username@192.168.1.100 "echo 'SSH works!'"
```

### 2.3 Install Flask Application

```bash
# Create application directory
sudo mkdir -p /var/www/pc-control
sudo chown $USER:www-data /var/www/pc-control

# Copy server files from this repository's server/ directory
cp -r server/* /var/www/pc-control/

cd /var/www/pc-control

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### 2.4 Configure the Application

Edit `/var/www/pc-control/app.py` and update the `CONFIG` dictionary:

```python
CONFIG = {
    "target_mac": "XX:XX:XX:XX:XX:XX",      # Your target PC's MAC
    "target_ip": "192.168.1.100",           # Your target PC's IP
    "target_user": "your_username",         # SSH username
    "ssh_key_path": "/home/server_user/.ssh/pc_control_key",
    "broadcast_ip": "192.168.1.255",        # Your network's broadcast
    "scripts_path": "/home/your_username/pc-control-scripts",
}
```

### 2.5 Setup Systemd Service

```bash
# Copy service file from server/config/ directory
sudo cp /var/www/pc-control/config/pc-control.service /etc/systemd/system/

# Edit paths in service file
sudo nano /etc/systemd/system/pc-control.service

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable pc-control
sudo systemctl start pc-control

# Check status
sudo systemctl status pc-control
```

### 2.6 Configure Nginx

```bash
# Copy nginx config from server/config/ directory
sudo cp /var/www/pc-control/config/nginx-pc-control.conf /etc/nginx/sites-available/pc-control

# Edit the config (update paths and server_name)
sudo nano /etc/nginx/sites-available/pc-control

# Enable site
sudo ln -s /etc/nginx/sites-available/pc-control /etc/nginx/sites-enabled/

# Test nginx config
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

### 2.7 Firewall Configuration

```bash
# If using UFW
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp  # If using HTTPS
```

---

## Part 3: Testing

### Test WoL from Server

```bash
# Activate virtual environment
source /var/www/pc-control/venv/bin/activate

# Test WoL
python3 -c "from wakeonlan import send_magic_packet; send_magic_packet('XX:XX:XX:XX:XX:XX')"
```

### Test SSH Connection

```bash
ssh -i ~/.ssh/pc_control_key user@192.168.1.100 "hostname"
```

### Test Display Switching

```bash
ssh -i ~/.ssh/pc_control_key user@192.168.1.100 "bash ~/pc-control-scripts/set_display_tv.sh"
```

### Test CEC

```bash
ssh -i ~/.ssh/pc_control_key user@192.168.1.100 "bash ~/pc-control-scripts/tv_on.sh"
```

### Test Web Interface

Open in browser: `http://your-server-ip/`

---

## Troubleshooting

### WoL Not Working
1. Check BIOS WoL setting
2. Verify `ethtool enp3s0 | grep Wake-on` shows `g`
3. Ensure PC is connected via Ethernet (not Wi-Fi)
4. Check broadcast address is correct

### SSH Connection Failing
1. Verify key permissions: `chmod 600 ~/.ssh/pc_control_key`
2. Check SSH service: `systemctl status ssh`
3. Test manually: `ssh -v -i key user@host`

### Display Switching Not Working
1. Verify `DISPLAY=:0` is set
2. Check `XAUTHORITY` path
3. Run `xrandr --query` to verify output names
4. Test manually while logged in graphically

### CEC Not Working
1. Check `/dev/cec*` exists
2. Run `echo 'scan' | cec-client -s -d 1`
3. May need Pulse-Eight USB-CEC adapter
4. Verify TV has CEC enabled (Samsung: Anynet+, LG: SimpLink, etc.)

### Steam Not Launching
1. Verify Steam is installed
2. Test manually: `steam -bigpicture`
3. Check `nohup` is available

---

## Security Considerations

1. **SSH Keys**: Use key-based authentication only
2. **Network**: Keep on private network, not exposed to internet
3. **HTTPS**: Enable SSL for production use
4. **Firewall**: Restrict access to trusted IPs only
5. **Updates**: Keep all systems updated

---

## Files Reference

### Repository Structure
```
HomeControl/
├── README.md                    # Project overview
├── SETUP_GUIDE.md              # This setup guide
├── server/                     # Control server files
│   ├── app.py                  # Flask application
│   ├── wsgi.py                 # WSGI entry point
│   ├── requirements.txt        # Python dependencies
│   ├── templates/
│   │   └── index.html          # Web interface
│   └── config/
│       ├── pc-control.service  # Systemd service template
│       └── nginx-pc-control.conf  # Nginx config template
└── target-pc/                  # Target PC files
    ├── wol-startup-handler.service  # Startup service template
    └── scripts/
        ├── set_display_tv.sh
        ├── set_display_monitor.sh
        ├── tv_on.sh
        ├── tv_off.sh
        ├── launch_steam.sh
        └── wol_startup_handler.sh
```

### Deployed Structure - Control Server
```
/var/www/pc-control/
├── app.py                  # Flask application
├── wsgi.py                 # WSGI entry point
├── requirements.txt        # Python dependencies
├── templates/
│   └── index.html          # Web interface
├── config/                 # Config templates
└── venv/                   # Virtual environment

/etc/systemd/system/
└── pc-control.service      # Systemd service

/etc/nginx/sites-available/
└── pc-control              # Nginx config
```

### Deployed Structure - Target PC
```
~/pc-control-scripts/
├── set_display_tv.sh       # Switch to TV display
├── set_display_monitor.sh  # Switch to monitor display
├── tv_on.sh                # Turn on TV via CEC
├── tv_off.sh               # Turn off TV via CEC
├── launch_steam.sh         # Launch Steam
├── wol_startup_handler.sh  # Startup handler
└── current_display_mode    # Current mode (auto-generated)

~/.config/systemd/user/
└── wol-startup-handler.service  # Startup service
```
