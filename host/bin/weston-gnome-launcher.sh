#!/bin/bash
# Weston wrapper for launching containerized GNOME desktop
# This is the entry point called by the display manager

# Enable logging
LOG_DIR="$HOME/dotfiles/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/weston-gnome-launcher-$(date +%Y%m%d-%H%M%S).log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo "=== Session started at $(date) ==="
echo "Environment:"
env | sort
echo ""

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

# Now launch GNOME session and wait for it to finish
echo "Starting GNOME session at $(date)"
/usr/local/bin/gnome-session.sh &
GNOME_PID=$!
echo "GNOME session PID: $GNOME_PID"

# Wait for GNOME session to finish
echo "Waiting for GNOME session to finish..."
wait $GNOME_PID
GNOME_EXIT=$?
echo "GNOME session exited with code: $GNOME_EXIT at $(date)"

# Cleanup when GNOME exits
echo "Cleaning up Weston..."
kill $WESTON_PID 2>/dev/null || true
wait $WESTON_PID 2>/dev/null || true

echo "Session ended at $(date)"
echo "Log saved to: $LOG_FILE"
