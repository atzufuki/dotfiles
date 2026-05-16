#!/usr/bin/env bash

set -euo pipefail

command="${1:-apply}"
bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
am_bin="$bin_dir/am"
am_url="https://raw.githubusercontent.com/ivan-hc/AM/main/APP-MANAGER"
appman_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/appman"
appman_config_file="$appman_config_dir/appman-config"
apps_dir="$HOME/Applications"

ensure_appman_config() {
    if [[ -f "$appman_config_file" ]]; then
        return 0
    fi

    mkdir -p "$appman_config_dir" "$apps_dir"
    printf '%s\n' "$apps_dir" > "$appman_config_file"
}

sync_am() {
    if command -v am >/dev/null 2>&1; then
        am -s
    elif [[ -x "$am_bin" ]]; then
        "$am_bin" -s
    fi
}

case "$command" in
    apply)
        if command -v am >/dev/null 2>&1 || [[ -x "$am_bin" ]]; then
            echo "[INFO] AM already installed, skipping."
            ensure_appman_config
            sync_am
            exit 0
        fi

        echo "[INFO] Installing AM in $bin_dir."
        mkdir -p "$bin_dir"
        curl -fsSL "$am_url" -o "$am_bin"
        chmod +x "$am_bin"
        ensure_appman_config
        sync_am
        ;;
    purge)
        echo "[INFO] Removing AM user installation."
        rm -f "$am_bin"
        ;;
    dry-run)
        if command -v am >/dev/null 2>&1 || [[ -x "$am_bin" ]]; then
            echo "[DRY-RUN] AM is already installed."
        else
            echo "[DRY-RUN] Would install AM into $bin_dir."
        fi
        if [[ -f "$appman_config_file" ]]; then
            echo "[DRY-RUN] AM user apps directory is configured: $(<"$appman_config_file")"
        else
            echo "[DRY-RUN] Would configure AM user apps directory: $apps_dir"
        fi
        ;;
    status)
        if command -v am >/dev/null 2>&1; then
            echo "[OK] AM installed: $(command -v am)"
        elif [[ -x "$am_bin" ]]; then
            echo "[OK] AM installed: $am_bin"
        else
            echo "[MISSING] AM is not installed"
        fi
        ;;
    *)
        echo "Usage: $0 [apply|purge|dry-run|status]"
        exit 1
        ;;
esac
