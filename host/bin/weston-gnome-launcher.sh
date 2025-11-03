#!/bin/bash
# Weston kiosk launcher for containerized GNOME desktop
# This is the entry point called by the display manager

set -e

# Force use of logind by setting LIBSEAT_BACKEND
export LIBSEAT_BACKEND=logind

# Use logind launcher for seat management
export XDG_SEAT=seat0
export XDG_SESSION_TYPE=wayland

echo "Launching Weston in kiosk mode with GNOME"
echo "Session started at $(date)"

# Launch Weston in kiosk mode - it will hide itself and only show GNOME
# The --shell=kiosk-shell.so makes Weston fullscreen the client (GNOME)
exec weston --shell=kiosk-shell.so -- /usr/local/bin/gnome-session.sh
