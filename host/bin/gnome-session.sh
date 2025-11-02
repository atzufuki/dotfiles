#!/bin/bash
# Host-side launcher for GNOME session in Distrobox
# This script is called by gamescope to start the containerized GNOME desktop

set -e

CONTAINER_NAME="gnome-box"

# Check if container exists
if ! distrobox list | grep -q "$CONTAINER_NAME"; then
    echo "ERROR: Container $CONTAINER_NAME does not exist"
    echo "Please run the setup script first: bash setup.sh"
    exit 1
fi

# Launch GNOME inside the container
exec distrobox enter "$CONTAINER_NAME" -- /bin/bash ~/.local/bin/start-gnome.sh
