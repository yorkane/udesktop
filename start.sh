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

# ====== Inline entrypoint with service toggles ======
# (replaces exec /docker_config/entrypoint.sh to allow conditional service startup)

echo "Starting services..."

## 1. One-time initialization (user creation, env hooks)
if [ ! -f "/docker_config/init_flag" ]; then
    echo "Running first-time initialization..."
    # set python is python3
    update-alternatives --install /usr/bin/python python /usr/bin/python3 2
    # update /etc/environment
    export PATH=/usr/NX/scripts/vgl:$PATH
    env | grep -Ev "CMD=|PWD=|SHLVL=|_=|DEBIAN_FRONTEND=|USER=|HOME=|UID=|GID=|PASSWORD=" > /etc/environment
    # create user
    groupadd -g $GID $USER 2>/dev/null || true
    useradd --create-home --no-log-init -u $UID -g $GID $USER 2>/dev/null || true
    usermod -aG sudo $USER
    usermod -aG ssl-cert $USER 2>/dev/null || true
    echo "root:$PASSWORD" | chpasswd
    echo "$USER:$PASSWORD" | chpasswd
    chsh -s /bin/bash $USER
    # /run/user/$UID
    mkdir -p /run/user/$UID
    chown $GID:$UID /run/user/$UID
    # extra env init for developer
    if [ -f "/docker_config/env_init.sh" ]; then
        bash /docker_config/env_init.sh
    fi
    # custom env init for user
    if [ -f "/docker_config/custom_env_init.sh" ]; then
        bash /docker_config/custom_env_init.sh
    fi
    echo "ok" > /docker_config/init_flag
fi

## 2. Custom startup hook
if [ -f "/docker_config/custom_startup.sh" ]; then
    bash /docker_config/custom_startup.sh
fi

## 3. SSH server (default: enabled)
if [ "$ENABLE_SSH" = "0" ] || [ "$ENABLE_SSH" = "false" ]; then
    echo "[Service] SSH: DISABLED"
else
    echo "[Service] SSH: starting..."
    /usr/sbin/sshd
fi

## 4. code-server (default: enabled)
if [ "$ENABLE_CODE_SERVER" = "0" ] || [ "$ENABLE_CODE_SERVER" = "false" ]; then
    echo "[Service] code-server: DISABLED"
else
    echo "[Service] code-server: starting on port 5000..."
    if [ ! -z ${DISABLE_HTTPS+x} ]; then
        su $USER -c "code-server --bind-addr=0.0.0.0:5000 &"
    else
        su $USER -c "code-server --cert $HTTPS_CERT --cert-key $HTTPS_CERT_KEY --bind-addr=0.0.0.0:5000 &"
    fi
fi

## 5. Remote desktop (always needed for VNC access)
if [ "${REMOTE_DESKTOP}" = "nomachine" ]; then
    echo "[Service] Remote Desktop: nomachine"
    bash /docker_config/start_nomachine.sh
elif [ "${REMOTE_DESKTOP}" = "kasmvnc" ]; then
    echo "[Service] Remote Desktop: kasmvnc"
    bash /docker_config/start_kasmvnc.sh
elif [ "${REMOTE_DESKTOP}" = "novnc" ]; then
    echo "[Service] Remote Desktop: novnc"
    bash /docker_config/start_novnc.sh
else
    echo "[Service] Unsupported remote desktop: $REMOTE_DESKTOP"
fi
