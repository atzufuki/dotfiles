#!/usr/bin/env bash

# Fix X11 socket permissions for rootless container
chown -f -R $USER:$USER /tmp/.X11-unix

# Ensure systemd user instance is started for GNOME session
if ! systemctl --user is-active --quiet; then
    if command -v systemd-user-sessions >/dev/null 2>&1; then
        systemd-user-sessions start 2>/dev/null || true
    fi
fi
