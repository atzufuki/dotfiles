#!/usr/bin/env bash

# Dotfiles setup script
# This script clones the dotfiles repo and manages symlinks.

usage() {
    echo "Usage: $0 [install|uninstall]"
}

if [[ $# -gt 1 ]]; then
    usage
    exit 1
fi

command="${1:-install}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$script_dir"

if [[ $# -eq 0 ]]; then
    repo_dir="$HOME/.dotfiles"
fi

case "$command" in
    install)
        echo "[INFO] Installing dotfiles."
        ;;
    uninstall)
        echo "[INFO] Uninstalling dotfiles."
        ;;
    *)
        usage
        exit 1
        ;;
esac

if [[ "$command" == "install" && $# -eq 0 ]]; then
    if [[ -d "$HOME/.dotfiles" ]]; then
        echo "[INFO] Dotfiles repo exists. Pulling latest changes..."
        git -C "$HOME/.dotfiles" pull
    else
        echo "[INFO] Cloning dotfiles repository..."
        git clone "https://github.com/atzufuki/dotfiles.git" "$HOME/.dotfiles"
    fi
fi

ignore_file="$repo_dir/.dotfilesignore"

if [[ ! -d "$repo_dir" ]]; then
    echo "[ERROR] Dotfiles repo not found: $repo_dir"
    exit 1
fi

if [[ ! -f "$ignore_file" ]]; then
    echo "[ERROR] Ignore file not found: $ignore_file"
    exit 1
fi

echo "[INFO] Found .dotfilesignore, processing files..."
cd "$repo_dir" || exit 1

if [[ "$command" == "uninstall" ]]; then
    echo "[INFO] Disabling scarlett-stereo.service..."
    systemctl --user disable --now scarlett-stereo.service || true
fi

find . -type f | sed 's|^./||' | grep -vFf "$ignore_file" | grep -v "^.dotfilesignore$" | while read -r item; do
    target="/$item"
    if [[ "$command" == "uninstall" ]]; then
        if [[ -L "$target" ]]; then
            echo "[INFO] Deleting symlink: $target"
            sudo rm "$target"
        fi
    else
        # Ensure parent directory exists
        sudo mkdir -p "$(dirname "$target")"
        echo "[INFO] Creating symlink: $target -> $repo_dir/$item"
        sudo ln -sfn "$repo_dir/$item" "$target"
    fi
done

if [[ "$command" == "install" ]]; then
    echo "[INFO] Enabling scarlett-stereo.service..."
    systemctl --user daemon-reload
    systemctl --user enable --now scarlett-stereo.service
else
    echo "[INFO] Reloading user systemd state..."
    systemctl --user daemon-reload
fi

echo "[INFO] Dotfiles setup complete!"
