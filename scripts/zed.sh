#!/usr/bin/env bash

set -euo pipefail

command="${1:-apply}"

case "$command" in
    apply)
        if command -v zed >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/zed" ]]; then
            echo "[INFO] Zed already installed, skipping."
            exit 0
        fi

        curl -f https://zed.dev/install.sh | sh
        ;;
    purge)
        echo "[INFO] Removing Zed user installation."
        rm -f "$HOME/.local/bin/zed"
        rm -rf "$HOME/.local/zed.app"
        ;;
    dry-run)
        if command -v zed >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/zed" ]]; then
            echo "[DRY-RUN] Zed is already installed."
        else
            echo "[DRY-RUN] Would install Zed with https://zed.dev/install.sh."
        fi
        ;;
    status)
        if command -v zed >/dev/null 2>&1; then
            echo "[OK] Zed installed: $(command -v zed)"
        elif [[ -x "$HOME/.local/bin/zed" ]]; then
            echo "[OK] Zed installed: $HOME/.local/bin/zed"
        else
            echo "[MISSING] Zed is not installed"
        fi
        ;;
    *)
        echo "Usage: $0 [apply|purge|dry-run|status]"
        exit 1
        ;;
esac
