# atzufuki dotfiles

Personal dotfiles managed with symlinks.

## Usage

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

Bootstrap clones or updates the repo at `$HOME/.dotfiles` and installs command symlinks:

```bash
dotfiles
dot
```

Both `dotfiles` and `dot` show help when run without arguments or with `--help`.

Use the current checkout directly:

```bash
./dotfiles.sh apply
```

Configure local feature selections:

```bash
dot configure
```

Purge dotfiles-managed changes and local config:

```bash
dot purge
```

Preview apply actions without changing files. Scripts receive the `dry-run` command:

```bash
dot dry-run
```

Check symlinks, script state, and managed user services:

```bash
dot status
```

## Scripts

Feature scripts live in `scripts/`. They are run alphabetically and are not symlinked because `scripts/` is ignored by `.dotfilesignore`.

Each script receives one command:

```bash
scripts/name.sh apply
scripts/name.sh purge
scripts/name.sh dry-run
scripts/name.sh status
```

## Config

Default active selections live in `dotfiles.defaults.conf`. Local selections are written to gitignored `dotfiles.conf` by `dot configure`.

Available scripts are discovered from `scripts/*.sh`, and available modules are discovered from `modules/` plus `EXTERNAL_MODULE_REPOS` in `dotfiles.defaults.conf`.

## Modules

External module repositories are defined in `dotfiles.defaults.conf` as `EXTERNAL_MODULE_REPOS` and cloned into `modules/` when setup is run with `--external`.

## Features

- Scarlett stereo PipeWire loopback user service
- Zed editor setup with Hyper Term Black theme
- Zed and OpenCode user-level installers
- Optional external modules with `setup.sh --external`
