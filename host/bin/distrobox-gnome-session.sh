#!/bin/bash
# Hybrid GNOME session: Host handles PAM/systemd, container provides shell/apps
# This allows proper session registration while keeping desktop in container

set -e

CONTAINER_NAME="gnome-box"

# Verify container exists
if ! distrobox list | grep -q "$CONTAINER_NAME"; then
    echo "ERROR: Container $CONTAINER_NAME does not exist" >&2
    exit 1
fi

# Run host's gnome-session with standard "gnome" session
# but override gnome-shell to use containerized version
# The wrapper at /usr/local/bin/gnome-shell will redirect to container
exec /usr/bin/gnome-session --session=gnome
