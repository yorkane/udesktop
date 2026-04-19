#!/bin/sh
# Custom noVNC startup script with fixed home directory resolution and resolution support

# Resolve correct home directory (handles root's /root vs /home/user)
USER_HOME=$(eval echo ~$USER)

# Create VNC config directory
mkdir -p "$USER_HOME/.vnc"
chown $USER:$USER "$USER_HOME/.vnc" 2>/dev/null || true

# Set password for TurboVNC using -f (stdin, non-interactive) mode
if [ ! -f "$USER_HOME/.vnc/passwd" ]; then
    # -f reads a plain-text password from stdin and writes the encrypted passwd file to stdout
    echo "$PASSWORD" | /opt/TurboVNC/bin/vncpasswd -f > "$USER_HOME/.vnc/passwd"
    chmod 600 "$USER_HOME/.vnc/passwd"
    chown $USER:$USER "$USER_HOME/.vnc/passwd" 2>/dev/null || true
fi

rm -rf /tmp/.X1000-lock /tmp/.X11-unix/X1000

# Set default resolution if not provided
VNC_RESOLUTION=${VNC_RESOLUTION:-1280x1024}

# Start TurboVNC with resolution
su $USER -c "/opt/TurboVNC/bin/vncserver :1000 -rfbport 5900 -geometry ${VNC_RESOLUTION}"

# Start noVNC
if [ ! -z ${DISABLE_HTTPS+x} ]; then
    su $USER -c "/opt/noVNC/utils/novnc_proxy --vnc localhost:5900 --listen 4000 --heartbeat 10 &"
else
    su $USER -c "/opt/noVNC/utils/novnc_proxy --vnc localhost:5900 --ssl-only --cert $HTTPS_CERT --key $HTTPS_CERT_KEY --listen 4000 --heartbeat 10 &"
fi

su $USER -c "pulseaudio --start" 2>/dev/null || true

# Keep container running - use correct home path for log tailing
# Fall back to tail -f /dev/null if no log files exist yet
if ls $USER_HOME/.vnc/*.log 1>/dev/null 2>&1; then
    tail -f $USER_HOME/.vnc/*.log
else
    echo "No VNC log files found at $USER_HOME/.vnc/, keeping container alive..."
    tail -f /dev/null
fi
