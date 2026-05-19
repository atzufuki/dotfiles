#!/usr/bin/env bash

set -euo pipefail

script_command="${1:-apply}"
app_name="Docker Engine"
service="docker.service"
packages=(moby-engine docker-cli containerd)
static_install_dir="/usr/local/bin"
static_service_file="/etc/systemd/system/$service"
daemon_config_dir="/etc/docker"
daemon_config_file="$daemon_config_dir/daemon.json"
state_dir="/var/lib/docker"

ensure_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "[ERROR] $command_name is required to install $app_name."
        exit 1
    fi
}

is_installed() {
    rpm -q "${packages[@]}" >/dev/null 2>&1
}

installed_by_old_static_script() {
    [[ -x "$static_install_dir/docker" && -x "$static_install_dir/dockerd" && -f "$static_service_file" ]] &&
        grep -Fq "$static_install_dir/dockerd" "$static_service_file"
}

cleanup_old_static_install() {
    local binary

    ensure_command sudo
    ensure_command systemctl

    if ! installed_by_old_static_script; then
        return 0
    fi

    echo "[INFO] Removing old static Docker installation from $static_install_dir."
    sudo systemctl disable --now "$service" >/dev/null 2>&1 || true
    sudo rm -f "$static_service_file"
    for binary in docker dockerd containerd containerd-shim containerd-shim-runc-v2 ctr docker-init docker-proxy runc; do
        sudo rm -f "$static_install_dir/$binary"
    done
    sudo rm -f /var/run/docker.pid /run/docker.pid
    sudo systemctl daemon-reload
}

install_docker() {
    ensure_command rpm-ostree
    ensure_command sudo

    cleanup_old_static_install
    echo "[INFO] Layering $app_name packages with rpm-ostree: ${packages[*]}"
    sudo rpm-ostree install --idempotent "${packages[@]}"
    echo "[INFO] Reboot required before enabling $service."
}

enable_service() {
    ensure_command sudo
    ensure_command systemctl

    echo "[INFO] Enabling $service."
    sudo systemctl enable --now "$service"
}

configure_group() {
    ensure_command sudo

    if ! getent group docker >/dev/null 2>&1; then
        echo "[INFO] Creating docker group."
        sudo groupadd docker
    fi

    if ! id -nG "$USER" | tr ' ' '\n' | grep -Fxq docker; then
        echo "[INFO] Adding $USER to docker group. Log out and back in before using docker without sudo."
        sudo usermod -aG docker "$USER"
    fi
}

purge_docker() {
    ensure_command rpm-ostree
    ensure_command sudo
    ensure_command systemctl

    sudo systemctl disable --now "$service" >/dev/null 2>&1 || true
    cleanup_old_static_install
    if is_installed; then
        echo "[INFO] Removing $app_name rpm-ostree packages: ${packages[*]}"
        sudo rpm-ostree uninstall "${packages[@]}"
        echo "[INFO] Reboot required to complete removal."
    else
        echo "[INFO] $app_name packages are not layered, skipping removal."
    fi
    echo "[INFO] Kept Docker state under $state_dir."
    echo "[INFO] Kept Docker daemon config at $daemon_config_file."
}

case "$script_command" in
    apply)
        if is_installed; then
            echo "[INFO] $app_name packages already installed, ensuring group and service. Run: $0 update"
            cleanup_old_static_install
            configure_group
            enable_service
            exit 0
        fi

        install_docker
        configure_group
        ;;
    update)
        echo "[INFO] Updating $app_name packages."
        install_docker
        configure_group
        ;;
    purge)
        purge_docker
        ;;
    dry-run)
        if is_installed; then
            echo "[DRY-RUN] $app_name rpm-ostree packages are already installed."
        else
            echo "[DRY-RUN] Would layer $app_name packages with rpm-ostree: ${packages[*]}"
        fi
        echo "[DRY-RUN] Would remove old static install if present in: $static_install_dir"
        echo "[DRY-RUN] Would create docker group and add user: $USER"
        echo "[DRY-RUN] Reboot is required after install, update, or removal."
        ;;
    status)
        if is_installed; then
            echo "[OK] $app_name rpm-ostree packages installed"
            rpm -q "${packages[@]}" || true
        else
            echo "[MISSING] $app_name rpm-ostree packages are not all installed"
        fi

        if installed_by_old_static_script; then
            echo "[WARN] Old static Docker installation is still present at $static_install_dir"
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

        if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
            echo "[OK] Docker daemon reachable"
        elif command -v docker >/dev/null 2>&1; then
            echo "[MISSING] Docker daemon is not reachable by current user"
        fi
        ;;
    *)
        echo "Usage: $0 [apply|update|purge|dry-run|status]"
        exit 1
        ;;
esac
