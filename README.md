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
- Antigravity 2 user-level desktop installer
- Antigravity CLI user-level installer
- Google Chrome user-level RPM extractor installer
- Google Cloud CLI user-level installer
- Git Credential Manager user-level installer
- GitHub CLI user-level installer
- GNOME rounded window corners setup
- Deno user-level installer
- Docker Engine static binary installer
- Docker Desktop RPM extractor installer
- Podman-based Docker compatibility setup
- Rust toolchain user-level installer
- GitHub SSH key and repository push setup
- Tailscale system service setup
- Slack user-level RPM extractor installer
- llama.cpp local AI runtime setup with AMD-friendly Vulkan backend
- Zed editor setup with Hyper Term Black theme
- OpenCode user-level installer
