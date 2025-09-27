#!/usr/bin/env bash

# Dotfiles setup script
# This script clones the dotfiles repo, manages symlinks, and sets up a Fedora GNOME container using Distrobox.

delete_symlinks=false

# Check for --delete-symlinks argument
if [[ "$1" == "--delete-symlinks" ]]; then
    delete_symlinks=true
    echo "[INFO] Symlinks will be deleted."
else
    echo "[INFO] Symlinks will be created or updated."
fi

echo "[INFO] Cloning dotfiles repository..."
if [[ -d "$HOME/.dotfiles" ]]; then
    echo "[INFO] Dotfiles repo exists. Pulling latest changes..."
    git -C "$HOME/.dotfiles" pull
else
    echo "[INFO] Cloning dotfiles repository..."
    git clone "https://github.com/atzufuki/dotfiles.git" "$HOME/.dotfiles"
fi

ignore_file="$HOME/.dotfiles/.dotfilesignore"

# Manage symlinks based on ignore file
echo "[INFO] Found .dotfilesignore, processing files..."
cd "$HOME/.dotfiles"
find . -mindepth 1 -maxdepth 1 | sed 's|^./||' | grep -vFf "$ignore_file" | grep -v "^.dotfilesignore$" | while read -r item; do
    target="/$item"
    if $delete_symlinks; then
        if [[ -L "$target" ]]; then
            echo "[INFO] Deleting symlink: $target"
            rm "$target"
        fi
    else
        echo "[INFO] Creating symlink: $target -> $HOME/.dotfiles/$item"
        sudo ln -sfn "$HOME/.dotfiles/$item" "$target"
    fi
done

# Install Distrobox if missing
if ! command -v distrobox &> /dev/null; then
    echo "[INFO] Distrobox not found. Installing via rpm-ostree..."
    sudo rpm-ostree install distrobox
    echo "[INFO] Please reboot your system, then re-run this script to complete the setup."
else
    echo "[INFO] Distrobox found. Setting up Fedora GNOME container..."
    # Create Fedora container with GNOME if missing
    if ! distrobox list | grep -q fedora-gnome; then
        echo "[INFO] Creating fedora-gnome container..."
        distrobox create --name fedora-gnome --init --additional-packages "systemd" --image registry.fedoraproject.org/fedora:rawhide
    else
        echo "[INFO] fedora-gnome container already exists."
    fi

    # Enter the container and run the bootstrap script
    echo "[INFO] Entering fedora-gnome container and running bootstrap script..."
    distrobox enter fedora-gnome -- bash ~/.dotfiles/containers/gnome/bootstrap.sh
    
    echo "[INFO] Dotfiles setup complete!"
fi

