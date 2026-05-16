#!/usr/bin/env bash
# dotfiles-depends: am

set -euo pipefail

command="${1:-apply}"
app_id="telegram"
app_name="Telegram Desktop"
bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"

if [[ -x "$bin_dir/am" && ":$PATH:" != *":$bin_dir:"* ]]; then
    export PATH="$bin_dir:$PATH"
fi

ensure_am() {
    if ! command -v am >/dev/null 2>&1; then
        echo "[ERROR] AM is required to install $app_name."
        exit 1
    fi
}

is_installed() {
    command -v "$app_id" >/dev/null 2>&1
}

case "$command" in
    apply)
        ensure_am

        if is_installed; then
            echo "[INFO] $app_name already installed, skipping."
            exit 0
        fi

        echo "[INFO] Installing $app_name with AM AppImage manager."
        am -i --user "$app_id"
        ;;
    purge)
        ensure_am

        if is_installed; then
            echo "[INFO] Removing $app_name AM user installation."
            am -R "$app_id"
        else
            echo "[INFO] $app_name is not installed, skipping."
        fi
        ;;
    dry-run)
        if is_installed; then
            echo "[DRY-RUN] $app_name is already installed."
        else
            echo "[DRY-RUN] Would install $app_name with: am -i --user $app_id"
        fi
        ;;
    status)
        if is_installed; then
            echo "[OK] $app_name installed: $(command -v "$app_id")"
        else
            echo "[MISSING] $app_name is not installed"
        fi
        ;;
    *)
        echo "Usage: $0 [apply|purge|dry-run|status]"
        exit 1
        ;;
esac
