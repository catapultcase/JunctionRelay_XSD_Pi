#!/bin/bash
# JunctionRelay XSD - Update Script
# Electron AppImage - everything bundled!

set -e

REPO="catapultcase/JunctionRelay_XSD_Pi"
INSTALL_DIR="/opt/junctionrelay-xsd"
SERVICE_NAME="junctionrelay"
APPIMAGE_NAME="junctionrelay.AppImage"

echo "============================================================================"
echo "  JunctionRelay XSD Updater"
echo "============================================================================"
echo ""

if [ "$(id -u)" != "0" ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

if [ ! -d "$INSTALL_DIR" ]; then
    echo "ERROR: JunctionRelay is not installed at $INSTALL_DIR"
    echo "Please run the installer first:"
    echo "  curl -fsSL https://raw.githubusercontent.com/catapultcase/JunctionRelay_XSD_Pi/main/install.sh | sudo bash"
    exit 1
fi

echo "[1/4] Checking for updates..."
LATEST_RELEASE=$(curl -s https://api.github.com/repos/$REPO/releases/latest)
LATEST_VERSION=$(echo "$LATEST_RELEASE" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
DOWNLOAD_URL=$(echo "$LATEST_RELEASE" | grep '"browser_download_url":' | grep '.AppImage"' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$DOWNLOAD_URL" ]; then
    echo "  ERROR: Failed to get download URL from GitHub"
    echo "  Make sure a release exists with an AppImage asset"
    exit 1
fi

echo "  Latest version: $LATEST_VERSION"
echo ""

echo "[2/4] Downloading..."
TEMP_DIR=$(mktemp -d)
curl -L -o "$TEMP_DIR/$APPIMAGE_NAME" "$DOWNLOAD_URL"
echo "  ✓ Download complete ($(du -h "$TEMP_DIR/$APPIMAGE_NAME" | cut -f1))"
echo ""

echo "[3/4] Stopping service..."
systemctl stop ${SERVICE_NAME}.service
echo "  ✓ Service stopped"
echo ""

echo "[4/4] Installing update..."

# Backup current AppImage
if [ -f "$INSTALL_DIR/$APPIMAGE_NAME" ]; then
    BACKUP_NAME="${APPIMAGE_NAME}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$INSTALL_DIR/$APPIMAGE_NAME" "$INSTALL_DIR/$BACKUP_NAME"
    echo "  Backup saved to: $INSTALL_DIR/$BACKUP_NAME"
fi

# Install new AppImage
cp "$TEMP_DIR/$APPIMAGE_NAME" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/$APPIMAGE_NAME"

if [ -n "$SUDO_USER" ]; then
    ACTUAL_USER="$SUDO_USER"
else
    ACTUAL_USER=$(stat -c '%U' "$INSTALL_DIR")
fi
chown ${ACTUAL_USER}:${ACTUAL_USER} "$INSTALL_DIR/$APPIMAGE_NAME"

# Start service
systemctl start ${SERVICE_NAME}.service
echo "  ✓ Service started"

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "============================================================================"
echo "  Update Complete!"
echo "============================================================================"
echo ""
echo "Version: $LATEST_VERSION"
echo ""
echo "Service status:"
systemctl status ${SERVICE_NAME}.service --no-pager | head -n 10
echo ""
