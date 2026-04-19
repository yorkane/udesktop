#!/bin/bash
# Custom environment initialization script
# This runs after user is created but before desktop starts

# Resolve correct home directory (handles root's /root vs /home/user)
USER_HOME=$(eval echo ~$USER)

# Fix user config directory permissions for pulseaudio and code-server
if [ -n "$USER" ] && [ -d "$USER_HOME" ]; then
    echo "Fixing user directory permissions..."
    mkdir -p $USER_HOME/.config/pulse
    mkdir -p $USER_HOME/.config/code-server
    mkdir -p $USER_HOME/Desktop
    chown -R $USER:$USER $USER_HOME/.config 2>/dev/null || true
    chown -R $USER:$USER $USER_HOME/Desktop 2>/dev/null || true
fi

# Set up Chrome initial arguments
CHROME_ARGS="--remote-debugging-port=9222 --load-extension=/opt/switchyomega,/opt/midscene-ext --no-sandbox --disable-dev-shm-usage --start-maximized --test-type --no-first-run --no-default-browser-check --disable-search-engine-choice-screen --disable-infobars --password-store=basic"

if [ -n "$CHROME_PROXY_SERVER" ]; then
    echo "Applying Chrome Proxy: $CHROME_PROXY_SERVER"
    CHROME_ARGS="$CHROME_ARGS --proxy-server=$CHROME_PROXY_SERVER"
fi
if [ -n "$CHROME_NO_PROXY" ]; then
    echo "Applying Chrome No Proxy: $CHROME_NO_PROXY"
    CHROME_ARGS="$CHROME_ARGS --proxy-bypass-list=$CHROME_NO_PROXY"
fi
echo "Chrome Args: $CHROME_ARGS"

# Install Chrome .desktop to system-trusted location first
cat > /usr/share/applications/chrome.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Google Chrome
Comment=Access the Internet
Exec=/usr/local/bin/chrome $CHROME_ARGS %U
Icon=google-chrome
Terminal=false
Categories=Network;WebBrowser;
EOF
chmod +x /usr/share/applications/chrome.desktop

# Copy to user's Desktop (inherits trust from system location)
mkdir -p $USER_HOME/Desktop
# By symlinking a .desktop file located in a trusted system directory (/usr/share/applications/),
# XFCE bypasses the "Untrusted launcher" warning automatically without needing brittle GIO metadata.
ln -sf /usr/share/applications/chrome.desktop $USER_HOME/Desktop/chrome.desktop
chown -h $USER:$USER $USER_HOME/Desktop/chrome.desktop 2>/dev/null || true

# Auto-start Chrome if CHROME_AUTO_START is set
if [ "$CHROME_AUTO_START" = "1" ] || [ "$CHROME_AUTO_START" = "true" ]; then
    echo "Chrome auto-start enabled, will launch after desktop starts..."
    mkdir -p $USER_HOME/.config/autostart
    cat > $USER_HOME/.config/autostart/chrome-autostart.desktop << EOF
[Desktop Entry]
Type=Application
Name=Chrome Auto Start
Exec=/usr/local/bin/chrome $CHROME_ARGS ${CHROME_URL:-}
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
    chown -R $USER:$USER $USER_HOME/.config/autostart 2>/dev/null || true
fi

# Auto-start midscene-pc
echo "Configuring midscene-pc auto-start..."
mkdir -p $USER_HOME/.config/autostart
cat > $USER_HOME/.config/autostart/midscene-pc.desktop << EOF
[Desktop Entry]
Type=Application
Name=Midscene PC
Exec=sh -c "export DISPLAY=:1000 && cd $USER_HOME && /usr/local/bin/midscene-pc"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
chown -R $USER:$USER $USER_HOME/.config/autostart 2>/dev/null || true
# Auto-start midscene-relay (Chrome CDP relay for remote access)
if [ "$MIDSCENE_RELAY_AUTO_START" = "1" ] || [ "$MIDSCENE_RELAY_AUTO_START" = "true" ]; then
    echo "Configuring midscene-relay auto-start..."
    mkdir -p $USER_HOME/.config/autostart
    cat > $USER_HOME/.config/autostart/midscene-relay.desktop << EOF
[Desktop Entry]
Type=Application
Name=Midscene Relay
Exec=sh -c "sleep 5 && cd /opt/midscene-relay && /usr/local/bin/npx tsx src/server.ts > /proc/1/fd/1 2>&1"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
    chown -R $USER:$USER $USER_HOME/.config/autostart 2>/dev/null || true
    echo "midscene-relay will auto-start after desktop (ports: ${RELAY_PORT:-3766} SDK, ${CDP_PROXY_PORT:-9223} CDP proxy)"
fi

# Force reliable xstartup for XFCE with clipboard sync
mkdir -p $USER_HOME/.vnc
cat > $USER_HOME/.vnc/xstartup << EOF
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
# Start autocutsel for seamless VNC <-> X11 clipboard sync
autocutsel -fork -s CLIPBOARD &
autocutsel -fork -s PRIMARY &
exec /usr/bin/startxfce4
EOF
chmod +x $USER_HOME/.vnc/xstartup
chown -R $USER:$USER $USER_HOME/.vnc 2>/dev/null || true
