#!/bin/bash
# Weston wrapper for launching containerized GNOME desktop
# This is the entry point called by the display manager

set -e

# Detect if we're in a Wayland session or on bare TTY
if [ -n "$WAYLAND_DISPLAY" ]; then
    # Running nested in existing Wayland session
    BACKEND="wayland-backend.so"
    echo "Detected existing Wayland session, using wayland backend"
else
    # Running on TTY/GDM, use DRM with software rendering
    BACKEND="drm-backend.so"
    echo "Running on TTY, using DRM backend with software rendering"
fi

# Force use of logind by setting LIBSEAT_BACKEND
export LIBSEAT_BACKEND=logind

# Use logind launcher for seat management instead of seatd
export XDG_SEAT=seat0
export XDG_SESSION_TYPE=wayland

# Force software rendering (pixman) for VMware compatibility
# This avoids EGL/GL issues in virtual machines
export WESTON_RENDERER=pixman

# Start Weston in background
weston --backend=$BACKEND &
WESTON_PID=$!

# Wait for Weston to create Wayland socket
echo "Waiting for Weston to initialize..."
timeout=30
while [ $timeout -gt 0 ]; do
    if ls "$XDG_RUNTIME_DIR"/wayland-* &>/dev/null; then
        echo "Weston ready"
        break
    fi
    sleep 0.5
    timeout=$((timeout - 1))
done

if [ $timeout -eq 0 ]; then
    echo "ERROR: Weston failed to start"
    kill $WESTON_PID 2>/dev/null || true
    exit 1
fi

# Now launch GNOME session
/usr/local/bin/gnome-session.sh

# Cleanup when GNOME exits
kill $WESTON_PID 2>/dev/null || true
