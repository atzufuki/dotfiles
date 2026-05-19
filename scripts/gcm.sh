#!/usr/bin/env bash

set -euo pipefail

script_command="${1:-apply}"
app_name="Git Credential Manager"
bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
app_dir="${XDG_OPT_HOME:-$HOME/.local/opt}/git-credential-manager"
gcm_bin="$app_dir/git-credential-manager"
launcher="$bin_dir/git-credential-manager"
tmp_parent="${GCM_TMPDIR:-/var/tmp}"

ensure_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "[ERROR] $command_name is required to install $app_name."
        exit 1
    fi
}

archive_arch() {
    case "$(uname -m)" in
        x86_64)
            echo "x64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        *)
            echo "[ERROR] Unsupported architecture for $app_name: $(uname -m)" >&2
            exit 1
            ;;
    esac
}

latest_version() {
    local version

    version="$(curl -fsSL https://api.github.com/repos/git-ecosystem/git-credential-manager/releases/latest | sed -n 's/.*"tag_name": "v\([^"]*\)".*/\1/p')"
    if [[ -z "$version" ]]; then
        echo "[ERROR] Could not resolve latest $app_name version." >&2
        exit 1
    fi

    echo "$version"
}

archive_url() {
    local arch
    local version

    if [[ -n "${GCM_ARCHIVE_URL:-}" ]]; then
        echo "$GCM_ARCHIVE_URL"
        return 0
    fi

    arch="$(archive_arch)"
    version="$(latest_version)"
    echo "https://github.com/git-ecosystem/git-credential-manager/releases/download/v${version}/gcm-linux-${arch}-${version}.tar.gz"
}

is_installed() {
    [[ -x "$gcm_bin" && -x "$launcher" ]]
}

install_launcher() {
    mkdir -p "$bin_dir"
    ln -sfn "$gcm_bin" "$launcher"
}

configure_git() {
    ensure_command git

    echo "[INFO] Configuring git credential.helper: $launcher"
    git config --global credential.helper "$launcher"
}

install_gcm() {
    local tmp archive url

    ensure_command curl
    ensure_command git
    ensure_command tar

    url="$(archive_url)"
    mkdir -p "$tmp_parent"
    tmp="$(mktemp -d "$tmp_parent/gcm.XXXXXX")"
    trap 'rm -rf "$tmp"' RETURN
    archive="$tmp/gcm.tar.gz"

    echo "[INFO] Downloading $app_name archive: $url"
    curl -fL --output "$archive" "$url"

    echo "[INFO] Extracting $app_name archive."
    rm -rf "$app_dir"
    mkdir -p "$app_dir"
    tar -xzf "$archive" -C "$app_dir"

    if [[ ! -x "$gcm_bin" ]]; then
        echo "[ERROR] Archive did not contain executable: $gcm_bin"
        exit 1
    fi

    install_launcher
    configure_git
}

purge_gcm() {
    if command -v git >/dev/null 2>&1; then
        git config --global --fixed-value --unset-all credential.helper "$launcher" 2>/dev/null || true
        git config --global --fixed-value --unset-all credential.helper "$gcm_bin" 2>/dev/null || true
    fi

    if [[ -L "$launcher" && "$(readlink "$launcher")" == "$gcm_bin" ]]; then
        rm -f "$launcher"
    fi

    rm -rf "$app_dir"
}

case "$script_command" in
    apply)
        if is_installed; then
            echo "[INFO] $app_name already installed at $gcm_bin, refreshing launcher and git config. Run: $0 update"
            install_launcher
            configure_git
            exit 0
        fi

        install_gcm
        ;;
    update)
        echo "[INFO] Updating $app_name."
        install_gcm
        ;;
    purge)
        echo "[INFO] Removing $app_name user installation."
        purge_gcm
        ;;
    dry-run)
        if is_installed; then
            echo "[DRY-RUN] $app_name is already installed at $gcm_bin."
        else
            echo "[DRY-RUN] Would download and extract archive from: $(archive_url)"
            echo "[DRY-RUN] Would install to: $app_dir"
        fi
        echo "[DRY-RUN] Would install launcher: $launcher"
        echo "[DRY-RUN] Would set global git credential.helper to: $launcher"
        ;;
    status)
        if is_installed; then
            echo "[OK] $app_name installed: $gcm_bin"
            "$gcm_bin" --version || true
        else
            echo "[MISSING] $app_name is not installed by this script"
        fi

        if command -v git >/dev/null 2>&1 && git config --global --get-all credential.helper | grep -Fxq "$launcher"; then
            echo "[OK] git credential.helper configured: $launcher"
        else
            echo "[MISSING] git credential.helper is not configured for $app_name"
        fi
        ;;
    *)
        echo "Usage: $0 [apply|update|purge|dry-run|status]"
        exit 1
        ;;
esac
