#!/bin/bash
# Cage wrapper for launching containerized GNOME desktop
# This is the entry point called by the display manager

set -e

# Launch cage (simple Wayland compositor) with the GNOME session launcher
exec cage -- /usr/local/bin/gnome-session.sh
