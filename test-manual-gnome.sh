#!/bin/bash
# Manual test script for GNOME Shell nested in Weston
# Run this in TTY (Ctrl+Alt+F3)

set -e

echo "=== Manual GNOME Shell Test ==="
echo ""

# 1. Setup environment for Weston
echo "Step 1: Setting up Weston environment..."
export LIBSEAT_BACKEND=logind
export WESTON_RENDERER=pixman
export XDG_SEAT=seat0
export XDG_SESSION_TYPE=wayland

# 2. Start Weston in background
echo "Step 2: Starting Weston in background..."
weston --backend=drm-backend.so &
WESTON_PID=$!
echo "Weston started with PID: $WESTON_PID"

# 3. Wait for Weston to initialize
echo "Step 3: Waiting for Weston to initialize..."
sleep 3

# 4. Check for Wayland socket
echo "Step 4: Checking for Wayland socket..."
if ls $XDG_RUNTIME_DIR/wayland-* &>/dev/null; then
    echo "Found Wayland sockets:"
    ls -la $XDG_RUNTIME_DIR/wayland-*
else
    echo "ERROR: No Wayland socket found!"
    kill $WESTON_PID
    exit 1
fi

# 5. Start GNOME Shell in container
echo "Step 5: Starting GNOME Shell in nested mode inside container..."
echo "Press Ctrl+C to stop"
echo ""

distrobox enter gnome-box -- bash -c '
export WAYLAND_DISPLAY=wayland-0
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=GNOME
export XDG_SESSION_CLASS=user
export XDG_SESSION_DESKTOP=gnome

echo "Container environment:"
echo "  WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
echo "  XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
echo ""

echo "Starting GNOME Shell..."
gnome-shell --wayland --nested --no-x11
'

# Cleanup
echo ""
echo "Cleaning up..."
kill $WESTON_PID 2>/dev/null || true
echo "Done"
