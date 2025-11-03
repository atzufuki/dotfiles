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

# Start GNOME Session the same way as gnome-wayland.desktop does
# No --session parameter needed - it will use the default GNOME session
exec gnome-session
