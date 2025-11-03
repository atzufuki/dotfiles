#!/bin/bash
# Test script: Run GNOME Shell nested in Weston
# Run this from a working GNOME host session

echo "Starting Weston with nested GNOME Shell..."
echo ""

# Start Weston in window mode
weston --width=1920 --height=1080 &
WESTON_PID=$!

# Wait for Weston to be ready
sleep 2

# Export Weston's Wayland display
export WAYLAND_DISPLAY=wayland-1

# Start GNOME Shell as a nested client inside Weston
# Using distrobox to run it in the container
echo "Starting GNOME Shell in container..."
distrobox-enter -n gnome-box -- env WAYLAND_DISPLAY=$WAYLAND_DISPLAY /usr/bin/gnome-shell &
GNOME_PID=$!

echo ""
echo "Weston PID: $WESTON_PID"
echo "GNOME Shell PID: $GNOME_PID"
echo ""
echo "Press Ctrl+C to stop"

# Wait
wait $GNOME_PID

# Cleanup
kill $WESTON_PID 2>/dev/null
