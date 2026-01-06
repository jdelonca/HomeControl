"""
PC Control Server - Flask Application
Controls a remote PC: Wake-on-LAN, display configuration, Steam launch, shutdown
"""

import os
import time
import logging
from flask import Flask, render_template, jsonify, request
from wakeonlan import send_magic_packet
import paramiko

app = Flask(__name__)

# ============================================================================
# CONFIGURATION - Adjust these values to match your setup
# ============================================================================

CONFIG = {
    # Target PC settings
    "target_mac": "AA:BB:CC:DD:EE:FF",          # MAC address of target PC
    "target_ip": "192.168.1.100",               # IP address of target PC
    "target_user": "your_username",             # SSH username on target PC
    "ssh_key_path": "/home/server_user/.ssh/id_rsa",  # Path to SSH private key
    "ssh_port": 22,
    
    # Network settings
    "broadcast_ip": "192.168.1.255",            # Broadcast address for WoL
    "wol_port": 9,
    
    # Paths on target PC
    "wol_flag_path": "/tmp/wol_wake_flag",      # Flag file to indicate WoL wake
    "scripts_path": "/home/your_username/pc-control-scripts",  # Scripts location on target
}

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def get_ssh_client():
    """Create and return an SSH client connected to target PC."""
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        client.connect(
            hostname=CONFIG["target_ip"],
            port=CONFIG["ssh_port"],
            username=CONFIG["target_user"],
            key_filename=CONFIG["ssh_key_path"],
            timeout=10
        )
        return client
    except Exception as e:
        logger.error(f"SSH connection failed: {e}")
        raise


def execute_remote_command(command, timeout=30):
    """Execute a command on the target PC via SSH."""
    client = None
    try:
        client = get_ssh_client()
        stdin, stdout, stderr = client.exec_command(command, timeout=timeout)
        
        exit_status = stdout.channel.recv_exit_status()
        output = stdout.read().decode('utf-8').strip()
        error = stderr.read().decode('utf-8').strip()
        
        return {
            "success": exit_status == 0,
            "output": output,
            "error": error,
            "exit_status": exit_status
        }
    except Exception as e:
        logger.error(f"Remote command execution failed: {e}")
        return {
            "success": False,
            "output": "",
            "error": str(e),
            "exit_status": -1
        }
    finally:
        if client:
            client.close()


def check_target_online():
    """Check if target PC is online and reachable via SSH."""
    try:
        client = get_ssh_client()
        client.close()
        return True
    except:
        return False


# ============================================================================
# ROUTES
# ============================================================================

@app.route('/')
def index():
    """Serve the main control panel."""
    return render_template('index.html')


@app.route('/api/status')
def get_status():
    """Get current status of the target PC."""
    online = check_target_online()
    
    display_mode = "unknown"
    if online:
        result = execute_remote_command(
            f"cat {CONFIG['scripts_path']}/current_display_mode 2>/dev/null || echo 'unknown'"
        )
        if result["success"]:
            display_mode = result["output"]
    
    return jsonify({
        "online": online,
        "display_mode": display_mode
    })


@app.route('/api/wake', methods=['POST'])
def wake_pc():
    """
    Wake the PC using Wake-on-LAN and set a flag for TV mode + Steam launch.
    """
    try:
        # Send magic packet
        send_magic_packet(
            CONFIG["target_mac"],
            ip_address=CONFIG["broadcast_ip"],
            port=CONFIG["wol_port"]
        )
        logger.info(f"WoL magic packet sent to {CONFIG['target_mac']}")
        
        # Wait for PC to come online (with timeout)
        max_wait = 120  # seconds
        check_interval = 5
        waited = 0
        
        while waited < max_wait:
            time.sleep(check_interval)
            waited += check_interval
            
            if check_target_online():
                logger.info("Target PC is now online")
                
                # Create flag file to indicate WoL wake
                result = execute_remote_command(
                    f"touch {CONFIG['wol_flag_path']}"
                )
                
                if result["success"]:
                    logger.info("WoL flag created successfully")
                    return jsonify({
                        "success": True,
                        "message": "PC woken successfully. TV mode and Steam will be activated."
                    })
                else:
                    return jsonify({
                        "success": True,
                        "message": "PC woken but flag creation failed. Manual setup may be needed.",
                        "warning": result["error"]
                    })
        
        return jsonify({
            "success": False,
            "message": f"PC did not come online within {max_wait} seconds"
        })
        
    except Exception as e:
        logger.error(f"Wake failed: {e}")
        return jsonify({
            "success": False,
            "message": str(e)
        }), 500


@app.route('/api/shutdown', methods=['POST'])
def shutdown_pc():
    """Shutdown the target PC."""
    if not check_target_online():
        return jsonify({
            "success": False,
            "message": "PC is not online"
        }), 400
    
    try:
        # Use systemctl poweroff (requires sudo without password for this command)
        result = execute_remote_command("sudo systemctl poweroff")
        
        return jsonify({
            "success": True,
            "message": "Shutdown command sent"
        })
        
    except Exception as e:
        logger.error(f"Shutdown failed: {e}")
        return jsonify({
            "success": False,
            "message": str(e)
        }), 500


@app.route('/api/display/tv', methods=['POST'])
def set_display_tv():
    """Set display to TV only mode."""
    if not check_target_online():
        return jsonify({
            "success": False,
            "message": "PC is not online"
        }), 400
    
    try:
        result = execute_remote_command(
            f"bash {CONFIG['scripts_path']}/set_display_tv.sh"
        )
        
        if result["success"]:
            return jsonify({
                "success": True,
                "message": "Display set to TV mode"
            })
        else:
            return jsonify({
                "success": False,
                "message": result["error"]
            }), 500
            
    except Exception as e:
        logger.error(f"Display switch failed: {e}")
        return jsonify({
            "success": False,
            "message": str(e)
        }), 500


@app.route('/api/display/monitor', methods=['POST'])
def set_display_monitor():
    """Set display to main monitor only mode."""
    if not check_target_online():
        return jsonify({
            "success": False,
            "message": "PC is not online"
        }), 400
    
    try:
        result = execute_remote_command(
            f"bash {CONFIG['scripts_path']}/set_display_monitor.sh"
        )
        
        if result["success"]:
            return jsonify({
                "success": True,
                "message": "Display set to monitor mode"
            })
        else:
            return jsonify({
                "success": False,
                "message": result["error"]
            }), 500
            
    except Exception as e:
        logger.error(f"Display switch failed: {e}")
        return jsonify({
            "success": False,
            "message": str(e)
        }), 500


@app.route('/api/tv/on', methods=['POST'])
def turn_tv_on():
    """Turn on the TV via HDMI-CEC."""
    if not check_target_online():
        return jsonify({
            "success": False,
            "message": "PC is not online"
        }), 400
    
    try:
        result = execute_remote_command(
            f"bash {CONFIG['scripts_path']}/tv_on.sh"
        )
        
        return jsonify({
            "success": result["success"],
            "message": "TV power on command sent" if result["success"] else result["error"]
        })
            
    except Exception as e:
        logger.error(f"TV control failed: {e}")
        return jsonify({
            "success": False,
            "message": str(e)
        }), 500


@app.route('/api/tv/off', methods=['POST'])
def turn_tv_off():
    """Turn off the TV via HDMI-CEC."""
    if not check_target_online():
        return jsonify({
            "success": False,
            "message": "PC is not online"
        }), 400
    
    try:
        result = execute_remote_command(
            f"bash {CONFIG['scripts_path']}/tv_off.sh"
        )
        
        return jsonify({
            "success": result["success"],
            "message": "TV power off command sent" if result["success"] else result["error"]
        })
            
    except Exception as e:
        logger.error(f"TV control failed: {e}")
        return jsonify({
            "success": False,
            "message": str(e)
        }), 500


@app.route('/api/steam/launch', methods=['POST'])
def launch_steam():
    """Launch Steam in Big Picture mode."""
    if not check_target_online():
        return jsonify({
            "success": False,
            "message": "PC is not online"
        }), 400
    
    try:
        result = execute_remote_command(
            f"bash {CONFIG['scripts_path']}/launch_steam.sh"
        )
        
        return jsonify({
            "success": True,
            "message": "Steam launch command sent"
        })
            
    except Exception as e:
        logger.error(f"Steam launch failed: {e}")
        return jsonify({
            "success": False,
            "message": str(e)
        }), 500


if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000, debug=True)
