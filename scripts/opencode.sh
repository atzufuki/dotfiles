#!/usr/bin/env bash

set -euo pipefail

command="${1:-apply}"
config_dir="$HOME/.config/opencode"
config_file="$config_dir/opencode.jsonc"

write_llama_config() {
    mkdir -p "$config_dir"
    cat > "$config_file" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  // Managed by atzufuki dotfiles: local llama.cpp provider.
  "provider": {
    "llama.cpp": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "llama-server (local)",
      "options": {
        "baseURL": "http://127.0.0.1:8080/v1"
      },
      "models": {
        "qwen3-coder-30b-a3b-instruct-q3_k_m": {
          "name": "Qwen3 Coder 30B A3B Instruct Q3_K_M (local)",
          "limit": {
            "context": 32768,
            "output": 8192
          }
        },
        "gemma-4-26b-a4b-it-ud-iq4_xs": {
          "name": "Gemma 4 26B A4B IT UD-IQ4_XS (local)",
          "limit": {
            "context": 32768,
            "output": 8192
          }
        },
        "qwen2.5-coder-7b-instruct-q4_k_m": {
          "name": "Qwen2.5 Coder 7B Instruct Q4_K_M (local)",
          "limit": {
            "context": 32768,
            "output": 8192
          }
        }
      }
    }
  }
}
EOF
}

is_minimal_config() {
    local compact

    [[ -f "$config_file" ]] || return 1
    compact="$(tr -d '[:space:]' < "$config_file")"
    [[ "$compact" == '{"$schema":"https://opencode.ai/config.json"}' ]]
}

ensure_llama_config() {
    if [[ ! -f "$config_file" ]] || is_minimal_config; then
        echo "[INFO] Writing OpenCode llama.cpp provider config: $config_file"
        write_llama_config
    elif grep -Fq '"llama.cpp"' "$config_file"; then
        echo "[INFO] OpenCode llama.cpp provider already configured."
    else
        echo "[WARN] OpenCode config exists and is not managed by this script: $config_file"
        echo "[WARN] Add llama.cpp provider manually or simplify the config before rerunning."
    fi
}

case "$command" in
    apply)
        if command -v opencode >/dev/null 2>&1 || [[ -x "$HOME/.opencode/bin/opencode" ]]; then
            echo "[INFO] OpenCode already installed."
            ensure_llama_config
            exit 0
        fi

        curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path
        ensure_llama_config
        ;;
    purge)
        echo "[INFO] Removing OpenCode user installation."
        rm -rf "$HOME/.opencode"
        if [[ -f "$config_file" ]] && grep -Fq 'Managed by atzufuki dotfiles: local llama.cpp provider.' "$config_file"; then
            echo "[INFO] Removing managed OpenCode config: $config_file"
            rm -f "$config_file"
        fi
        ;;
    dry-run)
        if command -v opencode >/dev/null 2>&1 || [[ -x "$HOME/.opencode/bin/opencode" ]]; then
            echo "[DRY-RUN] OpenCode is already installed."
        else
            echo "[DRY-RUN] Would install OpenCode with https://opencode.ai/install."
        fi

        if [[ ! -f "$config_file" ]] || is_minimal_config; then
            echo "[DRY-RUN] Would write OpenCode llama.cpp provider config: $config_file"
        elif grep -Fq '"llama.cpp"' "$config_file"; then
            echo "[DRY-RUN] OpenCode llama.cpp provider is already configured."
        else
            echo "[DRY-RUN] Would warn about existing OpenCode config: $config_file"
        fi
        ;;
    status)
        if command -v opencode >/dev/null 2>&1; then
            echo "[OK] OpenCode installed: $(command -v opencode)"
        elif [[ -x "$HOME/.opencode/bin/opencode" ]]; then
            echo "[OK] OpenCode installed: $HOME/.opencode/bin/opencode"
        else
            echo "[MISSING] OpenCode is not installed"
        fi

        if [[ -f "$config_file" ]] && grep -Fq '"llama.cpp"' "$config_file"; then
            echo "[OK] OpenCode llama.cpp provider configured: $config_file"
        elif [[ -f "$config_file" ]]; then
            echo "[MISSING] OpenCode llama.cpp provider not configured in $config_file"
        else
            echo "[MISSING] OpenCode config is not present: $config_file"
        fi
        ;;
    *)
        echo "Usage: $0 [apply|purge|dry-run|status]"
        exit 1
        ;;
esac
