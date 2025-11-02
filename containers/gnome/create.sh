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

# Create the distrobox with all necessary bindings
distrobox create \
    --name "$CONTAINER_NAME" \
    --image "$IMAGE_NAME" \
    --init \
    --additional-flags "\
        --ipc=host \
        --security-opt label=disable \
        --device /dev/dri \
        --device /dev/snd \
        --volume=\$XDG_RUNTIME_DIR:\$XDG_RUNTIME_DIR \
        --env XDG_RUNTIME_DIR=\$XDG_RUNTIME_DIR \
        --env WAYLAND_DISPLAY=\$WAYLAND_DISPLAY"

echo "Container created successfully!"
echo ""
echo "Next steps:"
echo "1. Enter the container: distrobox enter $CONTAINER_NAME"
echo "2. Copy start-gnome.sh to ~/.local/bin/ inside the container"
echo "3. Make it executable: chmod +x ~/.local/bin/start-gnome.sh"
