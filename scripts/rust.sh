#!/usr/bin/env bash

set -euo pipefail

command="${1:-apply}"
cargo_home="${CARGO_HOME:-$HOME/.cargo}"
rustup_home="${RUSTUP_HOME:-$HOME/.rustup}"
cargo_bin="$cargo_home/bin/cargo"
rustup_bin="$cargo_home/bin/rustup"

case "$command" in
    apply)
        if command -v cargo >/dev/null 2>&1 || [[ -x "$cargo_bin" ]]; then
            echo "[INFO] Rust toolchain already installed, skipping."
            exit 0
        fi

        echo "[INFO] Installing Rust toolchain with rustup."
        curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path
        ;;
    purge)
        if command -v rustup >/dev/null 2>&1; then
            echo "[INFO] Removing Rust toolchain with rustup."
            rustup self uninstall -y
        elif [[ -x "$rustup_bin" ]]; then
            echo "[INFO] Removing Rust toolchain with $rustup_bin."
            "$rustup_bin" self uninstall -y
        else
            echo "[INFO] Removing Rust user installation directories."
            rm -rf "$cargo_home" "$rustup_home"
        fi
        ;;
    dry-run)
        if command -v cargo >/dev/null 2>&1 || [[ -x "$cargo_bin" ]]; then
            echo "[DRY-RUN] Rust toolchain is already installed."
        else
            echo "[DRY-RUN] Would install Rust toolchain with rustup."
        fi
        ;;
    status)
        if command -v cargo >/dev/null 2>&1; then
            echo "[OK] Cargo installed: $(command -v cargo)"
        elif [[ -x "$cargo_bin" ]]; then
            echo "[OK] Cargo installed: $cargo_bin"
        else
            echo "[MISSING] Cargo is not installed"
        fi

        if command -v rustup >/dev/null 2>&1; then
            echo "[OK] rustup installed: $(command -v rustup)"
        elif [[ -x "$rustup_bin" ]]; then
            echo "[OK] rustup installed: $rustup_bin"
        else
            echo "[MISSING] rustup is not installed"
        fi
        ;;
    *)
        echo "Usage: $0 [apply|purge|dry-run|status]"
        exit 1
        ;;
esac
