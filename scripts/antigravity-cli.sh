#!/usr/bin/env bash

set -euo pipefail

script_command="${1:-apply}"
app_name="Antigravity CLI"
install_url="${ANTIGRAVITY_CLI_INSTALL_URL:-https://antigravity.google/cli/install.sh}"
bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
binary="$bin_dir/agy"

ensure_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "[ERROR] $command_name is required to install $app_name."
        exit 1
    fi
}

is_installed() {
    [[ -x "$binary" ]]
}

install_antigravity_cli() {
    ensure_command bash
    ensure_command curl

    echo "[INFO] Installing $app_name with official installer: $install_url"
    curl -fsSL "$install_url" | bash -s -- --dir "$bin_dir"
}

case "$script_command" in
    apply)
        if is_installed; then
            echo "[INFO] $app_name already installed: $binary"
            echo "[INFO] $app_name self-updates during regular runs."
            exit 0
        fi

        install_antigravity_cli
        ;;
    update)
        echo "[INFO] $app_name self-updates during regular runs."
        if is_installed; then
            "$binary" install --dir "$bin_dir" --skip-path || true
        else
            install_antigravity_cli
        fi
        ;;
    purge)
        echo "[INFO] Removing $app_name binary."
        rm -f "$binary"
        echo "[INFO] Kept Antigravity config/cache under home directory."
        ;;
    dry-run)
        if is_installed; then
            echo "[DRY-RUN] $app_name is already installed: $binary"
        else
            echo "[DRY-RUN] Would install $app_name using: $install_url"
            echo "[DRY-RUN] Would install binary to: $binary"
        fi
        ;;
    status)
        if is_installed; then
            echo "[OK] $app_name installed: $binary"
            "$binary" --version 2>/dev/null || true
        else
            echo "[MISSING] $app_name is not installed by this script"
        fi
        ;;
    *)
        echo "Usage: $0 [apply|update|purge|dry-run|status]"
        exit 1
        ;;
esac
