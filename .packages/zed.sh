#!/usr/bin/env bash

set -euo pipefail

command="${1:-install}"

case "$command" in
    install)
        curl -f https://zed.dev/install.sh | sh
        ;;
    uninstall)
        rm -f "$HOME/.local/bin/zed"
        rm -rf "$HOME/.local/zed.app"
        ;;
    *)
        echo "Usage: $0 [install|uninstall]"
        exit 1
        ;;
esac
