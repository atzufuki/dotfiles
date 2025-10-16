# Copilot Instructions for Dotfiles

## Project Overview

This is a **minimal Fedora host + containerized desktop environment** dotfiles repository. The architecture separates immutable host configuration from containerized desktop environments (GNOME via Distrobox), providing system integrity while allowing flexible DE updates.

### Key Architecture Pattern

- **Host level** (root/system): Fedora Silverblue/Kinoite with minimal configuration
  - Location: `etc/`, `usr/` directories (installed at `/etc` and `/usr` via symlinks)
  - Files: Session launchers, environment fixes, profile.d scripts
- **User level**: Home directory configs in `home/atzufuki/`
  - Location: Symlinked to `~` during setup
  - Files: `.bashrc`, `.profile`, Sway WM config
- **Container level**: GNOME via Distrobox in `fedora-gnome`
  - Bootstrap: `containers/gnome/bootstrap.sh`
  - Launched via: `usr/local/bin/distrobox-gnome-session.sh`

## Setup & Deployment Workflow

### Single Command Installation
```bash
curl -sL https://raw.githubusercontent.com/atzufuki/dotfiles/main/setup.sh | bash
```

### Setup Script Logic (`setup.sh`)
1. **Clone/update** dotfiles repo to `~/.dotfiles`
2. **Symlink files** based on `.dotfilesignore` (inverse whitelist approach)
3. **Install Distrobox** if missing
4. **Create `fedora-gnome` container** with specific mounts/packages
5. **Bootstrap container** by running `containers/gnome/bootstrap.sh`

### Critical Convention: `.dotfilesignore`
- **Inverse-list approach**: Only excludes specific files/directories
- Currently excludes: `.git/`, `containers/`, `setup.sh`, `README.md`
- All other files are symlinked to root filesystem
- **When adding new files**: Update `.dotfilesignore` if they shouldn't be system-wide symlinks

## Key Components & Patterns

### 1. Wayland Session Integration
- **File**: `usr/share/wayland-sessions/distrobox-gnome.desktop`
- **Purpose**: Registers containerized GNOME as available session at login
- **Launch script**: `usr/local/bin/distrobox-gnome-session.sh`
- **Pattern**: Uses `xhost` for X11 socket access + Wayland-specific env vars (`XDG_RUNTIME_DIR`, `WAYLAND_DISPLAY`)

### 2. Host-Container Communication
- **X11/Wayland socket mounting**: `$XDG_RUNTIME_DIR` shared between host and container
- **Fix script**: `etc/profile.d/fix_tmp.sh` - ensures `/tmp/.X11-unix` ownership for host user
- **Pattern**: Profile.d scripts execute early to establish socket/device ownership

### 3. Container Initialization
- **Bootstrap**: `containers/gnome/bootstrap.sh` runs inside container
- **Current state**: Installs `workstation-product-environment` group via dnf (GNOME + deps)
- **Pattern**: Intentionally minimal - only installs what's necessary; extends via dotfiles post-login

## Development Patterns & Conventions

### File Organization
- **System files** (`etc/`, `usr/`): Installed to filesystem root via sudo symlinks
- **User files** (`home/atzufuki/`): Installed to user home via symlinks
- **Container-specific** (`containers/`): Never symlinked, only executed during setup
- **Pattern**: Mirror filesystem hierarchy within dotfiles structure

### Symlink Strategy
- Use `ln -sfn` (force symbolic links, not hardlinks)
- Parent directories created via `sudo mkdir -p`
- Absolute paths: `$HOME/.dotfiles/$item` as symlink target
- Benefit: Clean separation of dotfiles repo from deployed config

### Shell Scripts
- Shebang: `#!/usr/bin/env bash` (not `#!/bin/bash`) for portability
- Error handling: Basic checks (command existence via `command -v`, directory existence via `[[ -d ]]`)
- Logging: `[INFO]` prefix for status messages to distinguish from command output

## Integration Points & Dependencies

### External Tools
- **Distrobox**: Container management - check availability with `command -v distrobox`
- **Fedora dnf**: Package manager inside container
- **Wayland**: Assumed display server on host (XDG_RUNTIME_DIR integration)
- **Systemd**: Required in container for session management

### Cross-Component Data Flow
1. Host boots → Silverblue/Kinoite minimal state
2. User logs in → Wayland session selector shows `distrobox-gnome.desktop`
3. User selects GNOME session → Runs `distrobox-gnome-session.sh`
4. Script sets up Wayland socket access + launches `gnome-session` inside container
5. Container startup executes profile.d scripts (including `fix_tmp.sh`)
6. User shell loads `.bashrc` + `.profile` from symlinked dotfiles

## When Modifying Components

### Adding System Configuration
1. Create file in appropriate `etc/` or `usr/` subdirectory
2. Verify `.dotfilesignore` won't exclude it
3. Test symlink creation in fresh clone
4. If adding shell sourcing: use profile.d pattern (files in `etc/profile.d/` auto-source)

### Extending Container Environment
- Edit `containers/gnome/bootstrap.sh` for packages/groups to install
- Edit `containers/gnome/bootstrap.sh` for post-install setup scripts
- Note: Container updates via `distrobox enter fedora-gnome -- <command>`

### Updating Session Configuration
- Wayland desktop entry: `usr/share/wayland-sessions/distrobox-gnome.desktop`
- Session launcher: `usr/local/bin/distrobox-gnome-session.sh`
- Test with: `distrobox-gnome-session.sh` directly or via login screen
