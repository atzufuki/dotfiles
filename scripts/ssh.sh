#!/usr/bin/env bash
# dotfiles-depends: gh

set -euo pipefail

command="${1:-apply}"
repo="atzufuki/dotfiles"
github_host_alias="github.com-dotfiles"
repo_ssh_url="git@${github_host_alias}:${repo}.git"
repo_dir="${DOTFILES_REPO_DIR:-$HOME/.dotfiles}"
bin_dir="$HOME/.local/bin"
key_file="$HOME/.ssh/id_ed25519_github"
pub_key_file="$key_file.pub"
ssh_config_file="$HOME/.ssh/config"
ssh_config_start="# dotfiles github ssh start"
ssh_config_end="# dotfiles github ssh end"

if [[ -x "$bin_dir/gh" && ":$PATH:" != *":$bin_dir:"* ]]; then
    export PATH="$bin_dir:$PATH"
fi

ensure_gh() {
    if ! command -v gh >/dev/null 2>&1; then
        echo "[ERROR] GitHub CLI is required before SSH setup."
        exit 1
    fi
}

ensure_gh_auth() {
    if gh auth status --hostname github.com >/dev/null 2>&1; then
        return 0
    fi

    gh auth login --hostname github.com --web --git-protocol ssh --scopes admin:public_key --skip-ssh-key
}

ensure_ssh_key() {
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    if [[ -f "$key_file" && -f "$pub_key_file" ]]; then
        return 0
    fi

    if [[ -e "$key_file" || -e "$pub_key_file" ]]; then
        echo "[ERROR] Incomplete SSH key pair exists at $key_file."
        exit 1
    fi

    ssh-keygen -t ed25519 -f "$key_file" -N "" -C "atzufuki dotfiles $(hostname)"
}

ensure_ssh_config() {
    local line
    local skip=0
    local tmp_file

    touch "$ssh_config_file"
    chmod 600 "$ssh_config_file"

    tmp_file="$(mktemp)"

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "$ssh_config_start" ]]; then
            skip=1
            continue
        fi
        if [[ "$line" == "$ssh_config_end" ]]; then
            skip=0
            continue
        fi
        [[ "$skip" -eq 1 ]] && continue
        echo "$line" >> "$tmp_file"
    done < "$ssh_config_file"

    {
        cat "$tmp_file"
        if [[ -s "$tmp_file" ]]; then
            echo
        fi
        echo "$ssh_config_start"
        echo "Host $github_host_alias"
        echo "    HostName github.com"
        echo "    User git"
        echo "    IdentityFile $key_file"
        echo "    IdentitiesOnly yes"
        echo "$ssh_config_end"
    } > "$ssh_config_file"

    rm -f "$tmp_file"
}

github_has_ssh_key() {
    local key
    local public_key

    public_key="$(<"$pub_key_file")"
    while IFS= read -r key; do
        [[ "$key" == "$public_key" ]] && return 0
    done < <(gh api user/keys --jq '.[].key')

    return 1
}

ensure_github_ssh_key() {
    if github_has_ssh_key; then
        return 0
    fi

    if ! gh ssh-key add "$pub_key_file" --title "dotfiles $(hostname)"; then
        gh auth refresh --hostname github.com --scopes admin:public_key
        gh ssh-key add "$pub_key_file" --title "dotfiles $(hostname)"
    fi
}

set_dotfiles_remote() {
    if [[ ! -d "$repo_dir/.git" ]]; then
        echo "[WARN] Dotfiles git repo not found: $repo_dir"
        return 0
    fi

    if git -C "$repo_dir" remote get-url origin >/dev/null 2>&1; then
        git -C "$repo_dir" remote set-url origin "$repo_ssh_url"
    else
        git -C "$repo_dir" remote add origin "$repo_ssh_url"
    fi
}

print_repo_permission() {
    local permission

    if ! permission="$(gh repo view "$repo" --json viewerPermission --jq .viewerPermission 2>/dev/null)"; then
        echo "[WARN] Could not check GitHub repository permission for $repo."
        return 0
    fi

    case "$permission" in
        ADMIN|MAINTAIN|WRITE)
            echo "[OK] GitHub repository push access: $permission"
            ;;
        *)
            echo "[WARN] GitHub repository push access missing for $repo: $permission"
            ;;
    esac
}

case "$command" in
    apply)
        ensure_gh
        ensure_ssh_key
        ensure_gh_auth
        gh config set git_protocol ssh --host github.com >/dev/null
        gh auth setup-git --hostname github.com >/dev/null
        ensure_ssh_config
        ensure_github_ssh_key
        set_dotfiles_remote
        print_repo_permission
        ;;
    purge)
        echo "[INFO] Not removing SSH keys or GitHub SSH keys automatically."
        ;;
    dry-run)
        if [[ -f "$key_file" && -f "$pub_key_file" ]]; then
            echo "[DRY-RUN] GitHub SSH key pair exists: $key_file"
        else
            echo "[DRY-RUN] Would create GitHub SSH key pair: $key_file"
        fi

        if command -v gh >/dev/null 2>&1; then
            if gh auth status --hostname github.com >/dev/null 2>&1; then
                echo "[DRY-RUN] GitHub CLI is authenticated."
            else
                echo "[DRY-RUN] Would authenticate GitHub CLI in browser."
            fi
        else
            echo "[DRY-RUN] GitHub CLI is required before SSH setup."
        fi

        echo "[DRY-RUN] Would add $pub_key_file to GitHub if missing."
        echo "[DRY-RUN] Would configure SSH host alias $github_host_alias."
        echo "[DRY-RUN] Would set dotfiles origin remote to $repo_ssh_url."
        ;;
    status)
        if [[ -f "$key_file" && -f "$pub_key_file" ]]; then
            echo "[OK] GitHub SSH key pair exists: $key_file"
        else
            echo "[MISSING] GitHub SSH key pair is missing: $key_file"
        fi

        if command -v gh >/dev/null 2>&1; then
            if gh auth status --hostname github.com >/dev/null 2>&1; then
                echo "[OK] GitHub CLI authenticated."
                if [[ -f "$pub_key_file" ]]; then
                    if github_has_ssh_key; then
                        echo "[OK] GitHub SSH key is registered."
                    else
                        echo "[MISSING] GitHub SSH key is not registered."
                    fi
                fi
                print_repo_permission
            else
                echo "[MISSING] GitHub CLI is not authenticated."
            fi
        else
            echo "[MISSING] GitHub CLI is not installed."
        fi

        if [[ -d "$repo_dir/.git" ]]; then
            echo "[INFO] Dotfiles origin: $(git -C "$repo_dir" remote get-url origin 2>/dev/null || true)"
        else
            echo "[MISSING] Dotfiles git repo not found: $repo_dir"
        fi

        if [[ -f "$ssh_config_file" ]] && grep -Fxq "$ssh_config_start" "$ssh_config_file"; then
            echo "[OK] SSH host alias configured: $github_host_alias"
        else
            echo "[MISSING] SSH host alias is not configured: $github_host_alias"
        fi
        ;;
    *)
        echo "Usage: $0 [apply|purge|dry-run|status]"
        exit 1
        ;;
esac
