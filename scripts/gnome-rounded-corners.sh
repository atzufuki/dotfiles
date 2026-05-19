#!/usr/bin/env bash

set -euo pipefail

command="${1:-apply}"
extension_uuid="rounded-window-corners@fxgn"
extension_name="Rounded Window Corners Reborn"
extension_schema_path="/org/gnome/shell/extensions/rounded-window-corners-reborn/"
extension_dir="${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions/$extension_uuid"
extensions_api="https://extensions.gnome.org/extension-info/?uuid=rounded-window-corners%40fxgn"
extension_base_url="https://extensions.gnome.org"
radius="${GNOME_ROUNDED_CORNERS_RADIUS:-12}"
padding="${GNOME_ROUNDED_CORNERS_PADDING:-1}"
smoothing="${GNOME_ROUNDED_CORNERS_SMOOTHING:-0}"
border_width="${GNOME_ROUNDED_CORNERS_BORDER_WIDTH:-0}"

ensure_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "[ERROR] $command_name is required for $extension_name."
        exit 1
    fi
}

gnome_shell_major_version() {
    local version

    version="$(gnome-shell --version 2>/dev/null || true)"
    if [[ "$version" =~ ([0-9]+)\.[0-9]+ ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi

    return 1
}

extension_download_url() {
    local shell_major api_json download_path regex

    shell_major="$(gnome_shell_major_version)" || {
        echo "[ERROR] Could not resolve GNOME Shell version." >&2
        exit 1
    }

    api_json="$(curl -fsSL "${extensions_api}&shell_version=${shell_major}")"
    regex='"download_url"[[:space:]]*:[[:space:]]*"([^"]+)"'

    if [[ "$api_json" =~ $regex ]]; then
        download_path="${BASH_REMATCH[1]}"
        echo "${extension_base_url}${download_path//\\u0026/&}"
        return 0
    fi

    echo "[ERROR] Could not resolve $extension_name download URL for GNOME Shell $shell_major." >&2
    exit 1
}

is_installed() {
    gnome-extensions info "$extension_uuid" >/dev/null 2>&1 || [[ -f "$extension_dir/metadata.json" ]]
}

is_enabled() {
    gnome-extensions list --enabled 2>/dev/null | grep -Fxq "$extension_uuid" && return 0

    if command -v gsettings >/dev/null 2>&1; then
        gsettings get org.gnome.shell enabled-extensions 2>/dev/null | grep -Fq "'$extension_uuid'"
    fi
}

enable_extension() {
    if gnome-extensions enable "$extension_uuid" 2>/dev/null; then
        return 0
    fi

    if ! command -v gsettings >/dev/null 2>&1; then
        echo "[WARN] Install completed, but current GNOME Shell session does not see $extension_name yet."
        echo "[WARN] Log out and back in, then enable $extension_uuid manually."
        return 0
    fi

    if ! is_enabled; then
        local current next

        current="$(gsettings get org.gnome.shell enabled-extensions)"
        if [[ "$current" == "@as []" || "$current" == "[]" ]]; then
            next="['$extension_uuid']"
        else
            next="${current%]} , '$extension_uuid']"
            next="${next/, ]/]}"
        fi
        gsettings set org.gnome.shell enabled-extensions "$next"
    fi

    echo "[INFO] $extension_name will become active after GNOME Shell reload or next login."
}

configure_extension() {
    if ! command -v dconf >/dev/null 2>&1; then
        echo "[WARN] dconf is not installed; leaving $extension_name preferences at defaults."
        return 0
    fi

    dconf write "${extension_schema_path}skip-libadwaita-app" true
    dconf write "${extension_schema_path}skip-libhandy-app" false
    dconf write "${extension_schema_path}border-width" "$border_width"
    dconf write "${extension_schema_path}global-rounded-corner-settings" "{'padding': <{'left': <uint32 ${padding}>, 'right': <uint32 ${padding}>, 'top': <uint32 ${padding}>, 'bottom': <uint32 ${padding}>}>, 'keepRoundedCorners': <{'maximized': <false>, 'fullscreen': <false>}>, 'borderRadius': <uint32 ${radius}>, 'smoothing': <${smoothing}>, 'borderColor': <[0.5, 0.5, 0.5, 1.0]>, 'enabled': <true>}"
}

install_extension() {
    local url tmp_file

    ensure_command curl
    ensure_command gnome-shell
    ensure_command gnome-extensions

    url="$(extension_download_url)"
    tmp_file="$(mktemp --suffix=.zip)"
    trap 'rm -f "$tmp_file"' RETURN

    echo "[INFO] Downloading $extension_name: $url"
    curl -fL --output "$tmp_file" "$url"

    echo "[INFO] Installing $extension_name."
    gnome-extensions install --force "$tmp_file"
    configure_extension
    enable_extension

    rm -f "$tmp_file"
    trap - RETURN
}

purge_extension() {
    ensure_command gnome-extensions

    if is_enabled; then
        gnome-extensions disable "$extension_uuid" || true
    fi

    if is_installed; then
        gnome-extensions uninstall "$extension_uuid" || true
    fi

    if command -v dconf >/dev/null 2>&1; then
        dconf reset -f "$extension_schema_path" || true
    fi
}

case "$command" in
    apply)
        if is_installed; then
            echo "[INFO] $extension_name already installed."
            configure_extension
            if ! is_enabled; then
                enable_extension
            fi
        else
            install_extension
        fi
        ;;
    purge)
        echo "[INFO] Removing $extension_name."
        purge_extension
        ;;
    dry-run)
        ensure_command gnome-shell
        ensure_command gnome-extensions
        echo "[DRY-RUN] Would install and enable: $extension_uuid"
        echo "[DRY-RUN] Would download from: $(extension_download_url)"
        echo "[DRY-RUN] Would set radius=$radius padding=$padding"
        ;;
    status)
        ensure_command gnome-extensions
        if is_installed; then
            echo "[OK] $extension_name installed."
        else
            echo "[MISSING] $extension_name is not installed."
        fi

        if is_enabled; then
            echo "[OK] $extension_name enabled."
        else
            echo "[MISSING] $extension_name is not enabled."
        fi
        ;;
    *)
        echo "Usage: $0 [apply|purge|dry-run|status]"
        exit 1
        ;;
esac
