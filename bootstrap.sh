#!/usr/bin/env bash

# Install Distrobox if missing
if ! command -v distrobox &> /dev/null; then
    sudo rpm-ostree install distrobox
fi

# Create Fedora container with GNOME
if ! distrobox list | grep -q fedora-gnome; then
    distrobox create --name fedora-gnome --init --additional-packages "systemd" --image registry.fedoraproject.org/fedora:rawhide
fi

# Enter the container and run the bootstrap script
distrobox enter fedora-gnome -- bash ./container-gnome/bootstrap.sh

echo "Bootstrap complete!"
