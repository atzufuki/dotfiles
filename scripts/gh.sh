#!/usr/bin/env bash

set -euo pipefail

command="${1:-apply}"
bin_dir="$HOME/.local/bin"
gh_bin="$bin_dir/gh"

install_gh() {
    local gh_os
    local gh_arch
    local gh_version
    local gh_tmp

    case "$(uname -s)" in
        Linux) gh_os="linux" ;;
        *)
            echo "[ERROR] Unsupported OS for GitHub CLI install: $(uname -s)"
            exit 1
            ;;
    esac

    case "$(uname -m)" in
        x86_64) gh_arch="amd64" ;;
        aarch64|arm64) gh_arch="arm64" ;;
        *)
            echo "[ERROR] Unsupported architecture for GitHub CLI install: $(uname -m)"
            exit 1
            ;;
    esac

    gh_version="$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | sed -n 's/.*"tag_name": "v\([^"]*\)".*/\1/p')"
    if [[ -z "$gh_version" ]]; then
        echo "[ERROR] Could not resolve latest GitHub CLI version."
        exit 1
    fi

    gh_tmp="$(mktemp -d)"
    trap 'rm -rf "$gh_tmp"' RETURN

    curl -fsSL "https://github.com/cli/cli/releases/download/v${gh_version}/gh_${gh_version}_${gh_os}_${gh_arch}.tar.gz" -o "$gh_tmp/gh.tar.gz"
    tar -xzf "$gh_tmp/gh.tar.gz" -C "$gh_tmp"
    mkdir -p "$bin_dir"
    cp "$gh_tmp/gh_${gh_version}_${gh_os}_${gh_arch}/bin/gh" "$gh_bin"
    chmod +x "$gh_bin"
}

case "$command" in
    apply)
        if command -v gh >/dev/null 2>&1 || [[ -x "$gh_bin" ]]; then
            echo "[INFO] GitHub CLI already installed, skipping."
            exit 0
        fi

        echo "[INFO] Installing GitHub CLI in $bin_dir."
        install_gh
        ;;
    purge)
        echo "[INFO] Removing GitHub CLI user installation."
        rm -f "$gh_bin"
        ;;
    dry-run)
        if command -v gh >/dev/null 2>&1 || [[ -x "$gh_bin" ]]; then
            echo "[DRY-RUN] GitHub CLI is already installed."
        else
            echo "[DRY-RUN] Would install GitHub CLI from GitHub releases into $bin_dir."
        fi
        ;;
    status)
        if command -v gh >/dev/null 2>&1; then
            echo "[OK] GitHub CLI installed: $(command -v gh)"
        elif [[ -x "$gh_bin" ]]; then
            echo "[OK] GitHub CLI installed: $gh_bin"
        else
            echo "[MISSING] GitHub CLI is not installed"
        fi
        ;;
    *)
        echo "Usage: $0 [apply|purge|dry-run|status]"
        exit 1
        ;;
esac
