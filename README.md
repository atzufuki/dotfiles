# atzufuki dotfiles

Personal dotfiles managed with symlinks.

## Install

Fetch the latest version from GitHub and install it:

```bash
curl -sL https://raw.githubusercontent.com/atzufuki/dotfiles/main/setup.sh | bash
```

Use the current checkout without fetching from GitHub:

```bash
./setup.sh install
```

## Uninstall

Remove the symlinks and disable the user service:

```bash
./setup.sh uninstall
```

## Features

- Scarlett stereo PipeWire loopback user service
