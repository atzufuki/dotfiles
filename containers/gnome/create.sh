#!/bin/bash
# Script to create GNOME Distrobox container with proper bindings

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
# Using --init to enable systemd as PID 1
# This is required for gnome-session to work properly
distrobox create \
    --name "$CONTAINER_NAME" \
    --image "$IMAGE_NAME" \
    --init \
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
echo "Next steps:"
echo "1. Enter the container: distrobox enter $CONTAINER_NAME"
echo "2. Copy start-gnome.sh to ~/.local/bin/ inside the container"
echo "3. Make it executable: chmod +x ~/.local/bin/start-gnome.sh"
