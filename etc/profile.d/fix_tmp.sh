#!/bin/sh
# Fix /tmp/.X11-unix permissions for rootless containers
# This is needed for XWayland to work properly in distrobox containers
chown -f -R $USER:$USER /tmp/.X11-unix 2>/dev/null || true
