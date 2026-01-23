#!/bin/bash
# JunctionRelay XSD - One-Command Installer for Raspberry Pi
# Electron AppImage - everything bundled!

set -e

REPO="catapultcase/JunctionRelay_XSD_Pi"
INSTALL_DIR="/opt/junctionrelay-xsd"
SERVICE_NAME="junctionrelay"
APPIMAGE_NAME="junctionrelay.AppImage"

echo "============================================================================"
echo "  JunctionRelay XSD Installer"
echo "============================================================================"
echo ""

if [ "$(id -u)" != "0" ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

if [ -n "$SUDO_USER" ]; then
    ACTUAL_USER="$SUDO_USER"
    ACTUAL_HOME=$(eval echo ~$SUDO_USER)
else
    ACTUAL_USER=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1; exit}' /etc/passwd)
    ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)
fi

# Get user's UID for XDG_RUNTIME_DIR
ACTUAL_UID=$(id -u "$ACTUAL_USER")

echo "[1/6] Detected user: $ACTUAL_USER (UID: $ACTUAL_UID)"
echo ""

echo "[2/6] Downloading latest release..."
LATEST_RELEASE=$(curl -s https://api.github.com/repos/$REPO/releases/latest)
VERSION=$(echo "$LATEST_RELEASE" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
DOWNLOAD_URL=$(echo "$LATEST_RELEASE" | grep '"browser_download_url":' | grep '.AppImage"' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$DOWNLOAD_URL" ]; then
    echo "  ERROR: Failed to get download URL from GitHub"
    echo "  Make sure a release exists with an AppImage asset"
    exit 1
fi

echo "  Version: $VERSION"
echo "  Downloading from: $DOWNLOAD_URL"

TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
curl -L -o "$APPIMAGE_NAME" "$DOWNLOAD_URL"
echo "  ✓ Download complete ($(du -h "$APPIMAGE_NAME" | cut -f1))"
echo ""

echo "[3/6] Installing..."

# Stop existing service if running
if systemctl is-active --quiet ${SERVICE_NAME}.service 2>/dev/null; then
    echo "  Stopping existing service..."
    systemctl stop ${SERVICE_NAME}.service
fi

# Backup existing installation
if [ -d "$INSTALL_DIR" ]; then
    echo "  Existing installation found, backing up..."
    BACKUP_DIR="${INSTALL_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    mv "$INSTALL_DIR" "$BACKUP_DIR"
    echo "  Backup saved to: $BACKUP_DIR"
fi

# Create install directory and copy AppImage
mkdir -p "$INSTALL_DIR"
cp "$APPIMAGE_NAME" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/$APPIMAGE_NAME"
chown -R ${ACTUAL_USER}:${ACTUAL_USER} "$INSTALL_DIR"
echo "  ✓ AppImage installed to $INSTALL_DIR"
echo ""

echo "[4/6] Creating startup script..."
cat > "$INSTALL_DIR/start-with-browser.sh" <<'EOFSTARTUP'
#!/bin/bash
# JunctionRelay XSD - Start with Firefox Browser

INSTALL_DIR="/opt/junctionrelay-xsd"
WEBUI_URL="http://localhost:8086/"
APPIMAGE_NAME="junctionrelay.AppImage"

# Cleanup function
cleanup() {
    if [ -n "$FIREFOX_PID" ]; then
        kill $FIREFOX_PID 2>/dev/null
    fi
}

trap cleanup EXIT SIGTERM SIGINT

# Start AppImage backend
cd "$INSTALL_DIR"
"./$APPIMAGE_NAME" --no-sandbox &
APPIMAGE_PID=$!

# Wait for backend to be ready (max 30 seconds)
for i in {1..60}; do
    if curl -s http://localhost:8086/api/health > /dev/null 2>&1; then
        break
    fi
    sleep 0.5
done

# Open Firefox in kiosk mode if DISPLAY is available
if [ -n "$DISPLAY" ]; then
    if command -v firefox &> /dev/null; then
        firefox --kiosk "$WEBUI_URL" &
        FIREFOX_PID=$!
    fi
fi

# Wait for AppImage process
wait $APPIMAGE_PID
exit $?
EOFSTARTUP

chmod +x "$INSTALL_DIR/start-with-browser.sh"
chown ${ACTUAL_USER}:${ACTUAL_USER} "$INSTALL_DIR/start-with-browser.sh"
echo "  ✓ Startup script created"
echo ""

echo "[5/6] Setting up systemd service..."
cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOFSERVICE
[Unit]
Description=JunctionRelay XSD
After=network-online.target graphical.target
Wants=network-online.target

[Service]
Type=simple
User=${ACTUAL_USER}
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/${ACTUAL_USER}/.Xauthority
Environment=WAYLAND_DISPLAY=wayland-0
Environment=XDG_RUNTIME_DIR=/run/user/${ACTUAL_UID}
Environment=MOZ_ENABLE_WAYLAND=1
WorkingDirectory=${INSTALL_DIR}
ExecStart=/bin/bash ${INSTALL_DIR}/start-with-browser.sh
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=30

[Install]
WantedBy=graphical.target
EOFSERVICE

systemctl daemon-reload
systemctl enable ${SERVICE_NAME}.service
echo "  ✓ Service configured"
echo ""

echo "[6/6] Creating update script..."
cat > "$INSTALL_DIR/update.sh" <<'EOFUPDATE'
#!/bin/bash
# JunctionRelay XSD - Update Script

set -e

REPO="catapultcase/JunctionRelay_XSD_Pi"
INSTALL_DIR="/opt/junctionrelay-xsd"
SERVICE_NAME="junctionrelay"
APPIMAGE_NAME="junctionrelay.AppImage"

if [ "$(id -u)" != "0" ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

echo "Checking for updates..."

LATEST_RELEASE=$(curl -s https://api.github.com/repos/$REPO/releases/latest)
VERSION=$(echo "$LATEST_RELEASE" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
DOWNLOAD_URL=$(echo "$LATEST_RELEASE" | grep '"browser_download_url":' | grep '.AppImage"' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$DOWNLOAD_URL" ]; then
    echo "ERROR: Failed to get download URL"
    exit 1
fi

echo "Latest version: $VERSION"
echo "Downloading..."

TEMP_DIR=$(mktemp -d)
curl -L -o "$TEMP_DIR/$APPIMAGE_NAME" "$DOWNLOAD_URL"

echo "Stopping service..."
systemctl stop ${SERVICE_NAME}.service

echo "Installing update..."
cp "$TEMP_DIR/$APPIMAGE_NAME" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/$APPIMAGE_NAME"

echo "Starting service..."
systemctl start ${SERVICE_NAME}.service

rm -rf "$TEMP_DIR"

echo ""
echo "Update complete! Version: $VERSION"
systemctl status ${SERVICE_NAME}.service --no-pager | head -n 5
EOFUPDATE

chmod +x "$INSTALL_DIR/update.sh"
chown ${ACTUAL_USER}:${ACTUAL_USER} "$INSTALL_DIR/update.sh"
echo "  ✓ Update script created"
echo ""

# Cleanup
cd /
rm -rf "$TEMP_DIR"

# Start service
echo "Starting service..."
systemctl start ${SERVICE_NAME}.service
sleep 3

echo ""
echo "============================================================================"
echo "  Installation Complete!"
echo "============================================================================"
echo ""
echo "Version: $VERSION"
echo "Install directory: $INSTALL_DIR"
echo "Service: $SERVICE_NAME"
echo ""
echo "Service status:"
systemctl status ${SERVICE_NAME}.service --no-pager | head -n 10
echo ""
echo "Firefox will auto-open to WebUI on next graphical session"
echo "Or access manually at: http://localhost:8086/"
echo ""
echo "Management commands:"
echo "  sudo systemctl status $SERVICE_NAME      # Check status"
echo "  sudo systemctl restart $SERVICE_NAME     # Restart service"
echo "  sudo systemctl stop $SERVICE_NAME        # Stop service"
echo "  sudo journalctl -u $SERVICE_NAME -f      # View logs"
echo "  sudo $INSTALL_DIR/update.sh              # Update to latest"
echo ""
