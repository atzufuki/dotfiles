#!/usr/bin/env bash

set -euo pipefail

command="${1:-apply}"
app_id="2129370"
runtime_version="10.0.7"
runtime_file="windowsdesktop-runtime-${runtime_version}-win-x64.exe"
runtime_url="https://builds.dotnet.microsoft.com/dotnet/WindowsDesktop/${runtime_version}/${runtime_file}"
download_dir="$HOME/Downloads"
runtime_path="$download_dir/$runtime_file"
wineprefix=""
proton_wine=""

usage() {
    echo "Usage: $0 [apply|purge|dry-run|status]"
}

add_unique_path() {
    local path="$1"
    local existing

    [[ -n "$path" ]] || return 0
    for existing in "${steam_libraries[@]}"; do
        [[ "$existing" == "$path" ]] && return 0
    done

    steam_libraries+=("$path")
}

load_steam_libraries() {
    local libraryfolders_file
    local line
    local path

    declare -g -a steam_libraries=()

    add_unique_path "$HOME/.local/share/Steam"
    add_unique_path "$HOME/.steam/steam"

    for libraryfolders_file in \
        "$HOME/.local/share/Steam/steamapps/libraryfolders.vdf" \
        "$HOME/.steam/steam/steamapps/libraryfolders.vdf"; do
        [[ -f "$libraryfolders_file" ]] || continue

        while IFS= read -r line; do
            if [[ "$line" =~ \"path\"[[:space:]]+\"([^\"]+)\" ]]; then
                path="${BASH_REMATCH[1]}"
                add_unique_path "$path"
            fi
        done < "$libraryfolders_file"
    done
}

resolve_paths() {
    local library
    local candidate
    local proton_candidate

    load_steam_libraries

    for library in "${steam_libraries[@]}"; do
        candidate="$library/steamapps/compatdata/$app_id/pfx"
        if [[ -d "$candidate" ]]; then
            wineprefix="$candidate"
            break
        fi
    done

    for library in "${steam_libraries[@]}"; do
        shopt -s nullglob
        for proton_candidate in "$library"/steamapps/common/Proton\ 10.0*/files/bin/wine; do
            if [[ -x "$proton_candidate" ]]; then
                proton_wine="$proton_candidate"
                shopt -u nullglob
                return 0
            fi
        done
        shopt -u nullglob
    done
}

ensure_proton_prefix() {
    if [[ ! -d "$wineprefix" ]]; then
        echo "[ERROR] Proton prefix not found for app $app_id."
        echo "[ERROR] Set s&box Editor compatibility to Proton 10.x and launch it once from Steam."
        exit 1
    fi
}

ensure_proton_wine() {
    if [[ ! -x "$proton_wine" ]]; then
        echo "[ERROR] Proton 10.x Wine not found in Steam libraries."
        echo "[ERROR] Install Proton 10.x in Steam."
        exit 1
    fi
}

runtime_install_dir() {
    echo "$wineprefix/drive_c/Program Files/dotnet/shared/Microsoft.WindowsDesktop.App/$runtime_version"
}

is_runtime_installed() {
    [[ -d "$(runtime_install_dir)" ]]
}

download_runtime() {
    mkdir -p "$download_dir"

    if [[ -f "$runtime_path" ]]; then
        echo "[INFO] .NET Desktop Runtime installer already downloaded: $runtime_path"
        return 0
    fi

    echo "[INFO] Downloading .NET Desktop Runtime $runtime_version."
    curl -fL "$runtime_url" -o "$runtime_path"
}

case "$command" in
    apply)
        resolve_paths
        ensure_proton_prefix
        ensure_proton_wine

        if is_runtime_installed; then
            echo "[INFO] .NET Desktop Runtime $runtime_version already installed in s&box Editor Proton prefix, skipping."
            exit 0
        fi

        download_runtime

        echo "[INFO] Installing .NET Desktop Runtime $runtime_version into s&box Editor Proton prefix."
        WINEPREFIX="$wineprefix" "$proton_wine" "$runtime_path"
        ;;
    purge)
        echo "[INFO] Nothing to purge for s&box Editor .NET Runtime. Remove it from the Proton prefix manually if needed."
        ;;
    dry-run)
        resolve_paths
        echo "[DRY-RUN] Would use Proton Wine: $proton_wine"
        echo "[DRY-RUN] Would use WINEPREFIX: $wineprefix"
        if is_runtime_installed; then
            echo "[DRY-RUN] .NET Desktop Runtime $runtime_version is already installed: $(runtime_install_dir)"
        else
            echo "[DRY-RUN] Would download installer: $runtime_url"
            echo "[DRY-RUN] Would run installer: $runtime_path"
        fi
        ;;
    status)
        resolve_paths
        if [[ -d "$wineprefix" ]]; then
            echo "[OK] s&box Editor Proton prefix exists: $wineprefix"
        else
            echo "[MISSING] s&box Editor Proton prefix missing for app $app_id"
        fi

        if [[ -x "$proton_wine" ]]; then
            echo "[OK] Proton Wine exists: $proton_wine"
        else
            echo "[MISSING] Proton Wine missing: $proton_wine"
        fi

        if [[ -f "$runtime_path" ]]; then
            echo "[OK] .NET Desktop Runtime installer downloaded: $runtime_path"
        else
            echo "[MISSING] .NET Desktop Runtime installer not downloaded: $runtime_path"
        fi

        if is_runtime_installed; then
            echo "[OK] .NET Desktop Runtime installed: $(runtime_install_dir)"
        else
            echo "[MISSING] .NET Desktop Runtime not installed: $(runtime_install_dir)"
        fi
        ;;
    *)
        usage
        exit 1
        ;;
esac
