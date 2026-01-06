# HomeControl

Remote PC control system with Wake-on-LAN, display switching, and TV integration.
**Disclaimer** : this has been fully vibe-coded

## Overview

Control your gaming PC from your phone or any device on your network. Wake it up, switch between TV and monitor modes, control your TV via HDMI-CEC, and launch Steam automatically.

**Key Features:**
- Wake-on-LAN with automatic TV mode and Steam launch
- Remote shutdown
- Display switching (TV / Monitor)
- TV power control via HDMI-CEC
- Modern web interface

## Architecture

```
Control Server (Always-on host)     Target PC (Gaming PC)
┌──────────────────┐                ┌────────────────────┐
│  Flask Web App   │    SSH/WoL     │  Display Scripts   │
│  nginx proxy     │ ──────────────>│  CEC Control       │
│  Web Interface   │   Magic Packet │  Steam             │
└──────────────────┘                └────────────────────┘
         ▲
         │ HTTP
    ┌────┴────┐
    │ Browser │
    └─────────┘
```

## Quick Start

1. **Target PC Setup**: Enable Wake-on-LAN, install CEC utilities, configure scripts
2. **Control Server Setup**: Install Flask app, configure nginx, set up SSH keys
3. **Configure**: Update IP addresses, MAC addresses, and display outputs
4. **Access**: Open web interface from any device on your network

See [SETUP_GUIDE.md](SETUP_GUIDE.md) for detailed installation instructions.

## Project Structure

```
HomeControl/
├── server/              # Control server application
│   ├── app.py           # Flask backend
│   ├── templates/       # Web interface
│   └── config/          # Service and nginx configs
└── target-pc/           # Target PC scripts
    └── scripts/         # Display, CEC, and Steam scripts
```

## Requirements

**Control Server:**
- Python 3.7+
- nginx
- Network connectivity to target PC

**Target PC:**
- Linux with X11
- Wake-on-LAN capable network card
- HDMI-CEC support (optional, for TV control)
- Steam (optional, for gaming mode)

## Security

This system is designed for **private networks only**. Do not expose to the internet without proper security measures (VPN, authentication, HTTPS).

## License

See [LICENSE](LICENSE) file.
