#!/usr/bin/env bash

set -euo pipefail

script_command="${1:-apply}"
app_id="antigravity"
app_name="Antigravity 2"
tarball_url="${ANTIGRAVITY_URL:-https://storage.googleapis.com/antigravity-public/antigravity-hub/2.0.10-5119448496078848/linux-x64/Antigravity.tar.gz}"
bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
data_dir="${XDG_DATA_HOME:-$HOME/.local/share}"
app_dir="${XDG_OPT_HOME:-$HOME/.local/opt}/antigravity"
desktop_dir="$data_dir/applications"
desktop_file="$desktop_dir/antigravity.desktop"
bin_file="$bin_dir/antigravity"
tmp_parent="${ANTIGRAVITY_TMPDIR:-/var/tmp}"

ensure_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "[ERROR] $command_name is required to install $app_name."
        exit 1
    fi
}

is_installed() {
    [[ -x "$app_dir/antigravity" && -x "$bin_file" ]]
}

install_launcher() {
    local tmp_file

    mkdir -p "$bin_dir"
    tmp_file="$(mktemp "$bin_dir/antigravity.XXXXXX")"
    cat > "$tmp_file" <<EOF
#!/usr/bin/env bash
exec "$app_dir/antigravity" "\$@"
EOF
    chmod +x "$tmp_file"
    mv -f "$tmp_file" "$bin_file"
}

install_desktop_entry() {
    mkdir -p "$desktop_dir"
    cat > "$desktop_file" <<EOF
[Desktop Entry]
Name=Antigravity 2
Comment=Antigravity 2 Desktop Client
Exec=$bin_file %U
Terminal=false
Type=Application
Icon=antigravity
Categories=Development;
StartupNotify=true
StartupWMClass=antigravity
EOF

    update-desktop-database "$desktop_dir" >/dev/null 2>&1 || true
}

install_antigravity() {
    local tmp tar_file extracted_dir

    ensure_command curl
    ensure_command tar

    mkdir -p "$tmp_parent"
    tmp="$(mktemp -d "$tmp_parent/antigravity.XXXXXX")"
    trap 'rm -rf "$tmp"' RETURN
    tar_file="$tmp/antigravity.tar.gz"

    echo "[INFO] Downloading $app_name tarball: $tarball_url"
    curl -fL --output "$tar_file" "$tarball_url"

    echo "[INFO] Extracting $app_name tarball."
    mkdir -p "$tmp/root"
    tar -xzf "$tar_file" -C "$tmp/root"

    # Tarball contains "Antigravity-x64" directory
    extracted_dir="$tmp/root/Antigravity-x64"
    if [[ ! -x "$extracted_dir/antigravity" ]]; then
        echo "[ERROR] Extracted archive did not contain Antigravity-x64/antigravity executable."
        exit 1
    fi

    rm -rf "$app_dir"
    mkdir -p "$(dirname "$app_dir")"
    cp -a "$extracted_dir" "$app_dir"

    install_launcher
    install_desktop_entry
}

purge_antigravity() {
    if [[ -f "$bin_file" ]] && grep -Fq "$app_dir/antigravity" "$bin_file"; then
        rm -f "$bin_file"
    fi

    rm -rf "$app_dir"
    rm -f "$desktop_file"
    update-desktop-database "$desktop_dir" >/dev/null 2>&1 || true
}

case "$script_command" in
    apply)
        if is_installed; then
            echo "[INFO] $app_name already installed at $app_dir, refreshing launcher and desktop entry. Run: $0 update"
            install_launcher
            install_desktop_entry
            exit 0
        fi

        install_antigravity
        ;;
    update)
        echo "[INFO] Updating $app_name."
        install_antigravity
        ;;
    purge)
        echo "[INFO] Removing $app_name user installation."
        purge_antigravity
        ;;
    dry-run)
        if is_installed; then
            echo "[DRY-RUN] $app_name is already installed at $app_dir."
        else
            echo "[DRY-RUN] Would download and extract tarball from: $tarball_url"
            echo "[DRY-RUN] Would install to: $app_dir"
        fi
        echo "[DRY-RUN] Would install launcher: $bin_file"
        echo "[DRY-RUN] Would install desktop entry: $desktop_file"
        ;;
    status)
        if is_installed; then
            echo "[OK] $app_name installed: $app_dir/antigravity"
        else
            echo "[MISSING] $app_name is not installed by this script"
        fi
        ;;
    *)
        echo "Usage: $0 [apply|update|purge|dry-run|status]"
        exit 1
        ;;
esac
