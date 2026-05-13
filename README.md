# atzufuki dotfiles

Personal dotfiles managed with symlinks.

## Usage

Fetch the latest version from GitHub and install it:

```bash
curl -sL https://raw.githubusercontent.com/atzufuki/dotfiles/main/setup.sh | bash
dot install
```

Include private modules during setup:

```bash
curl -sL https://raw.githubusercontent.com/atzufuki/dotfiles/main/setup.sh | bash -s -- --private
dot install
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
dot uninstall
```

Preview install actions without changing files. Scripts receive the `dry-run` command:

```bash
dot dry-run
```

Check symlinks, script state, and managed user services:

```bash
dot status
```

## Scripts

Install scripts live in `scripts/`. They are run alphabetically and are not symlinked because `scripts/` is ignored by `.dotfilesignore`.

Each script receives one command:

```bash
scripts/name.sh install
scripts/name.sh uninstall
scripts/name.sh dry-run
scripts/name.sh status
```

## Features

- Scarlett stereo PipeWire loopback user service
- Zed editor setup with Hyper Term Black theme
- Zed and OpenCode user-level installers
- Optional private modules with `setup.sh --private`
