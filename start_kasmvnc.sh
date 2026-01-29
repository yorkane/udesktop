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

server:
  http:
    httpd_directory: /usr/share/kasmvnc/www
EOF
chown $USER:$USER /home/$USER/.vnc/kasmvnc.yaml

# Start kasmvnc
if [ ! -z ${DISABLE_HTTPS+x} ]; then
  su $USER -c "kasmvncserver :1000 -select-de xfce -interface 0.0.0.0 -websocketPort 4000 -sslOnly 0 -RectThreads $VNC_THREADS"
else
  su $USER -c "kasmvncserver :1000 -select-de xfce -interface 0.0.0.0 -websocketPort 4000 -cert $HTTPS_CERT -key $HTTPS_CERT_KEY -RectThreads $VNC_THREADS"
fi

su $USER -c "pulseaudio --start"

# Keep container running without verbose log tailing
tail -f /dev/null

