# PC Control Server - Setup

This directory contains the Flask-based control server that manages your remote PC.

## Automated Setup (Recommended)

```bash
./setup.sh
```

The script will guide you through the entire setup process, including:
- Installing system dependencies
- Generating SSH keys
- Configuring the Flask application
- Setting up systemd service
- Configuring nginx reverse proxy
- Testing the installation

## What You'll Need

Before running the setup script, have this information ready:

- **Target PC MAC address** (you'll get this from running the target PC setup)
- **Target PC IP address** (e.g., `192.168.1.100`)
- **Target PC SSH username** (the username you use to log in)
- **Network broadcast address** (usually auto-detected, e.g., `192.168.1.255`)

## After Setup

Once setup is complete, you can:

1. **Access the web interface:**
   - Open `http://your-server-ip/` in any browser

2. **Check service status:**
   ```bash
   sudo systemctl status pc-control
   ```

3. **View logs:**
   ```bash
   sudo journalctl -u pc-control -f
   ```

4. **Restart service:**
   ```bash
   sudo systemctl restart pc-control
   ```

## Manual Setup

If you prefer manual setup or need to troubleshoot, see [SETUP_GUIDE.md](../SETUP_GUIDE.md) in the repository root.

## Troubleshooting

### Service won't start
Check the logs:
```bash
sudo journalctl -u pc-control -xe
```

Common issues:
- SSH key permissions (should be `600`)
- Wrong paths in `app.py` configuration
- Python dependencies not installed

### Can't access web interface
1. Check if service is running: `sudo systemctl status pc-control`
2. Check nginx: `sudo systemctl status nginx`
3. Check firewall: `sudo ufw status`

### Wake-on-LAN not working
1. Test from the server:
   ```bash
   source /var/www/pc-control/venv/bin/activate
   python3 -c "from wakeonlan import send_magic_packet; send_magic_packet('XX:XX:XX:XX:XX:XX')"
   ```
2. Ensure target PC has WoL enabled in BIOS
3. Verify target PC is connected via Ethernet (not Wi-Fi)
