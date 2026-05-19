#!/usr/bin/env bash

set -euo pipefail

script_command="${1:-apply}"
app_name="Docker Desktop"
rpm_url="${DOCKER_DESKTOP_RPM_URL:-https://desktop.docker.com/linux/main/amd64/docker-desktop-x86_64.rpm}"
opt_dir="/opt/docker-desktop"
tmp_parent="${DOCKER_DESKTOP_TMPDIR:-/var/tmp}"
user_systemd_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
desktop_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
service="docker-desktop.service"
service_file="$user_systemd_dir/$service"
desktop_file="$desktop_dir/docker-desktop.desktop"
uri_desktop_file="$desktop_dir/docker-desktop-uri-handler.desktop"

ensure_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "[ERROR] $command_name is required to install $app_name."
        exit 1
    fi
}

ensure_extractor() {
    if command -v bsdtar >/dev/null 2>&1; then
        return 0
    fi

    if command -v rpm2cpio >/dev/null 2>&1 && command -v cpio >/dev/null 2>&1; then
        return 0
    fi

    echo "[ERROR] bsdtar or rpm2cpio + cpio is required to extract the Docker Desktop RPM."
    exit 1
}

extract_rpm() {
    local rpm_file="$1"
    local target_dir="$2"

    mkdir -p "$target_dir"
    if command -v bsdtar >/dev/null 2>&1; then
        bsdtar -xf "$rpm_file" -C "$target_dir"
    else
        (
            cd "$target_dir"
            rpm2cpio "$rpm_file" | cpio -idm --quiet
        )
    fi
}

is_installed() {
    [[ -x "$opt_dir/bin/docker-desktop" && -f "$service_file" ]]
}

install_desktop_file() {
    local source_file="$1"
    local target_file="$2"

    install_user_file "$source_file" "$target_file"
    update-desktop-database "$desktop_dir" >/dev/null 2>&1 || true
}

install_user_file() {
    local source_file="$1"
    local target_file="$2"
    local target_dir

    target_dir="$(dirname "$target_file")"

    if install -D -m 0644 "$source_file" "$target_file" 2>/dev/null; then
        return 0
    fi

    sudo install -d -o "$(id -u)" -g "$(id -g)" "$target_dir"
    sudo install -o "$(id -u)" -g "$(id -g)" -m 0644 "$source_file" "$target_file"
}

install_service_file() {
    local source_file="$1"

    install_user_file "$source_file" "$service_file"
    systemctl --user daemon-reload
}

install_desktop() {
    local tmp rpm_file root_dir source_opt

    ensure_command curl
    ensure_command sudo
    ensure_command systemctl
    ensure_extractor

    mkdir -p "$tmp_parent"
    tmp="$(mktemp -d "$tmp_parent/docker-desktop.XXXXXX")"
    trap 'rm -rf "$tmp"' RETURN
    rpm_file="$tmp/docker-desktop.rpm"
    root_dir="$tmp/root"

    echo "[INFO] Downloading $app_name RPM: $rpm_url"
    curl -fL --output "$rpm_file" "$rpm_url"

    echo "[INFO] Extracting $app_name RPM."
    extract_rpm "$rpm_file" "$root_dir"
    source_opt="$root_dir/opt/docker-desktop"

    if [[ ! -x "$source_opt/bin/docker-desktop" || ! -x "$source_opt/bin/com.docker.backend" ]]; then
        echo "[ERROR] RPM did not contain expected Docker Desktop binaries."
        exit 1
    fi

    echo "[INFO] Installing $app_name to $opt_dir."
    systemctl --user stop "$service" >/dev/null 2>&1 || true
    sudo rm -rf "$opt_dir"
    sudo mkdir -p "$(dirname "$opt_dir")"
    sudo cp -a "$source_opt" "$opt_dir"

    if command -v restorecon >/dev/null 2>&1; then
        sudo restorecon -RF "$opt_dir" >/dev/null 2>&1 || true
    fi

    if command -v setcap >/dev/null 2>&1 && [[ -f "$opt_dir/chrome-sandbox" ]]; then
        sudo setcap cap_sys_admin,cap_setuid,cap_setgid+ep "$opt_dir/chrome-sandbox" >/dev/null 2>&1 || true
    fi

    install_service_file "$root_dir/usr/lib/systemd/user/docker-desktop.service"
    install_desktop_file "$root_dir/usr/share/applications/docker-desktop.desktop" "$desktop_file"
    install_desktop_file "$root_dir/usr/share/applications/docker-desktop-uri-handler.desktop" "$uri_desktop_file"
}

purge_desktop() {
    ensure_command sudo
    ensure_command systemctl

    systemctl --user disable --now "$service" >/dev/null 2>&1 || true
    rm -f "$service_file" "$desktop_file" "$uri_desktop_file"
    systemctl --user daemon-reload
    sudo rm -rf "$opt_dir"
    update-desktop-database "$desktop_dir" >/dev/null 2>&1 || true
    echo "[INFO] Kept Docker Desktop user data under $HOME/.docker/desktop if present."
}

case "$script_command" in
    apply)
        if is_installed; then
            echo "[INFO] $app_name already installed, updating files."
        fi
        install_desktop
        echo "[INFO] Start Docker Desktop from the app launcher or run: systemctl --user start $service"
        ;;
    purge)
        echo "[INFO] Removing $app_name."
        purge_desktop
        ;;
    dry-run)
        if is_installed; then
            echo "[DRY-RUN] $app_name is already installed at $opt_dir."
        else
            echo "[DRY-RUN] Would install $app_name from RPM."
        fi
        echo "[DRY-RUN] Would download: $rpm_url"
        echo "[DRY-RUN] Would install to: $opt_dir"
        echo "[DRY-RUN] Would install user service: $service_file"
        echo "[DRY-RUN] Would install desktop entries under: $desktop_dir"
        ;;
    status)
        if is_installed; then
            echo "[OK] $app_name installed: $opt_dir/bin/docker-desktop"
        else
            echo "[MISSING] $app_name is not installed by this script"
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
        echo "Usage: $0 [apply|purge|dry-run|status]"
        exit 1
        ;;
esac
