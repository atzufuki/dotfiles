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
fi

# Force use of logind by setting LIBSEAT_BACKEND
export LIBSEAT_BACKEND=logind

# Use logind launcher for seat management instead of seatd
export XDG_SEAT=seat0
export XDG_SESSION_TYPE=wayland

# Launch weston in fullscreen mode with the GNOME session launcher
exec weston --backend=$BACKEND --shell=fullscreen-shell.so -- /usr/local/bin/gnome-session.sh
