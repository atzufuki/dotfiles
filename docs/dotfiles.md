# Dotfiles Tool

## Commands

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

Feature scripts live in `scripts/`. They are not symlinked because `scripts/` is ignored by `.dotfilesignore`.

Each script receives one command:

```bash
scripts/name.sh apply
scripts/name.sh purge
scripts/name.sh dry-run
scripts/name.sh status
```

Scripts can declare dependencies with metadata comments:

```bash
# dotfiles-depends: gh
```

Active scripts are run in dependency order for `apply` and `dry-run`. `status` runs all scripts in dependency order, and `purge` runs all scripts in reverse dependency order.

If an active script depends on an inactive or missing script, `dot apply` and `dot dry-run` fail with an error.

## Config

Default active selections live in `dotfiles.defaults.conf`. Local selections are written to gitignored `dotfiles.conf` by `dot configure`.

Available scripts are discovered from `scripts/*.sh`, and available modules are discovered from `modules/` plus `EXTERNAL_MODULE_REPOS` in `dotfiles.defaults.conf`.

## Modules

External module repositories are defined in `dotfiles.defaults.conf` as `EXTERNAL_MODULE_REPOS` and cloned into `modules/` when setup is run with `--external`.

Active modules can provide `scripts/*.sh`. Module scripts run when the module is listed in `ACTIVE_MODULES`.
