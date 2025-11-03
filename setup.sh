#!/bin/bash
# Automated setup script for containerized desktop environment on Fedora
# This script sets up a minimal host with GNOME running in Distrobox

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="gnome-box"
IMAGE_NAME="fedora-gnome:43"

echo "======================================"
echo "Container Desktop Environment Setup"
echo "======================================"
echo ""

# Function to check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        echo "ERROR: Do not run this script as root"
        echo "Run as regular user with sudo access"
        exit 1
    fi
}

# Function to install host packages
install_host_packages() {
    echo "Installing host system packages..."
    
    # Read packages from file
    if [ ! -f "$SCRIPT_DIR/host/packages.txt" ]; then
        echo "ERROR: host/packages.txt not found"
        exit 1
    fi
    
    # Filter out comments and empty lines
    PACKAGES=$(grep -v '^#' "$SCRIPT_DIR/host/packages.txt" | grep -v '^$' | tr '\n' ' ')
    
    echo "Packages to install: $PACKAGES"
    sudo dnf install -y $PACKAGES
    
    echo "Host packages installed successfully"
}

# Function to build container image
build_container_image() {
    echo "Building GNOME container image..."
    
    if [ ! -f "$SCRIPT_DIR/containers/gnome/Containerfile" ]; then
        echo "ERROR: containers/gnome/Containerfile not found"
        exit 1
    fi
    
    podman build -t "$IMAGE_NAME" "$SCRIPT_DIR/containers/gnome/"
    
    echo "Container image built successfully"
}

# Function to create distrobox container
create_container() {
    echo "Creating Distrobox container..."
    
    # Check if container already exists
    if distrobox list | grep -q "$CONTAINER_NAME"; then
        echo "Container $CONTAINER_NAME already exists, skipping creation"
        return
    fi
    
    # Run the create script
    bash "$SCRIPT_DIR/containers/gnome/create.sh"
    
    echo "Container created successfully"
}

# Function to setup container internals
setup_container_internals() {
    echo "Setting up container internals..."
    
    # Copy start script into container
    distrobox enter "$CONTAINER_NAME" -- mkdir -p ~/.local/bin
    
    cat "$SCRIPT_DIR/containers/gnome/start-gnome.sh" | \
        distrobox enter "$CONTAINER_NAME" -- tee ~/.local/bin/start-gnome.sh > /dev/null
    
    distrobox enter "$CONTAINER_NAME" -- chmod +x ~/.local/bin/start-gnome.sh
    
    echo "Container internals configured"
}

# Function to install host launchers
install_launchers() {
    echo "Installing host-side launchers..."
    
    # Copy bin scripts to /usr/local/bin
    sudo cp "$SCRIPT_DIR/host/bin/gnome-session.sh" /usr/local/bin/
    sudo cp "$SCRIPT_DIR/host/bin/weston-gnome-launcher.sh" /usr/local/bin/
    sudo cp "$SCRIPT_DIR/host/bin/gdm-weston-wrapper.sh" /usr/local/bin/
    
    sudo chmod +x /usr/local/bin/gnome-session.sh
    sudo chmod +x /usr/local/bin/weston-gnome-launcher.sh
    sudo chmod +x /usr/local/bin/gdm-weston-wrapper.sh
    
    # Copy desktop session file
    sudo mkdir -p /usr/share/wayland-sessions
    sudo cp "$SCRIPT_DIR/host/wayland-sessions/distrobox-gnome.desktop" \
        /usr/share/wayland-sessions/
    
    echo "Launchers installed successfully"
}

# Main execution
main() {
    check_root
    
    echo "Step 1/5: Installing host packages..."
    install_host_packages
    echo ""
    
    echo "Step 2/5: Building container image..."
    build_container_image
    echo ""
    
    echo "Step 3/5: Creating Distrobox container..."
    create_container
    echo ""
    
    echo "Step 4/5: Setting up container internals..."
    setup_container_internals
    echo ""
    
    echo "Step 5/5: Installing launchers..."
    install_launchers
    echo ""
    
    echo "======================================"
    echo "Setup completed successfully!"
    echo "======================================"
    echo ""
    echo "Next steps:"
    echo "1. Log out of your current session"
    echo "2. At the login screen, select 'GNOME (Distrobox)'"
    echo "3. Log in to enjoy your containerized desktop!"
    echo ""
    echo "To rebuild the container:"
    echo "  distrobox rm $CONTAINER_NAME"
    echo "  bash $SCRIPT_DIR/containers/gnome/create.sh"
    echo ""
}

main "$@"
