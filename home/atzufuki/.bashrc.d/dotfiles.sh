# Dotfiles shell additions.

if ! [[ "$PATH" =~ "$HOME/.cargo/bin:" ]]; then
    PATH="$HOME/.cargo/bin:$PATH"
fi

if ! [[ "$PATH" =~ "$HOME/.deno/bin:" ]]; then
    PATH="$HOME/.deno/bin:$PATH"
fi

if ! [[ "$PATH" =~ "$HOME/.opencode/bin:" ]]; then
    PATH="$HOME/.opencode/bin:$PATH"
fi

export PATH
