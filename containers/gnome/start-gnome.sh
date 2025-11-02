#!/bin/bash
# Start GNOME desktop environment inside Distrobox container
# This script should be placed in ~/.local/bin/start-gnome.sh inside the container

# Enable logging
LOG_DIR="$HOME/dotfiles/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/start-gnome-$(date +%Y%m%d-%H%M%S).log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo "=== GNOME Session start at $(date) ==="

# Set up Wayland session environment
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=GNOME
export XDG_SESSION_CLASS=user
export XDG_SESSION_DESKTOP=gnome

# Ensure XDG_RUNTIME_DIR is set (should be passed from host)
if [ -z "$XDG_RUNTIME_DIR" ]; then
    echo "ERROR: XDG_RUNTIME_DIR is not set"
    exit 1
fi

# Wait for Wayland display to be available
echo "Waiting for Wayland display..."
timeout=30
while [ -z "$WAYLAND_DISPLAY" ] && [ $timeout -gt 0 ]; do
    # Check for any wayland socket in XDG_RUNTIME_DIR
    if ls "$XDG_RUNTIME_DIR"/wayland-* &>/dev/null; then
        export WAYLAND_DISPLAY=$(basename "$XDG_RUNTIME_DIR"/wayland-* | head -n1 | cut -d- -f2)
        echo "Found Wayland display: $WAYLAND_DISPLAY"
        break
    fi
    sleep 0.5
    timeout=$((timeout - 1))
done

if [ -z "$WAYLAND_DISPLAY" ]; then
    echo "ERROR: No Wayland display found after 15 seconds"
    exit 1
fi

echo "Container environment ready:"
echo "  WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
echo "  XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
echo ""

echo "Starting GNOME Session..."
echo "Logs saved to: $LOG_FILE"

# Start GNOME Session in background
gnome-session &
GNOME_PID=$!

echo "GNOME session started with PID: $GNOME_PID"

# Keep this script alive as long as GNOME is running
# This ensures GDM doesn't think the session has ended
while kill -0 $GNOME_PID 2>/dev/null; do
    sleep 1
done

echo "GNOME session ended"
exit 0
