#!/usr/bin/env bash

# Allow local user X11 access
xhost +si:localuser:$USER >/dev/null 2>&1 || true

# Launch GNOME session in container with proper systemd user setup
# The container will have systemd available for session management
exec /usr/bin/distrobox-enter -n fedora-gnome -- \
    /usr/bin/env bash -c 'exec systemd-run --user --scope --collect gnome-session'
