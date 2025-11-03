#!/bin/bash
# Direct GNOME launcher - launches containerized GNOME as display server
# This is the entry point called by the display manager

set -e

# Force use of logind by setting LIBSEAT_BACKEND
export LIBSEAT_BACKEND=logind

# Use logind launcher for seat management
export XDG_SEAT=seat0
export XDG_SESSION_TYPE=wayland

echo "Launching GNOME session directly (no nested compositor)"
echo "Session started at $(date)"

# Launch GNOME session directly - it will act as the display server
exec /usr/local/bin/gnome-session.sh
