#!/bin/bash
# Start GNOME desktop environment inside Distrobox container
# This script should be placed in ~/.local/bin/start-gnome.sh inside the container

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

# With --init flag, systemd is running as PID 1
# Verify systemd user session is ready
echo "Verifying systemd user session..."

# Set up D-Bus session bus (systemd creates it in XDG_RUNTIME_DIR)
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus

if ! systemctl --user is-system-running &>/dev/null; then
    echo "Systemd user session not ready, waiting..."
    systemctl --user is-system-running --wait || true
fi

systemctl --user status >/dev/null 2>&1 && echo "Systemd user session: OK" || echo "Systemd user session: DEGRADED"

echo "Starting GNOME Session..."

# Start GNOME Session without --systemd flag (doesn't exist in Fedora 43)
# gnome-session will automatically detect and use systemd when available
exec gnome-session --session=gnome
