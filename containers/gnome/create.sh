#!/bin/bash
# Script to create GNOME Distrobox container with proper bindings
# Container provides gnome-shell and apps, host provides gnome-session

set -e

CONTAINER_NAME="gnome-box"
IMAGE_NAME="localhost/fedora-gnome:43"

echo "Creating GNOME Distrobox container..."

# Check if container already exists
if distrobox list | grep -q "$CONTAINER_NAME"; then
    echo "Container $CONTAINER_NAME already exists. Remove it first with: distrobox rm $CONTAINER_NAME"
    exit 1
fi

# Build additional flags for environment variables
# Only set WAYLAND_DISPLAY if it's available
EXTRA_ENV=""
if [ -n "$WAYLAND_DISPLAY" ]; then
    EXTRA_ENV="--env WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
fi

# Create the distrobox with all necessary bindings
# NO --init flag since systemd session runs on host
distrobox create \
    --name "$CONTAINER_NAME" \
    --image "$IMAGE_NAME" \
    --additional-flags "\
        --ipc=host \
        --security-opt label=disable \
        --privileged \
        --device /dev/dri \
        --device /dev/snd \
        --env XDG_RUNTIME_DIR=\$XDG_RUNTIME_DIR \
        $EXTRA_ENV"

echo "Container created successfully!"
echo ""
echo "Note: This container uses host's gnome-session for proper PAM registration"
echo "Container provides: gnome-shell, apps, settings daemons"
echo "Host provides: gnome-session, PAM, systemd user session"
