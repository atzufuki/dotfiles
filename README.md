# Fedora Silverblue Sway + GNOME via Distrobox Setup

## Bootstrap

Run the bootstrap script directly with:

```bash
curl -sL https://raw.githubusercontent.com/atzufuki/dotfiles/main/bootstrap.sh | bash
```

This will set up Distrobox and the Fedora GNOME container automatically.

## Dotfiles Structure
- `host/`: Dotfiles for the Fedora Silverblue Sway host (e.g., `host/.bashrc`, `host/.profile`).
- `container-gnome/`: Dotfiles for the GNOME container (e.g., `container-gnome/.bashrc`, `container-gnome/.profile`).
- `.config/gnome/`: GNOME-specific configs for the container.
- `bootstrap.sh`: Installs Distrobox, Podman, and sets up Fedora GNOME container.
- `distrobox-gnome.sh`: Enters the container and launches GNOME Shell.

> For future setups, add more `container-<de>/` directories for other desktop environments (e.g., KDE, XFCE).

## Reference
- [Run latest GNOME/KDE on Distrobox](https://distrobox.it/posts/run_latest_gnome_kde_on_distrobox/)