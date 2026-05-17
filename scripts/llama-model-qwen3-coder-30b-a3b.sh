#!/usr/bin/env bash
# dotfiles-depends: llama-cpp

set -euo pipefail

command="${1:-apply}"
config_dir="$HOME/.config/llama.cpp"
models_dir="$HOME/.local/share/llama.cpp/models"
env_file="$config_dir/server.env"
service="llama-cpp.service"
repo_dir="${DOTFILES_REPO_DIR:-$HOME/.dotfiles}"
service_source="$repo_dir/home/atzufuki/.config/systemd/user/$service"
service_target="$HOME/.config/systemd/user/$service"
model_id="qwen3-coder-30b-a3b-instruct-q3_k_m"
model_name="Qwen3-Coder-30B-A3B-Instruct-Q3_K_M.gguf"
model_file="$models_dir/$model_name"
model_url="https://huggingface.co/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF/resolve/main/$model_name"

write_model_env() {
    mkdir -p "$config_dir"
    cat > "$env_file" <<EOF
LLAMA_CPP_HOST=127.0.0.1
LLAMA_CPP_PORT=8080
LLAMA_CPP_CONTEXT=32768
LLAMA_CPP_BATCH=512
LLAMA_CPP_UBATCH=512
LLAMA_CPP_GPU_LAYERS=999
LLAMA_CPP_MODEL="$model_file"
LLAMA_CPP_MODEL_ID=$model_id
LLAMA_CPP_EXTRA_ARGS="--jinja --flash-attn auto"
EOF
}

is_active_model() {
    [[ -f "$env_file" ]] && grep -Fqx "LLAMA_CPP_MODEL=\"$model_file\"" "$env_file"
}

ensure_service_file() {
    if [[ ! -f "$service_source" ]]; then
        echo "[ERROR] Missing service file in dotfiles repo: $service_source"
        exit 1
    fi

    if [[ -e "$service_target" && ! -L "$service_target" ]]; then
        echo "[ERROR] Refusing to replace non-symlink service file: $service_target"
        exit 1
    fi

    mkdir -p "$(dirname "$service_target")"
    ln -sfn "$service_source" "$service_target"
}

case "$command" in
    apply)
        if [[ ! -x "$HOME/.local/bin/llama-server" ]]; then
            echo "[ERROR] llama-server is not installed. Run llama-cpp apply first."
            exit 1
        fi

        mkdir -p "$models_dir"
        if [[ -f "$model_file" ]]; then
            echo "[INFO] Model already downloaded: $model_file"
        else
            echo "[INFO] Downloading $model_name."
            curl -fL --continue-at - "$model_url" -o "$model_file"
        fi

        write_model_env
        ensure_service_file
        systemctl --user daemon-reload
        echo "[INFO] Enabling $service with $model_id."
        systemctl --user enable --now "$service"
        systemctl --user restart "$service"
        ;;
    purge)
        if is_active_model; then
            echo "[INFO] Disabling $service because active model is being removed."
            systemctl --user disable --now "$service" || true
            rm -f "$env_file"
        fi

        if [[ -f "$model_file" ]]; then
            echo "[INFO] Removing model: $model_file"
            rm -f "$model_file"
        fi
        ;;
    dry-run)
        if [[ -f "$model_file" ]]; then
            echo "[DRY-RUN] Model already exists: $model_file"
        else
            echo "[DRY-RUN] Would download: $model_url"
        fi
        echo "[DRY-RUN] Would write active llama.cpp model env: $env_file"
        echo "[DRY-RUN] Would enable and restart $service."
        ;;
    status)
        if [[ -f "$model_file" ]]; then
            echo "[OK] Model downloaded: $model_file"
        else
            echo "[MISSING] Model is not downloaded: $model_file"
        fi

        if is_active_model; then
            echo "[OK] Model is active in $env_file"
        else
            echo "[INFO] Model is not active in $env_file"
        fi
        ;;
    *)
        echo "Usage: $0 [apply|purge|dry-run|status]"
        exit 1
        ;;
esac
