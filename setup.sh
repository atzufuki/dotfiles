#!/usr/bin/env bash

# Dotfiles bootstrap script.
# This script clones or updates the repo and installs the dotfiles commands.

usage() {
    cat <<'EOF'
Usage: setup.sh [--external] [--help]

Clones or updates https://github.com/atzufuki/dotfiles.git at $HOME/.dotfiles
and installs these commands through $HOME/.local/bin:

  dotfiles
  dot

Run `dot apply` after setup to apply the dotfiles.

Options:
  --external  Authenticate with GitHub in browser and clone external modules
EOF
}

install_external_modules=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --external)
            install_external_modules=1
            ;;
        --help|-h|help)
            usage
            exit 0
            ;;
        *)
            usage
            exit 1
            ;;
    esac
    shift
done

repo_url="https://github.com/atzufuki/dotfiles.git"
repo_dir="$HOME/.dotfiles"
bin_dir="$HOME/.local/bin"
dotfiles_script="$repo_dir/dotfiles.sh"
defaults_file="$repo_dir/dotfiles.defaults.conf"

ensure_gh() {
    if [[ -x "$HOME/.local/bin/gh" && ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        export PATH="$HOME/.local/bin:$PATH"
    fi

    if command -v gh >/dev/null 2>&1; then
        return 0
    fi

    case "$(uname -s)" in
        Linux) gh_os="linux" ;;
        *)
            echo "[ERROR] Unsupported OS for automatic GitHub CLI install: $(uname -s)"
            exit 1
            ;;
    esac

    case "$(uname -m)" in
        x86_64) gh_arch="amd64" ;;
        aarch64|arm64) gh_arch="arm64" ;;
        *)
            echo "[ERROR] Unsupported architecture for automatic GitHub CLI install: $(uname -m)"
            exit 1
            ;;
    esac

    echo "[INFO] Installing GitHub CLI in $HOME/.local/bin..."
    gh_version="$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | sed -n 's/.*"tag_name": "v\([^"]*\)".*/\1/p')"
    if [[ -z "$gh_version" ]]; then
        echo "[ERROR] Could not resolve latest GitHub CLI version."
        exit 1
    fi

    gh_tmp="$(mktemp -d)"
    trap 'rm -rf "$gh_tmp"' RETURN
    curl -fsSL "https://github.com/cli/cli/releases/download/v${gh_version}/gh_${gh_version}_${gh_os}_${gh_arch}.tar.gz" -o "$gh_tmp/gh.tar.gz"
    tar -xzf "$gh_tmp/gh.tar.gz" -C "$gh_tmp"
    mkdir -p "$HOME/.local/bin"
    cp "$gh_tmp/gh_${gh_version}_${gh_os}_${gh_arch}/bin/gh" "$HOME/.local/bin/gh"
    chmod +x "$HOME/.local/bin/gh"
    export PATH="$HOME/.local/bin:$PATH"
}

ensure_gh_auth() {
    ensure_gh
    gh auth status >/dev/null 2>&1 || gh auth login --web
    gh auth setup-git --hostname github.com >/dev/null
}

install_external_module_repos() {
    local module
    local repo
    local name
    local module_dir

    if [[ ! -f "$defaults_file" ]]; then
        echo "[ERROR] Dotfiles defaults not found: $defaults_file"
        exit 1
    fi

    source "$defaults_file"
    ensure_gh_auth
    mkdir -p "$repo_dir/modules"

    while IFS= read -r module; do
        repo="${module%%:*}"
        name="${module#*:}"
        module_dir="$repo_dir/modules/$name"

        if [[ -d "$module_dir/.git" ]]; then
            echo "[INFO] External module exists. Pulling latest changes: $name"
            git -C "$module_dir" pull
        elif [[ -e "$module_dir" ]]; then
            if [[ -d "$module_dir" && -f "$module_dir/.keep" && -z "$(find "$module_dir" -mindepth 1 ! -name .keep -print -quit)" ]]; then
                rm "$module_dir/.keep"
                rmdir "$module_dir"
                echo "[INFO] Cloning external module: $repo"
                gh repo clone "$repo" "$module_dir"
            else
                echo "[ERROR] $module_dir exists but is not a git repo."
                exit 1
            fi
        else
            echo "[INFO] Cloning external module: $repo"
            gh repo clone "$repo" "$module_dir"
        fi
    done < <(external_modules)
}

external_modules() {
    local entry

    for entry in "${EXTERNAL_MODULE_REPOS[@]}"; do
        [[ "$entry" == *=* ]] || {
            echo "[ERROR] Invalid external module entry: $entry" >&2
            exit 1
        }

        echo "${entry#*=}:${entry%%=*}"
    done
}

if [[ -d "$repo_dir/.git" ]]; then
    echo "[INFO] Dotfiles repo exists. Pulling latest changes..."
    git -C "$repo_dir" pull
elif [[ -e "$repo_dir" ]]; then
    echo "[ERROR] $repo_dir exists but is not a git repo."
    exit 1
else
    echo "[INFO] Cloning dotfiles repository..."
    git clone "$repo_url" "$repo_dir"
fi

if [[ "$install_external_modules" -eq 1 ]]; then
    install_external_module_repos
fi

if [[ ! -f "$dotfiles_script" ]]; then
    echo "[ERROR] Dotfiles command script not found: $dotfiles_script"
    exit 1
fi

mkdir -p "$bin_dir"
chmod +x "$dotfiles_script"

echo "[INFO] Installing commands in $bin_dir..."
ln -sfn "$dotfiles_script" "$bin_dir/dotfiles"
ln -sfn "$dotfiles_script" "$bin_dir/dot"

if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
    echo "[WARN] $bin_dir is not in PATH for this shell. Open a new shell or add it to PATH."
fi

echo "[INFO] Bootstrap complete. Run: dot apply"
