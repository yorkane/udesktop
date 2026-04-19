#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PRELOAD_DIR="$SCRIPT_DIR/preload"
mkdir -p "$PRELOAD_DIR"

echo "=== Preloading build assets to $PRELOAD_DIR ==="

# 1. Node.js
NODE_TAR="node-v24.15.0-linux-x64.tar.xz"
echo "[1/4] Node.js ($NODE_TAR)..."
curl -# -fSL "https://registry.npmmirror.com/-/binary/node/v24.15.0/$NODE_TAR" \
  -o "$PRELOAD_DIR/$NODE_TAR"

# 2. SwitchyOmega V3
echo "[2/4] SwitchyOmega V3..."
wget -qO "$PRELOAD_DIR/switchy.zip" \
  "https://clients2.google.com/service/update2/crx?response=redirect&acceptformat=crx2,crx3&prodversion=114.0&x=id%3Dhihblcmlaaademjlakdpicchbjnnnkbo%26installsource%3Dondemand%26uc"

# 3. Midscene.js Extension
echo "[3/4] Midscene.js Extension..."
wget -qO "$PRELOAD_DIR/midscene-ext.zip" \
  "https://clients2.google.com/service/update2/crx?response=redirect&acceptformat=crx2,crx3&prodversion=114.0&x=id%3Dgbldofcpkknbggpkmbdaefngejllnief%26installsource%3Dondemand%26uc"

# 4. Google Chrome for Testing (latest stable)
echo "[4/4] Google Chrome for Testing..."
CHROME_VERSION=$(curl -fsSL https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions.json | jq -r '.channels.Stable.version')
echo "     Version: $CHROME_VERSION"
curl -# -fSL "https://registry.npmmirror.com/-/binary/chrome-for-testing/${CHROME_VERSION}/linux64/chrome-linux64.zip" \
  -o "$PRELOAD_DIR/chrome-linux64.zip"

echo ""
echo "=== Preload complete ==="
ls -lh "$PRELOAD_DIR"
