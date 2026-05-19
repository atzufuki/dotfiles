#!/usr/bin/env bash

set -euo pipefail

script_command="${1:-apply}"
app_id="slack"
app_name="Slack"
download_page="https://slack.com/downloads/linux"
bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
data_dir="${XDG_DATA_HOME:-$HOME/.local/share}"
app_dir="${XDG_OPT_HOME:-$HOME/.local/opt}/slack"
desktop_dir="$data_dir/applications"
icon_dir="$data_dir/icons/hicolor/512x512/apps"
desktop_file="$desktop_dir/slack.desktop"
icon_file="$icon_dir/slack.png"
bin_file="$bin_dir/slack"
theme_name="SlackTitlebar"
theme_dir="$data_dir/themes/$theme_name/gtk-3.0"
tmp_parent="${SLACK_TMPDIR:-/var/tmp}"

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

    echo "[ERROR] bsdtar or rpm2cpio + cpio is required to extract the Slack RPM."
    exit 1
}

is_installed() {
    [[ -x "$app_dir/slack" && -x "$bin_file" ]]
}

latest_version() {
    local page

    page="$(curl -fsSL "$download_page")"
    if [[ "$page" =~ Version[[:space:]]+([0-9]+\.[0-9]+\.[0-9]+) ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
        return 0
    fi

    echo "[ERROR] Could not resolve latest $app_name version from $download_page." >&2
    echo "[ERROR] Set SLACK_VERSION or SLACK_RPM_URL and retry." >&2
    exit 1
}

rpm_url() {
    local version

    if [[ -n "${SLACK_RPM_URL:-}" ]]; then
        printf '%s\n' "$SLACK_RPM_URL"
        return 0
    fi

    version="${SLACK_VERSION:-$(latest_version)}"
    printf 'https://downloads.slack-edge.com/desktop-releases/linux/x64/%s/slack-%s-0.1.el8.x86_64.rpm\n' "$version" "$version"
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

install_desktop_entry() {
    mkdir -p "$desktop_dir" "$icon_dir"

    if [[ -f "$app_dir/usr/share/pixmaps/slack.png" ]]; then
        cp "$app_dir/usr/share/pixmaps/slack.png" "$icon_file"
    elif [[ -f "$app_dir/resources/app.asar.unpacked/src/static/slack.png" ]]; then
        cp "$app_dir/resources/app.asar.unpacked/src/static/slack.png" "$icon_file"
    fi

    cat > "$desktop_file" <<EOF
[Desktop Entry]
Name=Slack
Comment=Slack Desktop
Exec=$bin_file %U
Icon=slack
Terminal=false
Type=Application
Categories=Network;InstantMessaging;
StartupNotify=true
MimeType=x-scheme-handler/slack;
EOF

    update-desktop-database "$desktop_dir" >/dev/null 2>&1 || true
}

install_slack_theme() {
    mkdir -p "$theme_dir"

    cat > "$theme_dir/gtk.css" <<'EOF'
/* Slack-only GTK3 theme for the native Electron titlebar and menubar. */
decoration,
decoration:backdrop,
.titlebar,
.titlebar:backdrop,
.titlebar:not(headerbar),
.titlebar:not(headerbar):backdrop,
headerbar,
headerbar:backdrop,
menubar,
menubar:backdrop {
    background: #1a1a1a;
    background-color: #1a1a1a;
    color: #eeeeee;
}

decoration {
    border-radius: 12px;
}

window,
window.background {
    border-radius: 12px;
}
EOF
}

install_launcher() {
    local tmp_file

    mkdir -p "$bin_dir"
    tmp_file="$(mktemp "$bin_dir/slack.XXXXXX")"

    cat > "$tmp_file" <<EOF
#!/usr/bin/env bash
export GTK_THEME=$theme_name
exec "$app_dir/slack" "\$@"
EOF
    chmod +x "$tmp_file"
    mv -f "$tmp_file" "$bin_file"
}

install_slack() {
    local url tmp rpm_file extracted_app_dir

    ensure_command curl
    ensure_extractor

    url="$(rpm_url)"
    mkdir -p "$tmp_parent"
    tmp="$(mktemp -d "$tmp_parent/slack.XXXXXX")"
    trap 'rm -rf "$tmp"' RETURN
    rpm_file="$tmp/slack.rpm"

    echo "[INFO] Downloading $app_name RPM: $url"
    curl -fL --output "$rpm_file" "$url"

    echo "[INFO] Extracting $app_name RPM."
    extract_rpm "$rpm_file" "$tmp/root"
    extracted_app_dir="$tmp/root/usr/lib/slack"

    if [[ ! -x "$extracted_app_dir/slack" ]]; then
        echo "[ERROR] Downloaded RPM did not contain usr/lib/slack/slack."
        exit 1
    fi

    rm -rf "$app_dir"
    mkdir -p "$(dirname "$app_dir")" "$bin_dir"
    cp -a "$extracted_app_dir" "$app_dir"
    install_slack_theme
    install_launcher
    install_desktop_entry
}

purge_slack() {
    if [[ -L "$bin_file" && "$(readlink "$bin_file")" == "$app_dir/slack" ]]; then
        rm -f "$bin_file"
    elif [[ -f "$bin_file" ]] && grep -Fq "GTK_THEME=$theme_name" "$bin_file"; then
        rm -f "$bin_file"
    fi

    rm -rf "$app_dir"
    rm -rf "$data_dir/themes/$theme_name"
    rm -f "$desktop_file" "$icon_file"
    update-desktop-database "$desktop_dir" >/dev/null 2>&1 || true
}

case "$script_command" in
    apply)
        if is_installed; then
            echo "[INFO] $app_name already installed at $app_dir, refreshing launcher and theme. Run: $0 update"
            install_slack_theme
            install_launcher
            install_desktop_entry
            exit 0
        fi

        install_slack
        ;;
    update)
        echo "[INFO] Updating $app_name."
        install_slack
        ;;
    purge)
        echo "[INFO] Removing $app_name user installation."
        purge_slack
        ;;
    dry-run)
        if is_installed; then
            echo "[DRY-RUN] $app_name is already installed at $app_dir."
        else
            echo "[DRY-RUN] Would download and extract RPM from: $(rpm_url)"
            echo "[DRY-RUN] Would install to: $app_dir"
        fi
        echo "[DRY-RUN] Would install Slack-only GTK theme: $theme_dir/gtk.css"
        echo "[DRY-RUN] Would launch Slack with: GTK_THEME=$theme_name"
        ;;
    status)
        if is_installed; then
            echo "[OK] $app_name installed: $app_dir/slack"
        else
            echo "[MISSING] $app_name is not installed by this script"
        fi
        ;;
    *)
        echo "Usage: $0 [apply|update|purge|dry-run|status]"
        exit 1
        ;;
esac
