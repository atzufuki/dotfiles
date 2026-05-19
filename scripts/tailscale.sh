#!/usr/bin/env bash

set -euo pipefail

script_command="${1:-apply}"
service="tailscaled.service"

is_installed() {
    command -v tailscale >/dev/null 2>&1
}

install_tailscale() {
    if is_installed; then
        echo "[INFO] Tailscale already installed, skipping install."
        return 0
    fi

    echo "[INFO] Installing Tailscale with official installer."
    curl -fsSL https://tailscale.com/install.sh | sh
}

enable_service() {
    echo "[INFO] Enabling $service."
    sudo systemctl enable --now "$service"
}

print_connection_hint() {
    if tailscale status >/dev/null 2>&1; then
        echo "[OK] Tailscale is connected."
    else
        echo "[INFO] Tailscale is installed. Run: sudo tailscale up"
    fi
}

case "$script_command" in
    apply)
        install_tailscale
        enable_service
        print_connection_hint
        ;;
    purge)
        if systemctl list-unit-files "$service" >/dev/null 2>&1; then
            echo "[INFO] Disabling $service."
            sudo systemctl disable --now "$service" || true
        else
            echo "[INFO] $service is not installed, skipping."
        fi
        ;;
    dry-run)
        if is_installed; then
            echo "[DRY-RUN] Tailscale is already installed."
        else
            echo "[DRY-RUN] Would install Tailscale with https://tailscale.com/install.sh."
        fi
        echo "[DRY-RUN] Would enable $service."
        echo "[DRY-RUN] Would not run tailscale up automatically."
        ;;
    status)
        if is_installed; then
            echo "[OK] Tailscale installed: $(command -v tailscale)"
        else
            echo "[MISSING] Tailscale is not installed"
        fi

        if systemctl is-enabled "$service" >/dev/null 2>&1; then
            echo "[OK] $service enabled"
        else
            echo "[MISSING] $service is not enabled"
        fi

        if systemctl is-active "$service" >/dev/null 2>&1; then
            echo "[OK] $service active"
        else
            echo "[MISSING] $service is not active"
        fi

        if is_installed && tailscale status >/dev/null 2>&1; then
            echo "[OK] Tailscale connected"
        elif is_installed; then
            echo "[MISSING] Tailscale is not connected"
        fi
        ;;
    *)
        echo "Usage: $0 [apply|purge|dry-run|status]"
        exit 1
        ;;
esac
