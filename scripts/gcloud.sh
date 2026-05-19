#!/usr/bin/env bash

set -euo pipefail

script_command="${1:-apply}"
app_name="Google Cloud CLI"
bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
app_dir="${XDG_OPT_HOME:-$HOME/.local/opt}/google-cloud-cli"
sdk_dir="$app_dir/google-cloud-sdk"

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
            echo "x86_64"
            ;;
        aarch64|arm64)
            echo "arm"
            ;;
        *)
            echo "[ERROR] Unsupported architecture for $app_name: $(uname -m)" >&2
            exit 1
            ;;
    esac
}

archive_url() {
    local arch

    if [[ -n "${GCLOUD_ARCHIVE_URL:-}" ]]; then
        echo "$GCLOUD_ARCHIVE_URL"
        return 0
    fi

    arch="$(archive_arch)"
    echo "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-${arch}.tar.gz"
}

is_installed() {
    [[ -x "$sdk_dir/bin/gcloud" && -x "$bin_dir/gcloud" ]]
}

install_launchers() {
    local command_name

    mkdir -p "$bin_dir"
    for command_name in gcloud gsutil bq; do
        if [[ -x "$sdk_dir/bin/$command_name" ]]; then
            ln -sfn "$sdk_dir/bin/$command_name" "$bin_dir/$command_name"
        fi
    done
}

install_gcloud() {
    local tmp archive url extracted_dir

    ensure_command curl
    ensure_command tar

    url="$(archive_url)"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN
    archive="$tmp/google-cloud-cli.tar.gz"

    echo "[INFO] Downloading $app_name archive: $url"
    curl -fL --output "$archive" "$url"

    echo "[INFO] Extracting $app_name archive."
    tar -xzf "$archive" -C "$tmp"
    extracted_dir="$tmp/google-cloud-sdk"

    if [[ ! -x "$extracted_dir/bin/gcloud" ]]; then
        echo "[ERROR] Archive did not contain google-cloud-sdk/bin/gcloud."
        exit 1
    fi

    rm -rf "$app_dir"
    mkdir -p "$app_dir"
    cp -a "$extracted_dir" "$sdk_dir"

    echo "[INFO] Running non-interactive $app_name install."
    "$sdk_dir/install.sh" --quiet --usage-reporting=false --path-update=false --command-completion=false >/dev/null
    install_launchers
}

purge_gcloud() {
    local command_name

    for command_name in gcloud gsutil bq; do
        if [[ -L "$bin_dir/$command_name" && "$(readlink "$bin_dir/$command_name")" == "$sdk_dir/bin/$command_name" ]]; then
            rm -f "$bin_dir/$command_name"
        fi
    done

    rm -rf "$app_dir"
    echo "[INFO] Kept gcloud config under ${CLOUDSDK_CONFIG:-$HOME/.config/gcloud}."
}

case "$script_command" in
    apply)
        if is_installed; then
            echo "[INFO] $app_name already installed at $sdk_dir, updating launchers."
            install_launchers
            exit 0
        fi

        install_gcloud
        ;;
    purge)
        echo "[INFO] Removing $app_name user installation."
        purge_gcloud
        ;;
    dry-run)
        if is_installed; then
            echo "[DRY-RUN] $app_name is already installed at $sdk_dir."
        else
            echo "[DRY-RUN] Would download and extract archive from: $(archive_url)"
            echo "[DRY-RUN] Would install to: $sdk_dir"
        fi
        echo "[DRY-RUN] Would install launchers: $bin_dir/gcloud, $bin_dir/gsutil, $bin_dir/bq"
        ;;
    status)
        if is_installed; then
            echo "[OK] $app_name installed: $sdk_dir/bin/gcloud"
            "$sdk_dir/bin/gcloud" version --format='value(Google Cloud SDK)' 2>/dev/null || "$sdk_dir/bin/gcloud" version || true
        else
            echo "[MISSING] $app_name is not installed by this script"
        fi
        ;;
    *)
        echo "Usage: $0 [apply|purge|dry-run|status]"
        exit 1
        ;;
esac
