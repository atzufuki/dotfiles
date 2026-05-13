#!/usr/bin/env bash

# Dotfiles bootstrap script.
# This script clones or updates the repo and installs the dotfiles commands.

usage() {
    cat <<'EOF'
Usage: setup.sh [--help]

Clones or updates https://github.com/atzufuki/dotfiles.git at $HOME/.dotfiles
and installs these commands through $HOME/.local/bin:

  dotfiles
  dot

Run `dotfiles install` after setup to install the dotfiles.
EOF
}

if [[ $# -gt 1 ]]; then
    usage
    exit 1
fi

case "${1:-}" in
    --help|-h|help)
        usage
        exit 0
        ;;
    "")
        ;;
    *)
        usage
        exit 1
        ;;
esac

repo_url="https://github.com/atzufuki/dotfiles.git"
repo_dir="$HOME/.dotfiles"
bin_dir="$HOME/.local/bin"
dotfiles_script="$repo_dir/dotfiles.sh"

if [[ -d "$repo_dir/.git" ]]; then
    echo "[INFO] Dotfiles repo exists. Pulling latest changes..."
    git -C "$repo_dir" pull
elif [[ -e "$repo_dir" ]]; then
    echo "[ERROR] $repo_dir exists but is not a git repo."
    exit 1
else
    echo "[INFO] Cloning dotfiles repository..."
    git clone "$repo_url" "$repo_dir"
fi

if [[ ! -f "$dotfiles_script" ]]; then
    echo "[ERROR] Dotfiles command script not found: $dotfiles_script"
    exit 1
fi

mkdir -p "$bin_dir"
chmod +x "$dotfiles_script"

echo "[INFO] Installing commands in $bin_dir..."
ln -sfn "$dotfiles_script" "$bin_dir/dotfiles"
ln -sfn "$dotfiles_script" "$bin_dir/dot"

if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
    echo "[WARN] $bin_dir is not in PATH for this shell. Open a new shell or add it to PATH."
fi

echo "[INFO] Bootstrap complete. Run: dotfiles install"
