#!/usr/bin/env bash

set -euo pipefail

command="${1:-apply}"

case "$command" in
    apply)
        if command -v opencode >/dev/null 2>&1 || [[ -x "$HOME/.opencode/bin/opencode" ]]; then
            echo "[INFO] OpenCode already installed, skipping."
            exit 0
        fi

        curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path
        ;;
    purge)
        echo "[INFO] Removing OpenCode user installation."
        rm -rf "$HOME/.opencode"
        ;;
    dry-run)
        if command -v opencode >/dev/null 2>&1 || [[ -x "$HOME/.opencode/bin/opencode" ]]; then
            echo "[DRY-RUN] OpenCode is already installed."
        else
            echo "[DRY-RUN] Would install OpenCode with https://opencode.ai/install."
        fi
        ;;
    status)
        if command -v opencode >/dev/null 2>&1; then
            echo "[OK] OpenCode installed: $(command -v opencode)"
        elif [[ -x "$HOME/.opencode/bin/opencode" ]]; then
            echo "[OK] OpenCode installed: $HOME/.opencode/bin/opencode"
        else
            echo "[MISSING] OpenCode is not installed"
        fi
        ;;
    *)
        echo "Usage: $0 [apply|purge|dry-run|status]"
        exit 1
        ;;
esac
