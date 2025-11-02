#!/bin/bash
# GDM-compatible wrapper for Weston+GNOME session
# This ensures proper session registration with systemd-logind

set -e

# This wrapper is called by GDM and must:
# 1. Register with systemd-logind
# 2. Keep running until session ends
# 3. Properly cleanup on exit

# Ensure we have a proper systemd user scope
if [ -n "$XDG_SESSION_ID" ]; then
    echo "Running in GDM session $XDG_SESSION_ID"
else
    echo "Warning: No XDG_SESSION_ID set"
fi

# Run the actual launcher in foreground
# The launcher must not daemonize or exit early
exec /usr/local/bin/weston-gnome-launcher.sh
