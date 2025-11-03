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

# Function to setup display manager
setup_display_manager() {
    echo "======================================"
    echo "Display Manager Selection"
    echo "======================================"
    echo ""
    echo "Choose how you want to log in:"
    echo "1) SDDM - Simple Desktop Display Manager (recommended for Distrobox)"
    echo "2) GDM - GNOME Display Manager (may have issues with Distrobox)"
    echo "3) Autologin - Automatic login to GNOME (no display manager)"
    echo ""
    read -p "Enter your choice (1-3): " DM_CHOICE
    echo ""
    
    case $DM_CHOICE in
        1)
            echo "Setting up SDDM..."
            sudo dnf install -y sddm
            
            # Disable other display managers
            systemctl is-enabled gdm &>/dev/null && sudo systemctl disable gdm
            
            # Enable SDDM
            sudo systemctl enable sddm
            
            echo "SDDM configured successfully"
            echo "Note: You'll need to reboot for the change to take effect"
            ;;
        2)
            echo "Setting up GDM..."
            sudo dnf install -y gdm
            
            # Disable other display managers
            systemctl is-enabled sddm &>/dev/null && sudo systemctl disable sddm
            
            # Enable GDM
            sudo systemctl enable gdm
            
            echo "GDM configured successfully"
            echo "WARNING: GDM may have session registration issues with Distrobox"
            echo "Note: You'll need to reboot for the change to take effect"
            ;;
        3)
            echo "Setting up autologin..."
            
            # Get current username
            CURRENT_USER=$(logname 2>/dev/null || echo $SUDO_USER)
            if [ -z "$CURRENT_USER" ]; then
                echo "ERROR: Could not determine current user"
                exit 1
            fi
            
            # Disable display managers
            systemctl is-enabled gdm &>/dev/null && sudo systemctl disable gdm
            systemctl is-enabled sddm &>/dev/null && sudo systemctl disable sddm
            
            # Create autologin configuration
            sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
            sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf > /dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin $CURRENT_USER %I \$TERM
EOF
            
            # Create .bash_profile to auto-start GNOME on TTY1
            cat >> "$HOME/.bash_profile" <<'EOF'

# Auto-start GNOME on TTY1 (only once)
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ] && [ -z "$GNOME_STARTED" ]; then
    export GNOME_STARTED=1
    exec distrobox-enter -n gnome-box -- /usr/bin/gnome-session
fi
EOF
            
            echo "Autologin configured successfully for user: $CURRENT_USER"
            echo "GNOME will start automatically on TTY1 after login"
            echo "Note: You'll need to reboot for the change to take effect"
            ;;
        *)
            echo "Invalid choice. Skipping display manager setup."
            ;;
    esac
    echo ""
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
    
    # Copy desktop session file
    sudo mkdir -p /usr/share/wayland-sessions
    sudo cp "$SCRIPT_DIR/host/wayland-sessions/distrobox-gnome.desktop" \
        /usr/share/wayland-sessions/
    
    # Install launcher scripts
    sudo mkdir -p /usr/local/bin
    sudo cp "$SCRIPT_DIR/host/bin/distrobox-gnome-session.sh" /usr/local/bin/
    sudo chmod +x /usr/local/bin/distrobox-gnome-session.sh
    
    # Install gnome-shell wrapper (redirects to container)
    sudo cp "$SCRIPT_DIR/host/bin/gnome-shell" /usr/local/bin/
    sudo chmod +x /usr/local/bin/gnome-shell
    
    # Install /tmp/.X11-unix fix for XWayland
    sudo mkdir -p /etc/profile.d
    sudo cp "$SCRIPT_DIR/etc/profile.d/fix_tmp.sh" /etc/profile.d/
    sudo chmod +x /etc/profile.d/fix_tmp.sh
    
    echo "Launchers installed successfully"
}

# Main execution
main() {
    check_root
    
    echo "Step 1/6: Installing host packages..."
    install_host_packages
    echo ""
    
    echo "Step 2/6: Setting up display manager (SDDM)..."
    setup_display_manager
    echo ""
    
    echo "Step 3/6: Building container image..."
    build_container_image
    echo ""
    
    echo "Step 4/5: Creating Distrobox container..."
    create_container
    echo ""
    
    echo "Step 5/5: Installing launchers..."
    install_launchers
    echo ""
    
    echo "======================================"
    echo "Setup completed successfully!"
    echo "======================================"
    echo ""
    echo "IMPORTANT: Reboot your system for all changes to take effect"
    echo ""
    echo "Next steps:"
    echo "1. Reboot your system: sudo reboot"
    if [ "$DM_CHOICE" = "3" ]; then
        echo "2. GNOME will start automatically after reboot"
    else
        echo "2. At the login screen, select 'GNOME (Distrobox)'"
        echo "3. Log in to enjoy your containerized desktop!"
    fi
    echo ""
    echo "To rebuild the container:"
    echo "  distrobox rm $CONTAINER_NAME"
    echo "  bash $SCRIPT_DIR/containers/gnome/create.sh"
    echo ""
}

main "$@"
