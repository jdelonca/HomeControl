# PC Control System - Setup Guide

A complete solution for remotely controlling your Linux PC:
- Wake-on-LAN with automatic TV mode + Steam launch
- Remote shutdown
- Display switching (TV / Monitor modes)
- TV power control via HDMI-CEC

## Quick Start

**For most users, automated setup is recommended:**

1. **On your Target PC (gaming PC):**
   ```bash
   cd target-pc/
   ./setup.sh
   ```
   Note the MAC address displayed at the end - you'll need it for step 2.

2. **On your Control Server (always-on host):**
   ```bash
   cd server/
   ./setup.sh
   ```
   Enter the MAC address from step 1 when prompted.

3. **Done!** Access your control panel at `http://your-server-ip/`

**For manual setup or troubleshooting**, see the detailed sections below.

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

### Option A: Automated Setup (Recommended)

The easiest way to set up the target PC is using the automated setup script:

```bash
cd target-pc/
./setup.sh
```

The script will:
1. Prompt you for configuration (display outputs, network interface, etc.)
2. Auto-detect your network interfaces and MAC address
3. Auto-detect connected displays and resolutions
4. Install system dependencies (ethtool, cec-utils)
5. Configure Wake-on-LAN persistently
6. Generate and install all control scripts with your configuration
7. Set up the startup handler (systemd or desktop autostart)
8. Configure passwordless sudo for shutdown
9. Run basic tests and provide your MAC address

**Important**: After running the script:
1. Enable Wake-on-LAN in your BIOS/UEFI settings
2. Note your MAC address (displayed at the end) - you'll need it for the control server
3. Test the scripts manually to ensure display switching works

### Option B: Manual Setup

If you prefer manual installation or need to troubleshoot:

#### 1.1 Enable Wake-on-LAN

**BIOS/UEFI Settings:**
1. Enter BIOS (usually F2, F12, or DEL at boot)
2. Find Power Management or Advanced settings
3. Enable "Wake on LAN" or "Wake on PCI/PCIE"
4. Save and exit

**Linux Configuration:**
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

**Alternative: NetworkManager:**
```bash
# Enable WoL via nmcli
nmcli connection show  # Find your connection name
nmcli connection modify "Wired connection 1" 802-3-ethernet.wake-on-lan magic
```

#### 1.2 Install CEC Utilities

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

#### 1.3 Install Scripts on Target PC

```bash
# Create scripts directory
mkdir -p ~/pc-control-scripts
cd ~/pc-control-scripts

# Copy the scripts from the target-pc/scripts/ directory in this repository
REPO_DIR=/path/to/HomeControl
cp "$REPO_DIR/target-pc/scripts"/* ~/pc-control-scripts/

# Make them executable
chmod +x *.sh

# IMPORTANT: Edit each script to match your display configuration!
# Run this to see your display outputs:
xrandr --query
```

#### 1.4 Configure Display Scripts

Edit `set_display_tv.sh` and `set_display_monitor.sh`:

```bash
# Find your display outputs
xrandr --query | grep " connected"

# Example output:
# HDMI-1 connected 1920x1080+0+0
# DP-1 connected 1920x1080+1920+0

# Update the scripts with your actual output names
```

#### 1.5 Setup Startup Handler

**Option A: Systemd User Service (Recommended):**
```bash
# Create systemd user directory
mkdir -p ~/.config/systemd/user/

# Copy the service file from target-pc/ directory
cp /path/to/HomeControl/target-pc/wol-startup-handler.service ~/.config/systemd/user/

# Edit paths in the service file
nano ~/.config/systemd/user/wol-startup-handler.service

# Enable the service
systemctl --user enable wol-startup-handler.service
```

**Option B: Desktop Autostart:**
```bash
# Create autostart directory
mkdir -p ~/.config/autostart/

# Create the desktop file
cat > ~/.config/autostart/wol-startup-handler.desktop << EOF
[Desktop Entry]
Type=Application
Name=WoL Startup Handler
Exec=/home/your_username/pc-control-scripts/wol_startup_handler.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

chmod +x ~/.config/autostart/wol-startup-handler.desktop
```

#### 1.6 Configure Passwordless Sudo for Shutdown

```bash
# Create sudoers file (safer than editing main sudoers)
echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl poweroff" | sudo tee /etc/sudoers.d/pc-control-shutdown
sudo chmod 0440 /etc/sudoers.d/pc-control-shutdown
```

#### 1.7 Get Target PC Information

```bash
# MAC address (needed for WoL)
ip link show | grep ether

# IP address
ip addr show | grep "inet "
```

---

## Part 2: Control Server Setup

### Option A: Automated Setup (Recommended)

The easiest way to set up the control server is using the automated setup script:

```bash
cd server/
./setup.sh
```

The script will:
1. Prompt you for all necessary configuration (MAC address, IP, etc.)
2. Install system dependencies (Python, nginx, etc.)
3. Generate and configure SSH keys
4. Install the Flask application in `/var/www/pc-control`
5. Configure the systemd service
6. Set up nginx reverse proxy
7. Configure firewall rules (if using UFW)
8. Run basic tests

**Note**: The script will prompt you for the SSH key to be copied to the target PC. You can do this in a separate terminal:
```bash
ssh-copy-id -i ~/.ssh/pc_control_key your_username@192.168.1.100
```

### Option B: Manual Setup

If you prefer manual installation or need to troubleshoot:

#### 2.1 Prerequisites

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install python3 python3-pip python3-venv nginx -y
```

#### 2.2 Setup SSH Key Authentication

```bash
# On the CONTROL SERVER, generate SSH key
ssh-keygen -t ed25519 -f ~/.ssh/pc_control_key -N ""

# Copy key to TARGET PC
ssh-copy-id -i ~/.ssh/pc_control_key.pub your_username@192.168.1.100

# Test connection (should work without password)
ssh -i ~/.ssh/pc_control_key your_username@192.168.1.100 "echo 'SSH works!'"
```

#### 2.3 Install Flask Application

```bash
# Create application directory
sudo mkdir -p /var/www/pc-control
sudo chown $USER:www-data /var/www/pc-control

# Copy server files from this repository's server/ directory
REPO_DIR=/path/to/HomeControl
cp -r "$REPO_DIR/server"/* /var/www/pc-control/

cd /var/www/pc-control

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

deactivate
```

#### 2.4 Configure the Application

Edit `/var/www/pc-control/app.py` and update the `CONFIG` dictionary:

```python
CONFIG = {
    "target_mac": "XX:XX:XX:XX:XX:XX",      # Your target PC's MAC
    "target_ip": "192.168.1.100",           # Your target PC's IP
    "target_user": "your_username",         # SSH username
    "ssh_key_path": "/home/server_user/.ssh/pc_control_key",
    "ssh_port": 22,
    "broadcast_ip": "192.168.1.255",        # Your network's broadcast
    "scripts_path": "/home/your_username/pc-control-scripts",
}
```

#### 2.5 Setup Systemd Service

```bash
# Create systemd service file
sudo tee /etc/systemd/system/pc-control.service > /dev/null << 'EOF'
[Unit]
Description=PC Control Flask Application
After=network.target

[Service]
User=your_username
Group=www-data
WorkingDirectory=/var/www/pc-control
Environment="PATH=/var/www/pc-control/venv/bin"
ExecStart=/var/www/pc-control/venv/bin/gunicorn \
    --workers 2 \
    --bind unix:/var/www/pc-control/pc-control.sock \
    --timeout 120 \
    -m 007 \
    wsgi:app
Restart=always
RestartSec=5
NoNewPrivileges=yes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
EOF

# Edit the User field to match your username
sudo nano /etc/systemd/system/pc-control.service

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable pc-control
sudo systemctl start pc-control

# Check status
sudo systemctl status pc-control
```

#### 2.6 Configure Nginx

```bash
# Create nginx configuration
sudo tee /etc/nginx/sites-available/pc-control > /dev/null << 'EOF'
server {
    listen 80;
    server_name _;

    access_log /var/log/nginx/pc-control-access.log;
    error_log /var/log/nginx/pc-control-error.log;

    location / {
        proxy_pass http://unix:/var/www/pc-control/pc-control.sock;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Increase timeout for WoL operations
        proxy_read_timeout 180s;
        proxy_connect_timeout 180s;
        proxy_send_timeout 180s;
    }

    location /static {
        alias /var/www/pc-control/static;
        expires 30d;
    }
}
EOF

# Enable site
sudo ln -s /etc/nginx/sites-available/pc-control /etc/nginx/sites-enabled/

# Test nginx config
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

#### 2.7 Firewall Configuration

```bash
# If using UFW
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp  # If using HTTPS later
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
│   ├── setup.sh                # Automated setup script
│   ├── app.py                  # Flask application
│   ├── wsgi.py                 # WSGI entry point
│   ├── requirements.txt        # Python dependencies
│   ├── templates/
│   │   └── index.html          # Web interface
│   └── config/
│       ├── pc-control.service  # Systemd service template
│       └── nginx-pc-control.conf  # Nginx config template
└── target-pc/                  # Target PC files
    ├── setup.sh                # Automated setup script
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
