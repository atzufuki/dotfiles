# atzufuki dotfiles

Personal dotfiles managed with symlinks.

## Setup

Fetch the latest version from GitHub and install it:

```bash
curl -sL https://raw.githubusercontent.com/atzufuki/dotfiles/main/setup.sh | bash
dot apply
```

Include external modules during setup:

```bash
curl -sL https://raw.githubusercontent.com/atzufuki/dotfiles/main/setup.sh | bash -s -- --external
dot apply
```

## Features

- Scarlett stereo PipeWire loopback user service
- GitHub CLI user-level installer
- GitHub SSH key and repository push setup
- Zed editor setup with Hyper Term Black theme
- OpenCode user-level installer
