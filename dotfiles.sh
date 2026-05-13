#!/usr/bin/env bash

# Dotfiles command script.
# This script manages scripts and dotfile symlinks.

usage() {
    cat <<'EOF'
Usage: dotfiles <command>

Commands:
  install    Run install scripts and symlink dotfiles
  uninstall  Remove dotfiles symlinks and run uninstall scripts
  dry-run    Preview install actions without changing files
  status     Check symlinks, package state, and managed services
  help       Show this help

Short command:
  dot        Same as dotfiles when installed through setup.sh
EOF
}

if [[ $# -gt 1 ]]; then
    usage
    exit 1
fi

command="${1:-help}"
source_path="${BASH_SOURCE[0]}"
while [[ -L "$source_path" ]]; do
    source_dir="$(cd "$(dirname "$source_path")" && pwd)"
    source_path="$(readlink "$source_path")"
    [[ "$source_path" == /* ]] || source_path="$source_dir/$source_path"
done
script_dir="$(cd "$(dirname "$source_path")" && pwd)"
repo_dir="$script_dir"
ignore_file="$repo_dir/.dotfilesignore"
scripts_dir="$repo_dir/scripts"

case "$command" in
    install)
        echo "[INFO] Installing dotfiles."
        ;;
    uninstall)
        echo "[INFO] Uninstalling dotfiles."
        ;;
    dry-run)
        echo "[INFO] Previewing dotfiles install."
        ;;
    status)
        echo "[INFO] Checking dotfiles status."
        ;;
    help|--help|-h)
        usage
        exit 0
        ;;
    *)
        usage
        exit 1
        ;;
esac

if [[ ! -d "$repo_dir" ]]; then
    echo "[ERROR] Dotfiles repo not found: $repo_dir"
    exit 1
fi

if [[ ! -f "$ignore_file" ]]; then
    echo "[ERROR] Ignore file not found: $ignore_file"
    exit 1
fi

echo "[INFO] Found .dotfilesignore, processing files..."
cd "$repo_dir" || exit 1

managed_files() {
    local item

    while IFS= read -r item; do
        [[ "$item" == ".dotfilesignore" ]] && continue
        is_ignored_file "$item" && continue
        echo "$item"
    done < <(find . -type f | sed 's|^./||')
}

is_ignored_file() {
    local item="$1"
    local pattern

    while IFS= read -r pattern; do
        [[ -z "$pattern" || "$pattern" == \#* ]] && continue
        if [[ "$pattern" == *"*"* || "$pattern" == *"?"* || "$pattern" == *"["* ]]; then
            [[ "$item" == $pattern ]] && return 0
        elif [[ "$pattern" == */ ]]; then
            [[ "$item" == "$pattern"* ]] && return 0
        elif [[ "$item" == "$pattern" ]]; then
            return 0
        fi
    done < "$ignore_file"

    return 1
}

target_for() {
    echo "/$1"
}

skel_name_for() {
    case "$1" in
        home/atzufuki/.bashrc)
            echo ".bashrc"
            ;;
        home/atzufuki/.bash_profile)
            echo ".bash_profile"
            ;;
        *)
            return 1
            ;;
    esac
}

skel_source_for() {
    local skel_name="$1"

    if [[ -f "/usr/etc/skel/$skel_name" ]]; then
        echo "/usr/etc/skel/$skel_name"
    elif [[ -f "/etc/skel/$skel_name" ]]; then
        echo "/etc/skel/$skel_name"
    else
        return 1
    fi
}

is_repo_symlink() {
    local item="$1"
    local target="$2"
    local expected

    [[ -L "$target" ]] || return 1
    expected="$(readlink -f "$repo_dir/$item")"
    [[ "$(readlink -f "$target")" == "$expected" ]]
}

restore_skel_file() {
    local item="$1"
    local target="$2"
    local skel_name
    local skel_source

    skel_name="$(skel_name_for "$item")" || return 0
    skel_source="$(skel_source_for "$skel_name")" || {
        echo "[WARN] No skel restore source found for $target"
        return 0
    }

    if [[ -e "$target" && ! -L "$target" ]]; then
        echo "[INFO] Not restoring skel over existing regular file: $target"
        return 0
    fi

    mkdir -p "$(dirname "$target")"
    echo "[INFO] Restoring $target from $skel_source"
    cp "$skel_source" "$target"
}

print_skel_status() {
    local item="$1"
    local target="$2"
    local skel_name
    local skel_source

    skel_name="$(skel_name_for "$item")" || return 0
    if skel_source="$(skel_source_for "$skel_name")"; then
        echo "[SKEL] uninstall restore source for $target: $skel_source"
    else
        echo "[SKEL] uninstall restore source missing for $target"
    fi
}

legacy_removed_files() {
    echo "home/atzufuki/.profile"
}

cleanup_legacy_removed_files() {
    local action="$1"
    local item
    local target
    local expected
    local actual
    local raw_target

    while read -r item; do
        target="$(target_for "$item")"
        expected="$(readlink -f "$(dirname "$repo_dir/$item")")/$(basename "$item")"

        if [[ -L "$target" ]]; then
            raw_target="$(readlink "$target")"
            actual="$(readlink -f "$(dirname "$raw_target")")/$(basename "$raw_target")"
        else
            actual=""
        fi

        if [[ -L "$target" && "$actual" == "$expected" ]]; then
            case "$action" in
                install|uninstall)
                    echo "[INFO] Removing legacy symlink: $target"
                    rm "$target"
                    ;;
                dry-run)
                    echo "[DRY-RUN] Would remove legacy symlink: $target"
                    ;;
                status)
                    echo "[LEGACY] $target is still linked to removed dotfile $repo_dir/$item"
                    ;;
            esac
        fi
    done < <(legacy_removed_files)
}

run_scripts() {
    local script_command="$1"

    if [[ ! -d "$scripts_dir" ]]; then
        return 0
    fi

    shopt -s nullglob
    scripts=("$scripts_dir"/*.sh)
    shopt -u nullglob

    if [[ ${#scripts[@]} -eq 0 ]]; then
        return 0
    fi

    echo "[INFO] Running scripts..."
    for script in "${scripts[@]}"; do
        echo "[INFO] Running script: $script $script_command"
        bash "$script" "$script_command" || exit 1
    done
}

print_link_status() {
    local item="$1"
    local target
    local expected
    target="$(target_for "$item")"
    expected="$(readlink -f "$repo_dir/$item")"

    if [[ -L "$target" ]]; then
        if [[ "$(readlink -f "$target")" == "$expected" ]]; then
            echo "[OK] $target -> $repo_dir/$item"
            print_skel_status "$item" "$target"
        else
            echo "[CONFLICT] $target points to $(readlink "$target")"
        fi
    elif [[ -e "$target" ]]; then
        if skel_name="$(skel_name_for "$item")" && skel_source="$(skel_source_for "$skel_name")" && cmp -s "$target" "$skel_source"; then
            echo "[SKEL DEFAULT] $target exists as distro default and can be linked on install"
            print_skel_status "$item" "$target"
        else
            echo "[CONFLICT] $target exists and is not a symlink"
        fi
    else
        echo "[MISSING] $target"
        print_skel_status "$item" "$target"
    fi
}

preview_link() {
    local item="$1"
    local target
    local expected
    target="$(target_for "$item")"
    expected="$(readlink -f "$repo_dir/$item")"

    if [[ -L "$target" && "$(readlink -f "$target")" == "$expected" ]]; then
        echo "[DRY-RUN] Would skip existing symlink: $target"
    elif [[ -e "$target" && ! -L "$target" ]]; then
        if skel_name="$(skel_name_for "$item")" && skel_source="$(skel_source_for "$skel_name")" && cmp -s "$target" "$skel_source"; then
            echo "[DRY-RUN] Would replace skel default with symlink: $target -> $repo_dir/$item"
        else
            echo "[DRY-RUN] Would conflict with existing file: $target"
        fi
    else
        echo "[DRY-RUN] Would create symlink: $target -> $repo_dir/$item"
    fi

    if skel_name_for "$item" >/dev/null; then
        local skel_name
        local skel_source
        skel_name="$(skel_name_for "$item")"
        if skel_source="$(skel_source_for "$skel_name")"; then
            echo "[DRY-RUN] On uninstall would restore $target from $skel_source"
        else
            echo "[DRY-RUN] On uninstall no skel restore source found for $target"
        fi
    fi
}

if [[ "$command" != "install" ]]; then
    run_scripts "$command"
fi
cleanup_legacy_removed_files "$command"

if [[ "$command" == "status" ]]; then
    while read -r item; do
        print_link_status "$item"
    done < <(managed_files)
    exit 0
fi

if [[ "$command" == "dry-run" ]]; then
    while read -r item; do
        preview_link "$item"
    done < <(managed_files)
    exit 0
fi

managed_files | while read -r item; do
    target="$(target_for "$item")"
    if [[ "$command" == "uninstall" ]]; then
        if is_repo_symlink "$item" "$target"; then
            echo "[INFO] Deleting symlink: $target"
            rm "$target"
            restore_skel_file "$item" "$target"
        elif [[ -L "$target" ]]; then
            echo "[INFO] Not deleting non-dotfiles symlink: $target"
        fi
    else
        if [[ -e "$target" && ! -L "$target" ]]; then
            if skel_name="$(skel_name_for "$item")" && skel_source="$(skel_source_for "$skel_name")" && cmp -s "$target" "$skel_source"; then
                echo "[INFO] Replacing skel default with symlink: $target"
            else
                echo "[WARN] Skipping existing regular file: $target"
                continue
            fi
        fi

        # Ensure parent directory exists.
        sudo mkdir -p "$(dirname "$target")"
        echo "[INFO] Creating symlink: $target -> $repo_dir/$item"
        sudo ln -sfn "$repo_dir/$item" "$target"
    fi
done

echo "[INFO] Reloading user systemd state..."
systemctl --user daemon-reload

if [[ "$command" == "install" ]]; then
    run_scripts "$command"
fi

echo "[INFO] Dotfiles command complete!"
