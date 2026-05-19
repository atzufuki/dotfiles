#!/usr/bin/env bash

set -euo pipefail

script_command="${1:-apply}"
app_name="Docker Engine"
service="docker.service"
install_dir="/usr/local/bin"
service_file="/etc/systemd/system/$service"
daemon_config_dir="/etc/docker"
daemon_config_file="$daemon_config_dir/daemon.json"
state_dir="/var/lib/docker"
docker_bin="$install_dir/docker"
dockerd_bin="$install_dir/dockerd"
download_base="https://download.docker.com/linux/static/stable"
tmp_parent="${DOCKER_TMPDIR:-/var/tmp}"

ensure_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "[ERROR] $command_name is required to install $app_name."
        exit 1
    fi
}

docker_arch() {
    case "$(uname -m)" in
        x86_64)
            echo "x86_64"
            ;;
        aarch64|arm64)
            echo "aarch64"
            ;;
        *)
            echo "[ERROR] Unsupported architecture for Docker static binary: $(uname -m)" >&2
            exit 1
            ;;
    esac
}

latest_version() {
    local arch index version

    if [[ -n "${DOCKER_VERSION:-}" ]]; then
        echo "$DOCKER_VERSION"
        return 0
    fi

    arch="$(docker_arch)"
    index="$(curl -fsSL "$download_base/$arch/")"
    version="$(printf '%s\n' "$index" | sed -n 's/.*docker-\([0-9][0-9.]*\)\.tgz.*/\1/p' | sort -V | tail -n 1)"

    if [[ -z "$version" ]]; then
        echo "[ERROR] Could not resolve latest Docker static version." >&2
        echo "[ERROR] Set DOCKER_VERSION or DOCKER_ARCHIVE_URL and retry." >&2
        exit 1
    fi

    echo "$version"
}

archive_url() {
    local arch version

    if [[ -n "${DOCKER_ARCHIVE_URL:-}" ]]; then
        echo "$DOCKER_ARCHIVE_URL"
        return 0
    fi

    arch="$(docker_arch)"
    version="$(latest_version)"
    echo "$download_base/$arch/docker-${version}.tgz"
}

is_installed() {
    [[ -x "$docker_bin" && -x "$dockerd_bin" ]]
}

installed_by_this_script() {
    [[ -x "$docker_bin" && -x "$dockerd_bin" && -f "$service_file" ]] &&
        grep -Fq "$dockerd_bin" "$service_file"
}

write_service_file() {
    local target_file="$1"

    cat > "$target_file" <<EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service containerd.service
Wants=network-online.target

[Service]
Type=notify
EnvironmentFile=-/etc/default/docker
ExecStart=$dockerd_bin --host=unix:///var/run/docker.sock --group=docker \$DOCKERD_FLAGS
ExecReload=/bin/kill -s HUP \$MAINPID
TimeoutStartSec=0
Restart=on-failure
StartLimitBurst=3
StartLimitIntervalSec=60
Delegate=yes
KillMode=process
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target
EOF
}

install_service_file() {
    local tmp_service_file

    ensure_command sudo
    ensure_command systemctl
    mkdir -p "$tmp_parent"
    tmp_service_file="$(mktemp "$tmp_parent/docker-service.XXXXXX")"
    write_service_file "$tmp_service_file"
    echo "[INFO] Installing $service."
    sudo install -m 0644 "$tmp_service_file" "$service_file"
    rm -f "$tmp_service_file"
    sudo systemctl daemon-reload
}

install_docker() {
    local tmp archive extracted_dir url binary

    ensure_command curl
    ensure_command tar
    ensure_command sudo
    ensure_command systemctl

    url="$(archive_url)"
    mkdir -p "$tmp_parent"
    tmp="$(mktemp -d "$tmp_parent/docker.XXXXXX")"
    trap 'rm -rf "$tmp"' RETURN
    archive="$tmp/docker.tgz"

    echo "[INFO] Downloading Docker static archive: $url"
    curl -fL --output "$archive" "$url"

    echo "[INFO] Extracting Docker static archive."
    tar -xzf "$archive" -C "$tmp"
    extracted_dir="$tmp/docker"

    if [[ ! -x "$extracted_dir/docker" || ! -x "$extracted_dir/dockerd" ]]; then
        echo "[ERROR] Static archive did not contain docker and dockerd binaries."
        exit 1
    fi

    echo "[INFO] Installing Docker binaries to $install_dir."
    sudo systemctl stop "$service" >/dev/null 2>&1 || true
    sudo systemctl reset-failed "$service" >/dev/null 2>&1 || true
    sudo install -d -m 0755 "$install_dir"
    for binary in "$extracted_dir"/*; do
        [[ -f "$binary" && -x "$binary" ]] || continue
        sudo install -m 0755 "$binary" "$install_dir/$(basename "$binary")"
    done

    if command -v restorecon >/dev/null 2>&1; then
        sudo restorecon -F "$install_dir"/docker* "$install_dir"/containerd* "$install_dir"/ctr "$install_dir"/runc >/dev/null 2>&1 || true
    fi

    install_service_file

    if [[ ! -f "$daemon_config_file" ]]; then
        sudo install -d -m 0755 "$daemon_config_dir"
        printf '%s\n' '{"log-driver":"journald"}' | sudo tee "$daemon_config_file" >/dev/null
    fi
}

enable_service() {
    echo "[INFO] Enabling $service."
    sudo systemctl enable "$service"
    sudo systemctl restart "$service" || {
        echo "[ERROR] Failed to start $service. Recent logs:" >&2
        sudo journalctl -u "$service" -n 60 --no-pager >&2 || true
        exit 1
    }
}

configure_group() {
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
    local binary

    ensure_command sudo
    ensure_command systemctl

    if systemctl list-unit-files "$service" >/dev/null 2>&1; then
        echo "[INFO] Disabling $service."
        sudo systemctl disable --now "$service" || true
    fi

    if installed_by_this_script; then
        sudo rm -f "$service_file"
        for binary in docker dockerd containerd containerd-shim containerd-shim-runc-v2 ctr docker-init docker-proxy runc; do
            sudo rm -f "$install_dir/$binary"
        done
        sudo systemctl daemon-reload
        echo "[INFO] Kept Docker state under $state_dir."
        echo "[INFO] Kept Docker daemon config at $daemon_config_file."
    else
        echo "[INFO] Docker static installation was not found, skipping file removal."
    fi
}

case "$script_command" in
    apply)
        if is_installed; then
            echo "[INFO] Docker static binaries already installed, ensuring service. Run: $0 update"
            install_service_file
            configure_group
            enable_service
            exit 0
        fi

        install_docker
        configure_group
        enable_service
        ;;
    update)
        echo "[INFO] Updating Docker static binaries."
        install_docker
        configure_group
        enable_service
        ;;
    purge)
        purge_docker
        ;;
    dry-run)
        if is_installed; then
            echo "[DRY-RUN] Docker static binaries are already installed."
        else
            echo "[DRY-RUN] Would install Docker static binaries."
        fi
        echo "[DRY-RUN] Would download: $(archive_url)"
        echo "[DRY-RUN] Would install binaries to: $install_dir"
        echo "[DRY-RUN] Would install and enable: $service_file"
        echo "[DRY-RUN] Would create docker group and add user: $USER"
        ;;
    status)
        if is_installed; then
            echo "[OK] Docker installed: $docker_bin"
            "$docker_bin" --version || true
            "$dockerd_bin" --version || true
        else
            echo "[MISSING] Docker static binaries are not installed"
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

        if is_installed && "$docker_bin" info >/dev/null 2>&1; then
            echo "[OK] Docker daemon reachable"
        elif is_installed; then
            echo "[MISSING] Docker daemon is not reachable by current user"
        fi
        ;;
    *)
        echo "Usage: $0 [apply|update|purge|dry-run|status]"
        exit 1
        ;;
esac
