#!/bin/bash
# JunctionRelay XSD - Start with Firefox Browser
# This script starts the AppImage backend and opens Firefox to the WebUI

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
