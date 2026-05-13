# Dotfiles shell additions.

if ! [[ "$PATH" =~ "$HOME/.opencode/bin:" ]]; then
    PATH="$HOME/.opencode/bin:$PATH"
fi

export PATH
