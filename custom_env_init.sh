#!/bin/bash
# Custom environment initialization script
# This runs after user is created but before desktop starts

# Fix user config directory permissions for pulseaudio and code-server
if [ -n "$USER" ] && [ -d "/home/$USER" ]; then
    echo "Fixing user directory permissions..."
    mkdir -p /home/$USER/.config/pulse
    mkdir -p /home/$USER/.config/code-server
    mkdir -p /home/$USER/Desktop
    chown -R $USER:$USER /home/$USER/.config 2>/dev/null || true
    chown -R $USER:$USER /home/$USER/Desktop 2>/dev/null || true
fi

# Construct Chrome Launch Arguments
CHROME_ARGS="--no-sandbox --disable-dev-shm-usage --start-maximized --test-type --no-first-run --no-default-browser-check --disable-search-engine-choice-screen --disable-infobars --password-store=basic"

if [ -n "$CHROME_PROXY_SERVER" ]; then
    echo "Applying Chrome Proxy: $CHROME_PROXY_SERVER"
    CHROME_ARGS="$CHROME_ARGS --proxy-server=$CHROME_PROXY_SERVER"
fi
if [ -n "$CHROME_NO_PROXY" ]; then
    echo "Applying Chrome No Proxy: $CHROME_NO_PROXY"
    CHROME_ARGS="$CHROME_ARGS --proxy-bypass-list=$CHROME_NO_PROXY"
fi
echo "Chrome Args: $CHROME_ARGS"

# Create/Overwrite Chrome desktop shortcut with dynamic args
mkdir -p /home/$USER/Desktop
cat > /home/$USER/Desktop/chrome.desktop << EOF
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
chown $USER:$USER /home/$USER/Desktop/chrome.desktop 2>/dev/null || true
chmod +x /home/$USER/Desktop/chrome.desktop

# Auto-start Chrome if CHROME_AUTO_START is set
if [ "$CHROME_AUTO_START" = "1" ] || [ "$CHROME_AUTO_START" = "true" ]; then
    echo "Chrome auto-start enabled, will launch after desktop starts..."
    mkdir -p /home/$USER/.config/autostart
    cat > /home/$USER/.config/autostart/chrome-autostart.desktop << EOF
[Desktop Entry]
Type=Application
Name=Chrome Auto Start
Exec=/usr/local/bin/chrome $CHROME_ARGS ${CHROME_URL:-}
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
    chown -R $USER:$USER /home/$USER/.config/autostart 2>/dev/null || true
fi

# Create and register script to trust desktop shortcuts (runs on session login)
cat > /usr/local/bin/trust-shortcuts.sh << 'EOF'
#!/bin/bash
# Wait for desktop to be ready
# Retry loop to ensure desktop session is fully loaded
MAX_RETRIES=10
for ((i=1; i<=MAX_RETRIES; i++)); do
    if [ -d "$HOME/Desktop" ]; then
        FOUND=0
        for file in "$HOME/Desktop/"*.desktop; do
            if [ -f "$file" ]; then
                FOUND=1
                echo "Processing $file..."
                
                # Ensure executable
                chmod +x "$file"
                
                # Trust the shortcut
                # Try with standard session dbus
                gio set "$file" metadata::trusted yes 2>/dev/null || \
                # Try forcing a launch if session bus not found (fallback)
                dbus-launch gio set "$file" metadata::trusted yes 2>/dev/null || true
            fi
        done
        # If we processed files, we can exit, but let's wait a bit more to be sure XFCE picked it up? 
        # Actually once marked, it should be good.
        if [ "$FOUND" -eq 1 ]; then
            break
        fi
    fi
    sleep 2
done

# Cleanup
rm -f "$HOME/.config/autostart/trust-shortcuts.desktop"
EOF
chmod +x /usr/local/bin/trust-shortcuts.sh

# Create autostart entry for trust script
mkdir -p /home/$USER/.config/autostart
cat > /home/$USER/.config/autostart/trust-shortcuts.desktop << EOF
[Desktop Entry]
Type=Application
Name=Trust Shortcuts
Exec=/usr/local/bin/trust-shortcuts.sh
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF
chown -R $USER:$USER /home/$USER/.config/autostart 2>/dev/null || true

# Auto-start midscene-pc
echo "Configuring midscene-pc auto-start..."
mkdir -p /home/$USER/.config/autostart
cat > /home/$USER/.config/autostart/midscene-pc.desktop << EOF
[Desktop Entry]
Type=Application
Name=Midscene PC
Exec=sh -c "cd /home/$USER && /usr/local/bin/midscene-pc"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
chown -R $USER:$USER /home/$USER/.config/autostart 2>/dev/null || true

# Force reliable xstartup for XFCE
mkdir -p /home/$USER/.vnc
cat > /home/$USER/.vnc/xstartup << EOF
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec /usr/bin/startxfce4
EOF
chmod +x /home/$USER/.vnc/xstartup
chown -R $USER:$USER /home/$USER/.vnc 2>/dev/null || true


