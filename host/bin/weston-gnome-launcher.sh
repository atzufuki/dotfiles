#!/bin/bash
# Weston wrapper for launching containerized GNOME desktop
# This is the entry point called by the display manager

set -e

# Launch weston in fullscreen mode with the GNOME session launcher
# Weston will be the host compositor, GNOME Shell runs nested inside it
exec weston --backend=drm-backend.so --shell=fullscreen-shell.so -- /usr/local/bin/gnome-session.sh
