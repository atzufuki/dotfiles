# atzufuki dotfiles

Personal dotfiles managed with symlinks.

## Usage

Fetch the latest version from GitHub and install it:

```bash
curl -sL https://raw.githubusercontent.com/atzufuki/dotfiles/main/setup.sh | bash
dotfiles install
```

Bootstrap clones or updates the repo at `$HOME/.dotfiles` and installs command symlinks:

```bash
dotfiles
dot
```

Both `dotfiles` and `dot` show help when run without arguments or with `--help`.

Use the current checkout directly:

```bash
./dotfiles.sh install
```

Remove the symlinks and disable the user service:

```bash
dotfiles uninstall
```

Preview install actions without changing files, services, or packages:

```bash
dotfiles dry-run
```

Check symlinks, package state, and managed user services:

```bash
dotfiles status
```

## Packages

Package installers live in `.packages/`. They are not symlinked because `.packages/` is ignored by `.dotfilesignore`.

Each package script receives one command:

```bash
.packages/name.sh install
.packages/name.sh uninstall
.packages/name.sh dry-run
.packages/name.sh status
```

Managed packages:

- Zed via `curl -f https://zed.dev/install.sh | sh`
- OpenCode via `curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path`

User binaries are expected in `$HOME/.local/bin` and `$HOME/.opencode/bin`. Bazzite's default `.bashrc` already adds `$HOME/.local/bin`; dotfiles adds `$HOME/.opencode/bin` from `home/atzufuki/.bashrc.d/dotfiles.sh`.

## Shell

Shell startup follows Bazzite's skel layout:

- `home/atzufuki/.bashrc` extends `/usr/etc/skel/.bashrc` with `/etc/skel/.bashrc` as fallback.
- `home/atzufuki/.bash_profile` extends `/usr/etc/skel/.bash_profile` with `/etc/skel/.bash_profile` as fallback.
- `home/atzufuki/.bashrc.d/dotfiles.sh` contains dotfiles-specific interactive shell additions.

Uninstall removes dotfiles symlinks for `.bashrc` and `.bash_profile`, then restores Bazzite defaults from skel. The old `.profile` symlink is treated as legacy and removed without restore.

## Zed

Zed settings are managed at `home/atzufuki/.config/zed/settings.json`.

The local theme is managed at `home/atzufuki/.config/zed/themes/hyper-term-black.json` and is selected as `Hyper Term Black`.

Layout defaults:

- Project panel on the left
- Terminal panel on the right
- Agent panel on the right

## Secret Guard

`dotfiles install`, `dotfiles dry-run`, and `dotfiles status` scan repo file paths for likely secrets before continuing.

Blocked path patterns include `.env`, `.pem`, `.key`, `.crt`, `.cert`, `credentials*.json`, and names containing `secret` or `secrets`.

Keep real secrets outside this repo or ignore them locally before running setup.

## Features

- Scarlett stereo PipeWire loopback user service
- Zed editor setup with Hyper Term Black theme
- Zed and OpenCode user-level package installers
