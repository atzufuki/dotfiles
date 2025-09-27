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

# Recursively manage symlinks, preserving deep nesting
echo "[INFO] Recursively processing dotfiles for symlinking..."
cd "$HOME/.dotfiles"
if [[ -f "$ignore_file" ]]; then
    find . -type f -o -type d | grep -vFf "$ignore_file" | while read -r item; do
        # Skip . and ..
        [[ "$item" == "." || "$item" == ".." ]] && continue
        target="/${item#./}"
        source="$HOME/.dotfiles/${item#./}"
        # Ensure parent directory exists
        parent_dir="$(dirname "$target")"
        if [[ ! -d "$parent_dir" ]]; then
            mkdir -p "$parent_dir"
        fi
        if $delete_symlinks; then
            if [[ -L "$target" ]]; then
                echo "[INFO] Deleting symlink: $target"
                rm "$target"
            fi
        else
            # Only symlink files and directories, skip if already exists and not a symlink
            if [[ -e "$target" && ! -L "$target" ]]; then
                echo "[WARN] $target exists and is not a symlink. Skipping."
            else
                echo "[INFO] Creating symlink: $target -> $source"
                ln -sfn "$source" "$target"
            fi
        fi
    done
else
    find . -type f -o -type d | while read -r item; do
        [[ "$item" == "." || "$item" == ".." ]] && continue
        target="/${item#./}"
        source="$HOME/.dotfiles/${item#./}"
        parent_dir="$(dirname "$target")"
        if [[ ! -d "$parent_dir" ]]; then
            mkdir -p "$parent_dir"
        fi
        if $delete_symlinks; then
            if [[ -L "$target" ]]; then
                echo "[INFO] Deleting symlink: $target"
                rm "$target"
            fi
        else
            if [[ -e "$target" && ! -L "$target" ]]; then
                echo "[WARN] $target exists and is not a symlink. Skipping."
            else
                echo "[INFO] Creating symlink: $target -> $source"
                ln -sfn "$source" "$target"
            fi
        fi
    done
fi

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

