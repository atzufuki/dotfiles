#!/usr/bin/env bash

set -euo pipefail

script_command="${1:-apply}"
app_name="Docker Desktop"
package_name="docker-desktop"
rpm_url="${DOCKER_DESKTOP_RPM_URL:-https://desktop.docker.com/linux/main/amd64/docker-desktop-x86_64.rpm}"
tmp_parent="${DOCKER_DESKTOP_TMPDIR:-/var/tmp}"
service="docker-desktop.service"

ensure_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "[ERROR] $command_name is required to install $app_name."
        exit 1
    fi
}

is_installed() {
    rpm -q "$package_name" >/dev/null 2>&1
}

download_rpm() {
    local rpm_file="$1"

    ensure_command curl

    echo "[INFO] Downloading $app_name RPM: $rpm_url"
    curl -fL --output "$rpm_file" "$rpm_url"
}

install_desktop() {
    local tmp rpm_file

    ensure_command rpm-ostree
    ensure_command sudo

    mkdir -p "$tmp_parent"
    tmp="$(mktemp -d "$tmp_parent/docker-desktop.XXXXXX")"
    trap 'rm -rf "$tmp"' RETURN
    rpm_file="$tmp/docker-desktop.rpm"

    download_rpm "$rpm_file"
    echo "[INFO] Layering $app_name with rpm-ostree."
    sudo rpm-ostree install --idempotent "$rpm_file"
    echo "[INFO] Reboot required before starting $service."
}

purge_desktop() {
    ensure_command rpm-ostree
    ensure_command sudo
    ensure_command systemctl

    systemctl --user disable --now "$service" >/dev/null 2>&1 || true
    if is_installed; then
        echo "[INFO] Removing $app_name rpm-ostree layer."
        sudo rpm-ostree uninstall "$package_name"
        echo "[INFO] Reboot required to complete removal."
    else
        echo "[INFO] $app_name is not layered, skipping removal."
    fi
    echo "[INFO] Kept Docker Desktop user data under $HOME/.docker/desktop if present."
}

case "$script_command" in
    apply)
        if is_installed; then
            echo "[INFO] $app_name already installed, skipping. Run: $0 update"
            exit 0
        fi

        install_desktop
        ;;
    update)
        echo "[INFO] Updating $app_name."
        install_desktop
        ;;
    purge)
        echo "[INFO] Removing $app_name."
        purge_desktop
        ;;
    dry-run)
        if is_installed; then
            echo "[DRY-RUN] $app_name is already layered with rpm-ostree."
        else
            echo "[DRY-RUN] Would layer $app_name with rpm-ostree."
        fi
        echo "[DRY-RUN] Would download: $rpm_url"
        echo "[DRY-RUN] Would run: sudo rpm-ostree install --idempotent <downloaded-rpm>"
        echo "[DRY-RUN] Reboot is required after install or update."
        ;;
    status)
        if is_installed; then
            echo "[OK] $app_name rpm-ostree layer installed"
            rpm -q "$package_name" || true
        else
            echo "[MISSING] $app_name is not layered with rpm-ostree"
        fi

        if systemctl --user is-enabled "$service" >/dev/null 2>&1; then
            echo "[OK] User $service enabled"
        else
            echo "[MISSING] User $service is not enabled"
        fi

        if systemctl --user is-active "$service" >/dev/null 2>&1; then
            echo "[OK] User $service active"
        else
            echo "[MISSING] User $service is not active"
        fi
        ;;
    *)
        echo "Usage: $0 [apply|update|purge|dry-run|status]"
        exit 1
        ;;
esac
