#!/bin/bash
set -e

# Default S3 Configuration (can be overridden by env vars)
S3_ENDPOINT=${S3_ENDPOINT:-"https://s3rc.ai-t.wtvdev.com"}
S3_REGION=${S3_REGION:-"RegionOne"}
S3_ACCESS_KEY=${S3_ACCESS_KEY:-"R6TXQVFCPS0DW2DL8TMN"}
S3_SECRET_KEY=${S3_SECRET_KEY:-"0A6V02IRmxJbr1ApHewcmaJ1FhTMmF4UXk7Zh35t"}
S3_BUCKET=${S3_BUCKET:-"noco"}
MOUNT_POINT=${MOUNT_POINT:-"/mnt/s3/${S3_BUCKET}"}
RCLONE_CONFIG_DIR=${RCLONE_CONFIG_DIR:-"$HOME/.config/rclone"}
RCLONE_CONFIG_FILE="$RCLONE_CONFIG_DIR/rclone.conf"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[S3-MOUNT]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check for root privileges
if [ "$EUID" -ne 0 ]; then 
    error "Please run as root"
    exit 1
fi

# Install dependencies if missing
log "Checking dependencies..."
if ! command -v rclone &> /dev/null; then
    log "Installing rclone..."
    apt-get update && apt-get install -y rclone fuse3 curl
fi

if ! command -v fusermount3 &> /dev/null; then
    log "Installing fuse3..."
    apt-get install -y fuse3
fi

# Configure rclone
log "Configuring rclone..."
mkdir -p "$RCLONE_CONFIG_DIR"

cat > "$RCLONE_CONFIG_FILE" << EOF
[s3]
type = s3
provider = Other
env_auth = false
access_key_id = ${S3_ACCESS_KEY}
secret_access_key = ${S3_SECRET_KEY}
endpoint = ${S3_ENDPOINT}
region = ${S3_REGION}
acl = private
EOF

# Unmount if already mounted
# Unmount if already mounted
# Unmount if already mounted
cleanup_mount() {
    local target="$1"
    local max_retries=5
    local retries=0
    
    if mountpoint -q "$target"; then
        log "Existing mount detected at $target. Unmounting..."
        while mountpoint -q "$target" && [ $retries -lt $max_retries ]; do
            # Try standard unmount first, then lazy unmount
            fusermount3 -u "$target" 2>/dev/null || umount -l "$target" 2>/dev/null || true
            sleep 1
            retries=$((retries+1))
        done
        
        if mountpoint -q "$target"; then
            error "Failed to unmount $target after multiple attempts. Please unmount manually."
            # Don't exit here, try to process other cleanups, but return status
            return 1
        fi
        log "Unmount of $target successful."
    fi
    return 0
}

# Explicitly cleanup legacy/parent mount point if it exists and is different from current
# This prevents "resource busy" if /mnt/s3 was mounted and we are trying to mount /mnt/s3/bucket
if [ "$MOUNT_POINT" != "/mnt/s3" ]; then
    cleanup_mount "/mnt/s3" || true
fi

# Cleanup current mount point
cleanup_mount "$MOUNT_POINT" || exit 1

# Create mount point
mkdir -p "$MOUNT_POINT"

# Mount S3
# Performance flags:
# --vfs-cache-mode full: Essential for compatibility and performance. Caches reads and writes.
# --vfs-cache-max-age 24h: Keep cached files for 24h.
# --vfs-read-chunk-size 32M: Read in larger chunks.
# --vfs-read-chunk-size-limit off: Grow chunk size indefinitely.
# --buffer-size 32M: Memory buffer per file.
# --transfers 8: Parallel downloads.
# --no-modtime: Disable modtime checks for speed if precise times aren't needed (optional, safer to keep but slower). Keeping it for safety.
# --allow-other: Allow other users (and Docker containers mapping this path) to access the mount.

log "Mounting bucket '$S3_BUCKET' to '$MOUNT_POINT'..."

# Run rclone in background
rclone mount s3:${S3_BUCKET} "$MOUNT_POINT" \
    --config "$RCLONE_CONFIG_FILE" \
    --allow-other \
    --allow-non-empty \
    --vfs-cache-mode full \
    --vfs-cache-max-age 24h \
    --vfs-cache-max-size 10G \
    --vfs-read-chunk-size 32M \
    --vfs-read-chunk-size-limit off \
    --buffer-size 32M \
    --transfers 8 \
    --daemon

if [ $? -eq 0 ]; then
    log "Successfully mounted at $MOUNT_POINT"
    log "To unmount run: fusermount3 -u $MOUNT_POINT"
else
    error "Failed to mount S3 bucket"
    exit 1
fi
