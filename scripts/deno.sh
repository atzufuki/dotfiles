#!/usr/bin/env bash

set -euo pipefail

command="${1:-apply}"
deno_home="${DENO_INSTALL:-$HOME/.deno}"
deno_bin="$deno_home/bin/deno"

case "$command" in
    apply)
        if command -v deno >/dev/null 2>&1 || [[ -x "$deno_bin" ]]; then
            echo "[INFO] Deno already installed, skipping."
            exit 0
        fi

        echo "[INFO] Installing Deno in $deno_home."
        curl -fsSL https://deno.land/install.sh | sh -s -- -y --no-modify-path
        ;;
    purge)
        echo "[INFO] Removing Deno user installation."
        rm -rf "$deno_home"
        ;;
    dry-run)
        if command -v deno >/dev/null 2>&1 || [[ -x "$deno_bin" ]]; then
            echo "[DRY-RUN] Deno is already installed."
        else
            echo "[DRY-RUN] Would install Deno into $deno_home."
        fi
        ;;
    status)
        if command -v deno >/dev/null 2>&1; then
            echo "[OK] Deno installed: $(command -v deno)"
        elif [[ -x "$deno_bin" ]]; then
            echo "[OK] Deno installed: $deno_bin"
        else
            echo "[MISSING] Deno is not installed"
        fi
        ;;
    *)
        echo "Usage: $0 [apply|purge|dry-run|status]"
        exit 1
        ;;
esac
