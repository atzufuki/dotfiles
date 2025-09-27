#!/usr/bin/env bash

export GITHUB_USERNAME="atzufuki"

# Chezmoi init and apply
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply $GITHUB_USERNAME
