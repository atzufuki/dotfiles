#!/usr/bin/env bash

delete_symlinks=false
run_bootstrap=false

if [[ "$1" == "--delete" ]]; then
    delete_symlinks=true
elif [[ "$1" == "--bootstrap" ]]; then
    run_bootstrap=true
fi

git clone "https://github.com/atzufuki/dotfiles.git" "$HOME/.dotfiles"

ignore_file="$HOME/.dotfiles/.dotfilesignore"

if [[ -f "$ignore_file" ]]; then
    cd "$HOME/.dotfiles"
    find . -mindepth 1 -maxdepth 1 | grep -vFf "$ignore_file" | while read -r item; do
        target="$HOME/${item#./}"
        if $delete_symlinks; then
            [[ -L "$target" ]] && rm "$target"
        else
            ln -sfn "$HOME/.dotfiles/${item#./}" "$target"
        fi
    done
else
    for item in "$HOME/.dotfiles/"*; do
        target="$HOME/$(basename "$item")"
        if $delete_symlinks; then
            [[ -L "$target" ]] && rm "$target"
        else
            ln -sfn "$item" "$target"
        fi
    done
fi

if $run_bootstrap; then
    if [[ -f "$HOME/.dotfiles/bootstrap.sh" ]]; then
        bash "$HOME/.dotfiles/bootstrap.sh"
    else
        echo "bootstrap.sh not found in .dotfiles"
        exit 1
    fi
    exit 0
fi
