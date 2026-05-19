#!/usr/bin/env bash

set -euo pipefail

script_command="${1:-apply}"
app_name="Podman Docker compatibility"
bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
docker_bin="$bin_dir/docker"
socket="podman.socket"
docker_host="unix:///run/user/$(id -u)/podman/podman.sock"

is_installed() {
    command -v podman >/dev/null 2>&1
}

wrapper_managed() {
    [[ -f "$docker_bin" ]] && grep -Fq 'Managed by dotfiles docker-podman.sh' "$docker_bin"
}

install_wrapper() {
    mkdir -p "$bin_dir"
    cat > "$docker_bin" <<'EOF'
#!/usr/bin/env bash
# Managed by dotfiles docker-podman.sh
exec podman "$@"
EOF
    chmod +x "$docker_bin"
}

enable_socket() {
    echo "[INFO] Enabling user $socket."
    systemctl --user enable --now "$socket"
}

purge_wrapper() {
    if wrapper_managed; then
        rm -f "$docker_bin"
    fi

    systemctl --user disable --now "$socket" >/dev/null 2>&1 || true
}

case "$script_command" in
    apply)
        if ! is_installed; then
            echo "[ERROR] podman is required for $app_name."
            exit 1
        fi

        if [[ -e "$docker_bin" && ! -L "$docker_bin" ]] && ! wrapper_managed; then
            echo "[ERROR] Refusing to replace unmanaged docker command: $docker_bin"
            exit 1
        fi

        install_wrapper
        enable_socket
        echo "[INFO] Docker-compatible Podman socket: $docker_host"
        echo "[INFO] Set DOCKER_HOST=$docker_host for tools that need the Docker API socket."
        ;;
    purge)
        echo "[INFO] Removing $app_name."
        purge_wrapper
        ;;
    dry-run)
        if is_installed; then
            echo "[DRY-RUN] Podman is installed: $(command -v podman)"
        else
            echo "[DRY-RUN] Podman is missing."
        fi
        echo "[DRY-RUN] Would install docker wrapper: $docker_bin"
        echo "[DRY-RUN] Would enable user socket: $socket"
        echo "[DRY-RUN] Docker API socket would be: $docker_host"
        ;;
    status)
        if is_installed; then
            echo "[OK] Podman installed: $(command -v podman)"
        else
            echo "[MISSING] Podman is not installed"
        fi

        if wrapper_managed; then
            echo "[OK] Docker wrapper installed: $docker_bin"
        elif [[ -e "$docker_bin" ]]; then
            echo "[CONFLICT] Docker command exists and is not managed by this script: $docker_bin"
        else
            echo "[MISSING] Docker wrapper is not installed"
        fi

        if systemctl --user is-active "$socket" >/dev/null 2>&1; then
            echo "[OK] User $socket active"
        else
            echo "[MISSING] User $socket is not active"
        fi
        ;;
    *)
        echo "Usage: $0 [apply|purge|dry-run|status]"
        exit 1
        ;;
esac
