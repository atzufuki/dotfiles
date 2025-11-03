#!/bin/bash
# Start GNOME from TTY
# Usage: Run this from a TTY (Ctrl+Alt+F3) after logging in

echo "Starting GNOME from TTY..."
echo "This will start GNOME in Distrobox container"
echo ""

# Start GNOME session directly
exec distrobox-enter -n gnome-box -- /usr/bin/gnome-session
