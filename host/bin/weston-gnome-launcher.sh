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
    # Running on TTY/GDM, use DRM
    BACKEND="drm-backend.so"
    echo "Running on TTY, using DRM backend"
    
    # Try to start seatd if not running
    if ! pgrep -x seatd >/dev/null; then
        echo "Starting seatd..."
        sudo seatd -g video &
        sleep 1
    fi
fi

# Launch weston in fullscreen mode with the GNOME session launcher
exec weston --backend=$BACKEND --shell=fullscreen-shell.so -- /usr/local/bin/gnome-session.sh
