#!/bin/bash
set -e

# Start D-Bus system daemon if not running
echo "Initializing D-Bus daemon..."
mkdir -p /run/dbus
if [ ! -e /var/run/dbus/pid ] || ! pgrep -x dbus-daemon > /dev/null; then
    rm -f /var/run/dbus/pid 2>/dev/null || true
    dbus-daemon --system --fork 2>/dev/null || true
fi

# Disable problematic autostart applications that require unavailable system services
echo "Disabling incompatible autostart services..."
mkdir -p /etc/xdg/autostart

# Disable xiccd (requires colord which needs system D-Bus)
if [ -f /etc/xdg/autostart/xiccd.desktop ]; then
    echo "Hidden=true" >> /etc/xdg/autostart/xiccd.desktop
fi

# Disable light-locker (requires session management)
if [ -f /etc/xdg/autostart/light-locker.desktop ]; then
    echo "Hidden=true" >> /etc/xdg/autostart/light-locker.desktop
fi

# Disable polkit-gnome (requires polkitd)
if [ -f /etc/xdg/autostart/polkit-gnome-authentication-agent-1.desktop ]; then
    echo "Hidden=true" >> /etc/xdg/autostart/polkit-gnome-authentication-agent-1.desktop
fi

# Disable nm-applet (requires NetworkManager)
if [ -f /etc/xdg/autostart/nm-applet.desktop ]; then
    echo "Hidden=true" >> /etc/xdg/autostart/nm-applet.desktop
fi

# Configure rclone for S3 if environment variables are set
if [ -n "$S3_ENDPOINT" ] && [ -n "$S3_ACCESS_KEY" ] && [ -n "$S3_SECRET_KEY" ]; then
    echo "Configuring rclone for S3..."
    
    # Create rclone config directory
    mkdir -p /root/.config/rclone
    
    # Create rclone configuration
    cat > /root/.config/rclone/rclone.conf << EOF
[s3]
type = s3
provider = Other
env_auth = false
access_key_id = ${S3_ACCESS_KEY}
secret_access_key = ${S3_SECRET_KEY}
endpoint = ${S3_ENDPOINT}
region = ${S3_REGION:-us-east-1}
acl = private
EOF

    # Create mount point
    mkdir -p /mnt/s3
    
    # Mount S3 bucket in background
    if [ -n "$S3_BUCKET" ]; then
        echo "Mounting S3 bucket: ${S3_BUCKET} to /mnt/s3..."
        rclone mount s3:${S3_BUCKET} /mnt/s3 \
            --allow-other \
            --allow-non-empty \
            --vfs-cache-mode full \
            --vfs-cache-max-age 24h \
            --daemon
        echo "S3 bucket mounted successfully."
    fi
else
    echo "S3 environment variables not set, skipping S3 mount."
fi

# Execute the original entrypoint
echo "Starting Ubuntu Desktop..."
exec /docker_config/entrypoint.sh
