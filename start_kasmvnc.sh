#!/bin/sh
# Custom KasmVNC startup script with reduced logging and resolution support

# Set password for kasmvnc
if [ ! -f "/home/$USER/.vnc/passwd" ]; then
    su $USER -c "echo -e \"$PASSWORD\n$PASSWORD\n\" | kasmvncpasswd -u $USER -o -w -r"
fi

rm -rf /tmp/.X1000-lock /tmp/.X11-unix/X1000

# Set default resolution if not provided
VNC_RESOLUTION=${VNC_RESOLUTION:-1280x1024}

# Parse resolution
WIDTH=$(echo $VNC_RESOLUTION | cut -d'x' -f1)
HEIGHT=$(echo $VNC_RESOLUTION | cut -d'x' -f2)

# Create VNC config directory
mkdir -p /home/$USER/.vnc
chown $USER:$USER /home/$USER/.vnc

# Create/update kasmvnc.yaml with proper settings
# Log level: 0=Error, 10=Warning, 30=Info, 100=Debug
cat > /home/$USER/.vnc/kasmvnc.yaml << EOF
logging:
  log_writer_name: all
  log_dest: logfile
  level: 30

desktop:
  resolution:
    width: ${WIDTH}
    height: ${HEIGHT}
  allow_resize: true

network:
  protocol: http
  interface: 0.0.0.0
  websocket_port: 4000
  ssl:
    require_ssl: false

user_session:
  session_type: shared
  new_session_disconnects_existing_exclusive_session: false
  concurrent_connections_prompt: false
  idle_timeout: never

runtime_configuration:
  allow_client_to_override_kasm_server_settings: true
  allow_override_standard_vnc_server_settings: true
  allow_override_list:
    - pointer.enabled
    - data_loss_prevention.clipboard.server_to_client.enabled
    - data_loss_prevention.clipboard.client_to_server.enabled
    - data_loss_prevention.clipboard.server_to_client.primary_clipboard_enabled

server:
  auto_shutdown:
    no_user_session_timeout: never
    active_user_session_timeout: never
    inactive_user_session_timeout: never

data_loss_prevention:
  clipboard:
    server_to_client:
      enabled: true
      size: unlimited
      primary_clipboard_enabled: false
    client_to_server:
      enabled: true
      size: unlimited
EOF
chown $USER:$USER /home/$USER/.vnc/kasmvnc.yaml

# Start kasmvnc (network settings are in kasmvnc.yaml)
su $USER -c "kasmvncserver :1000 -select-de xfce"

su $USER -c "pulseaudio --start"

# Start midscene-relay if enabled (after VNC is ready)
if [ "$MIDSCENE_RELAY_AUTO_START" = "1" ] || [ "$MIDSCENE_RELAY_AUTO_START" = "true" ]; then
    echo "[Service] midscene-relay: starting in background (delay 5s)..."
    (sleep 5 && su $USER -c "DISPLAY=:1000 cd /opt/midscene-relay && /usr/local/bin/npx tsx src/server.ts" > /proc/1/fd/1 2>&1) &
fi

# Keep container running without verbose log tailing
tail -f /dev/null

