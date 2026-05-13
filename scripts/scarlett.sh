#!/usr/bin/env bash

set -euo pipefail

command="${1:-install}"
service="scarlett-stereo.service"

case "$command" in
    install)
        echo "[INFO] Enabling $service."
        systemctl --user enable --now "$service"
        ;;
    uninstall)
        echo "[INFO] Disabling $service."
        systemctl --user disable --now "$service" || true
        ;;
    dry-run)
        echo "[DRY-RUN] Would enable $service."
        ;;
    status)
        echo "[INFO] systemd user service status: $service"
        systemctl --user is-enabled "$service" || true
        systemctl --user is-active "$service" || true
        ;;
    *)
        echo "Usage: $0 [install|uninstall|dry-run|status]"
        exit 1
        ;;
esac
