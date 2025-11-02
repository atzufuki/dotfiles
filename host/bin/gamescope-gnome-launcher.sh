#!/bin/bash
# Gamescope wrapper for launching containerized GNOME desktop
# This is the entry point called by the display manager

set -e

# Launch gamescope with the GNOME session launcher
# Using minimal flags for maximum compatibility
exec gamescope -- /usr/local/bin/gnome-session.sh
