#!/usr/bin/env bash

set -euo pipefail

script_command="${1:-apply}"
service="tailscaled.service"
install_dir="/usr/local/bin"
tailscale_bin="$install_dir/tailscale"
tailscaled_bin="$install_dir/tailscaled"
service_file="/etc/systemd/system/$service"
state_dir="/var/lib/tailscale"

ensure_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "[ERROR] $command_name is required to install Tailscale."
        exit 1
    fi
}

tailscale_arch() {
    case "$(uname -m)" in
        x86_64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7l|armv6l)
            echo "arm"
            ;;
        i386|i686)
            echo "386"
            ;;
        *)
            echo "[ERROR] Unsupported architecture for Tailscale static binary: $(uname -m)" >&2
            exit 1
            ;;
    esac
}

archive_url() {
    local arch

    if [[ -n "${TAILSCALE_ARCHIVE_URL:-}" ]]; then
        echo "$TAILSCALE_ARCHIVE_URL"
        return 0
    fi

    arch="$(tailscale_arch)"
    echo "https://pkgs.tailscale.com/stable/tailscale_latest_${arch}.tgz"
}

is_installed() {
    [[ -x "$tailscale_bin" && -x "$tailscaled_bin" ]]
}

installed_by_this_script() {
    [[ -x "$tailscale_bin" && -x "$tailscaled_bin" && -f "$service_file" ]] &&
        grep -Fq "$tailscaled_bin" "$service_file"
}

write_service_file() {
    local target_file="$1"

    cat > "$target_file" <<EOF
[Unit]
Description=Tailscale node agent
Documentation=https://tailscale.com/kb/
Wants=network-pre.target
After=network-pre.target NetworkManager.service systemd-resolved.service

[Service]
EnvironmentFile=-/etc/default/tailscaled
ExecStart=$tailscaled_bin --state=$state_dir/tailscaled.state --socket=/run/tailscale/tailscaled.sock --port=41641 \$FLAGS
ExecStopPost=$tailscaled_bin --cleanup
Restart=on-failure
RuntimeDirectory=tailscale
RuntimeDirectoryMode=0755
StateDirectory=tailscale
StateDirectoryMode=0700

[Install]
WantedBy=multi-user.target
EOF
}

install_tailscale() {
    local tmp archive extracted_dir url

    ensure_command curl
    ensure_command tar
    ensure_command sudo
    ensure_command systemctl

    url="$(archive_url)"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN
    archive="$tmp/tailscale.tgz"

    echo "[INFO] Downloading Tailscale static archive: $url"
    curl -fL --output "$archive" "$url"

    echo "[INFO] Extracting Tailscale static archive."
    tar -xzf "$archive" -C "$tmp"
    extracted_dir="$(find "$tmp" -maxdepth 1 -type d -name 'tailscale_*' | head -n 1)"

    if [[ -z "$extracted_dir" || ! -x "$extracted_dir/tailscale" || ! -x "$extracted_dir/tailscaled" ]]; then
        echo "[ERROR] Static archive did not contain tailscale and tailscaled binaries."
        exit 1
    fi

    echo "[INFO] Installing Tailscale binaries to $install_dir."
    sudo systemctl stop "$service" >/dev/null 2>&1 || true
    sudo systemctl reset-failed "$service" >/dev/null 2>&1 || true
    sudo install -d -m 0755 "$install_dir"
    sudo install -m 0755 "$extracted_dir/tailscale" "$tailscale_bin"
    sudo install -m 0755 "$extracted_dir/tailscaled" "$tailscaled_bin"

    if command -v restorecon >/dev/null 2>&1; then
        sudo restorecon -F "$tailscale_bin" "$tailscaled_bin" >/dev/null 2>&1 || true
    fi

    write_service_file "$tmp/tailscaled.service"
    echo "[INFO] Installing $service."
    sudo install -m 0644 "$tmp/tailscaled.service" "$service_file"
    sudo systemctl daemon-reload
}

enable_service() {
    echo "[INFO] Enabling $service."
    sudo systemctl enable "$service"
    sudo systemctl restart "$service" || {
        echo "[ERROR] Failed to start $service. Recent logs:" >&2
        sudo journalctl -u "$service" -n 40 --no-pager >&2 || true
        exit 1
    }
}

print_connection_hint() {
    if "$tailscale_bin" status >/dev/null 2>&1; then
        echo "[OK] Tailscale is connected."
    else
        echo "[INFO] Tailscale is installed. Run: sudo $tailscale_bin up"
    fi
}

purge_tailscale() {
    ensure_command sudo
    ensure_command systemctl

    if systemctl list-unit-files "$service" >/dev/null 2>&1; then
        echo "[INFO] Disabling $service."
        sudo systemctl disable --now "$service" || true
    fi

    if installed_by_this_script; then
        sudo rm -f "$service_file" "$tailscale_bin" "$tailscaled_bin"
        sudo systemctl daemon-reload
        echo "[INFO] Kept Tailscale state under $state_dir."
    else
        echo "[INFO] Tailscale static installation was not found, skipping file removal."
    fi
}

case "$script_command" in
    apply)
        if is_installed; then
            echo "[INFO] Tailscale static binaries already installed, updating service."
        fi
        install_tailscale
        enable_service
        print_connection_hint
        ;;
    purge)
        purge_tailscale
        ;;
    dry-run)
        if is_installed; then
            echo "[DRY-RUN] Tailscale static binaries are already installed."
        else
            echo "[DRY-RUN] Would install Tailscale static binaries."
        fi
        echo "[DRY-RUN] Would download: $(archive_url)"
        echo "[DRY-RUN] Would install binaries: $tailscale_bin and $tailscaled_bin"
        echo "[DRY-RUN] Would install and enable: $service_file"
        echo "[DRY-RUN] Would not run tailscale up automatically."
        ;;
    status)
        if is_installed; then
            echo "[OK] Tailscale installed: $tailscale_bin"
            "$tailscale_bin" version | head -n 1 || true
        else
            echo "[MISSING] Tailscale static binaries are not installed"
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

        if is_installed && "$tailscale_bin" status >/dev/null 2>&1; then
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
