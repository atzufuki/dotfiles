#!/usr/bin/env bash

set -euo pipefail

script_command="${1:-apply}"
app_id="google-chrome"
app_name="Google Chrome"
rpm_url="${CHROME_RPM_URL:-https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm}"
bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
data_dir="${XDG_DATA_HOME:-$HOME/.local/share}"
app_dir="${XDG_OPT_HOME:-$HOME/.local/opt}/google-chrome"
desktop_dir="$data_dir/applications"
icon_base_dir="$data_dir/icons/hicolor"
desktop_file="$desktop_dir/google-chrome.desktop"
bin_file="$bin_dir/google-chrome"

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

    echo "[ERROR] bsdtar or rpm2cpio + cpio is required to extract the Chrome RPM."
    exit 1
}

is_installed() {
    [[ -x "$app_dir/google-chrome" && -x "$bin_file" ]]
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

install_icons() {
    local size

    for size in 16 24 32 48 64 128 256; do
        if [[ -f "$app_dir/product_logo_${size}.png" ]]; then
            mkdir -p "$icon_base_dir/${size}x${size}/apps"
            cp "$app_dir/product_logo_${size}.png" "$icon_base_dir/${size}x${size}/apps/google-chrome.png"
        fi
    done
}

install_launcher() {
    local tmp_file

    mkdir -p "$bin_dir"
    tmp_file="$(mktemp "$bin_dir/google-chrome.XXXXXX")"
    cat > "$tmp_file" <<EOF
#!/usr/bin/env bash
exec "$app_dir/google-chrome" "\$@"
EOF
    chmod +x "$tmp_file"
    mv -f "$tmp_file" "$bin_file"
}

install_desktop_entry() {
    mkdir -p "$desktop_dir"
    cat > "$desktop_file" <<EOF
[Desktop Entry]
Name=Google Chrome
Comment=Access the Internet
Exec=$bin_file %U
Terminal=false
Icon=google-chrome
Type=Application
Categories=Network;WebBrowser;
MimeType=application/pdf;application/rdf+xml;application/rss+xml;application/xhtml+xml;application/xhtml_xml;application/xml;image/gif;image/jpeg;image/png;image/webp;text/html;text/xml;x-scheme-handler/http;x-scheme-handler/https;
StartupNotify=true
StartupWMClass=Google-chrome
Actions=new-window;new-private-window;

[Desktop Action new-window]
Name=New Window
Exec=$bin_file

[Desktop Action new-private-window]
Name=New Incognito Window
Exec=$bin_file --incognito
EOF

    update-desktop-database "$desktop_dir" >/dev/null 2>&1 || true
}

install_chrome() {
    local tmp rpm_file extracted_app_dir

    ensure_command curl
    ensure_extractor

    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN
    rpm_file="$tmp/google-chrome.rpm"

    echo "[INFO] Downloading $app_name RPM: $rpm_url"
    curl -fL --output "$rpm_file" "$rpm_url"

    echo "[INFO] Extracting $app_name RPM."
    extract_rpm "$rpm_file" "$tmp/root"
    extracted_app_dir="$tmp/root/opt/google/chrome"

    if [[ ! -x "$extracted_app_dir/google-chrome" ]]; then
        echo "[ERROR] Downloaded RPM did not contain opt/google/chrome/google-chrome."
        exit 1
    fi

    rm -rf "$app_dir"
    mkdir -p "$(dirname "$app_dir")"
    cp -a "$extracted_app_dir" "$app_dir"
    install_launcher
    install_icons
    install_desktop_entry
}

purge_chrome() {
    if [[ -f "$bin_file" ]] && grep -Fq "$app_dir/google-chrome" "$bin_file"; then
        rm -f "$bin_file"
    fi

    rm -rf "$app_dir"
    rm -f "$desktop_file"
    rm -f "$icon_base_dir"/*/apps/google-chrome.png 2>/dev/null || true
    update-desktop-database "$desktop_dir" >/dev/null 2>&1 || true
}

case "$script_command" in
    apply)
        if is_installed; then
            echo "[INFO] $app_name already installed at $app_dir, updating launcher and desktop entry."
            install_launcher
            install_icons
            install_desktop_entry
            exit 0
        fi

        install_chrome
        ;;
    purge)
        echo "[INFO] Removing $app_name user installation."
        purge_chrome
        ;;
    dry-run)
        if is_installed; then
            echo "[DRY-RUN] $app_name is already installed at $app_dir."
        else
            echo "[DRY-RUN] Would download and extract RPM from: $rpm_url"
            echo "[DRY-RUN] Would install to: $app_dir"
        fi
        echo "[DRY-RUN] Would install launcher: $bin_file"
        echo "[DRY-RUN] Would install desktop entry: $desktop_file"
        ;;
    status)
        if is_installed; then
            echo "[OK] $app_name installed: $app_dir/google-chrome"
        else
            echo "[MISSING] $app_name is not installed by this script"
        fi
        ;;
    *)
        echo "Usage: $0 [apply|purge|dry-run|status]"
        exit 1
        ;;
esac
