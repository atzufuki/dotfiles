# Container-Based Desktop Environment for Fedora

Run a **minimal, immutable-style Fedora host** with desktop environments isolated in Distrobox containers. No GNOME or KDE installed on the host—only a lightweight Wayland compositor (cage) that launches containerized desktops.

## Features

✅ **Pristine host system** - No desktop environment bloat on the host  
✅ **Disposable desktops** - Break something? Delete and recreate the container  
✅ **Full GPU acceleration** - Native graphics performance via `/dev/dri` passthrough  
✅ **Wayland + PipeWire** - Modern graphics and audio stack  
✅ **Easy switching** - Run multiple desktop containers (GNOME, KDE, SteamOS-style)  
✅ **Immutable-OS friendly** - Perfect for Silverblue, Kinoite, or custom setups

## Architecture

```
Fedora Minimal Host
└── Cage (Wayland compositor)
    └── Distrobox Container
        └── GNOME/KDE/Steam Desktop
```

**Host packages:** podman, distrobox, cage, pipewire, mesa drivers  
**Container:** Full desktop environment with GPU and audio access

## Quick Start

### One-line install

```bash
curl -sL https://raw.githubusercontent.com/atzufuki/dotfiles/main/setup.sh | bash
```

### Manual installation

1. **Clone this repository:**
   ```bash
   git clone https://github.com/atzufuki/dotfiles.git
   cd dotfiles
   ```

2. **Run setup script:**
   ```bash
   bash setup.sh
   ```

3. **Log out and select "GNOME (Distrobox)" at login screen**

## What Gets Installed

### Host System
- `podman` - Container runtime
- `distrobox` - Container management
- `cage` - Minimal Wayland compositor
- `pipewire` + `wireplumber` - Audio system
- Mesa GPU drivers + Xwayland

### GNOME Container (gnome-box)
- GNOME Shell + Session
- GNOME Terminal, Nautilus, Control Center
- Full Wayland support with GPU acceleration

## Usage

### Launch Desktop
Select **"GNOME (Distrobox)"** from your login manager (GDM, SDDM, etc.)

### Manage Containers

**Rebuild broken container:**
```bash
distrobox rm gnome-box
bash containers/gnome/create.sh
```

**Enter container shell:**
```bash
distrobox enter gnome-box
```

**View all containers:**
```bash
distrobox list
```

## Project Structure

```
dotfiles/
├── setup.sh                          # Main installation script
├── README.md                         # This file
├── IMPLEMENTATION_PLAN.md            # Technical implementation plan
│
├── host/                             # Host system files
│   ├── packages.txt                  # DNF packages for host
│   ├── bin/
│   │   ├── cage-gnome-launcher.sh
│   │   └── gnome-session.sh
│   └── wayland-sessions/
│       └── distrobox-gnome.desktop   # Login manager entry
│
├── containers/
│   └── gnome/                        # GNOME container config
│       ├── Containerfile             # Container image definition
│       ├── create.sh                 # Distrobox creation script
│       └── start-gnome.sh            # GNOME startup script
│
└── docs/
    └── ARCHITECTURE.md               # Technical documentation
```

## How It Works

1. **Host boots** → Minimal Fedora with no DE installed
2. **User logs in** → Login manager launches `cage-gnome-launcher.sh`
3. **Cage starts** → Minimal Wayland compositor provides display server
4. **Distrobox enters container** → Runs `gnome-box` container
5. **GNOME Shell launches** → Full desktop inside container
6. **GPU/Audio shared** → `/dev/dri`, PipeWire sockets bind-mounted

## Security Notice

⚠️ This setup uses `--security-opt label=disable` to disable SELinux confinement for the container. This is required for Wayland socket sharing but reduces isolation. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for details.

## Adding More Desktops

Want KDE Plasma or a SteamOS-style gaming session? Create a new container:

```bash
cp -r containers/gnome containers/plasma
# Edit Containerfile, create.sh, start script
# Add launcher scripts and .desktop file
```

See [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) for expansion roadmap.

## Troubleshooting

**Container won't start:**
```bash
# Check if container exists
distrobox list

# View logs
journalctl -xe | grep distrobox
```

**GPU not working:**
```bash
# Inside container, verify GPU access
ls -la /dev/dri
glxinfo | grep renderer
```

**Audio issues:**
```bash
# Check PipeWire socket sharing
echo $XDG_RUNTIME_DIR
pactl info
```

## References

- [GitHub Issue #3](https://github.com/atzufuki/dotfiles/issues/3) - Original proposal
- [Distrobox Documentation](https://distrobox.it/)
- [Cage Wayland Compositor](https://github.com/cage-kiosk/cage)
- [Running GNOME/KDE on Distrobox](https://distrobox.it/posts/run_latest_gnome_kde_on_distrobox/)

## License

MIT - See LICENSE file for details
