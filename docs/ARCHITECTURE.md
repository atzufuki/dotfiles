# Architecture Documentation

## Overview

This project implements a **container-based desktop environment** architecture where the host system remains minimal and pristine while complete desktop environments run inside Podman containers managed by Distrobox.

## System Architecture

### High-Level Design

```
┌─────────────────────────────────────────────────────┐
│                  Fedora Host OS                      │
│                    (Minimal)                         │
│                                                      │
│  ┌────────────────────────────────────────────┐    │
│  │         Display Manager (GDM/SDDM)          │    │
│  └─────────────────┬───────────────────────────┘    │
│                    │                                 │
│                    ▼                                 │
│  ┌────────────────────────────────────────────┐    │
│  │  weston-gnome-launcher.sh               │    │
│  │  (Session Entry Point)                     │    │
│  └─────────────────┬───────────────────────────┘    │
│                    │                                 │
│                    ▼                                 │
│  ┌────────────────────────────────────────────┐    │
│  │         Cage Compositor                │    │
│  │      (Wayland Display Server)               │    │
│  └─────────────────┬───────────────────────────┘    │
│                    │                                 │
│                    ▼                                 │
│  ┌────────────────────────────────────────────┐    │
│  │       gnome-session.sh                      │    │
│  │  (Container Session Launcher)               │    │
│  └─────────────────┬───────────────────────────┘    │
│                    │                                 │
│                    │ distrobox enter gnome-box       │
│                    │                                 │
│  ┌────────────────▼───────────────────────────┐    │
│  │                                              │    │
│  │  ╔══════════════════════════════════════╗  │    │
│  │  ║   Podman Container: gnome-box        ║  │    │
│  │  ║                                       ║  │    │
│  │  ║  ┌────────────────────────────────┐  ║  │    │
│  │  ║  │  start-gnome.sh                 │  ║  │    │
│  │  ║  │  (GNOME Startup)                │  ║  │    │
│  │  ║  └──────────┬──────────────────────┘  ║  │    │
│  │  ║             │                          ║  │    │
│  │  ║             ▼                          ║  │    │
│  │  ║  ┌────────────────────────────────┐  ║  │    │
│  │  ║  │    GNOME Shell                  │  ║  │    │
│  │  ║  │  (Desktop Environment)          │  ║  │    │
│  │  ║  │                                  │  ║  │    │
│  │  ║  │  - GNOME Session                │  ║  │    │
│  │  ║  │  - Applications                 │  ║  │    │
│  │  ║  │  - Settings                     │  ║  │    │
│  │  ║  └────────────────────────────────┘  ║  │    │
│  │  ║                                       ║  │    │
│  │  ║  Shared Resources:                   ║  │    │
│  │  ║  • /dev/dri (GPU)                    ║  │    │
│  │  ║  • /dev/snd (Audio)                  ║  │    │
│  │  ║  • $XDG_RUNTIME_DIR (Wayland/Audio)  ║  │    │
│  │  ╚══════════════════════════════════════╝  │    │
│  │                                              │    │
│  └──────────────────────────────────────────────┘    │
│                                                      │
└─────────────────────────────────────────────────────┘
```

## Component Details

### 1. Host System

**Purpose:** Provide minimal runtime environment for containers

**Key Packages:**
- `podman` - OCI container runtime
- `distrobox` - User-friendly container management
- `weston` - Micro-compositor for nested sessions
- `pipewire` + `wireplumber` - Audio system
- `mesa-dri-drivers` - GPU drivers
- `xorg-x11-server-Xwayland` - X11 compatibility

**Responsibilities:**
- Boot process
- Hardware management
- Container orchestration
- Display server hosting (weston)

### 2. Cage Compositor

**Purpose:** Provide Wayland display server for containerized desktop

**Why Cage?**
- Lightweight micro-compositor
- Designed for nested/containerized sessions
- Excellent gaming performance (bonus)
- Supports adaptive sync, HDR (future)

**Configuration:**
```bash
weston \
  --prefer-vk-device /dev/dri/renderD128 \
  --adaptive-sync \
  --rt \
  -- /usr/local/bin/gnome-session.sh
```

### 3. Distrobox Container

**Image:** Custom Fedora 43 with GNOME

**Creation Flags:**
```bash
distrobox create -n gnome-box -i fedora-gnome:43 \
  --additional-flags "
    --ipc=host                           # Shared IPC namespace
    --security-opt label=disable         # Disable SELinux confinement
    --device /dev/dri                    # GPU access
    --device /dev/snd                    # Audio device access
    --volume=$XDG_RUNTIME_DIR:$XDG_RUNTIME_DIR  # Wayland/PipeWire sockets
    --env XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR
    --env WAYLAND_DISPLAY=$WAYLAND_DISPLAY
  "
```

**Critical Bindings:**
- `/dev/dri` → GPU acceleration (OpenGL, Vulkan)
- `/dev/snd` → Direct audio device access
- `$XDG_RUNTIME_DIR` → Wayland socket, PipeWire sockets
- `--ipc=host` → Shared memory for graphics performance

### 4. Desktop Environment (GNOME)

**Running inside container as:**
```bash
dbus-run-session -- gnome-shell --display-server
```

**Environment Variables:**
```bash
XDG_SESSION_TYPE=wayland
XDG_CURRENT_DESKTOP=GNOME
```

## Resource Sharing

### Graphics (GPU)

**Host → Container:**
```
/dev/dri/card0       → GPU device
/dev/dri/renderD128  → Render node
```

**How it works:**
1. Host mesa drivers load kernel DRM modules
2. Container has mesa-dri-drivers installed
3. `/dev/dri` bind-mount gives direct access
4. Applications use OpenGL/Vulkan normally

**Verification:**
```bash
# Inside container
glxinfo | grep "OpenGL renderer"
vulkaninfo | grep "deviceName"
```

### Audio (PipeWire)

**Host → Container:**
```
$XDG_RUNTIME_DIR/pipewire-0       → PipeWire socket
$XDG_RUNTIME_DIR/pulse/native     → PulseAudio compat
```

**How it works:**
1. Host runs PipeWire daemon
2. Sockets created in `$XDG_RUNTIME_DIR`
3. Container shares this directory
4. Container apps connect to host PipeWire

**Verification:**
```bash
# Inside container
pactl info
pw-cli info all
```

### Wayland Display

**Host → Container:**
```
$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY  → Wayland socket
```

**How it works:**
1. Cage creates Wayland socket (e.g., `wayland-0`)
2. `$WAYLAND_DISPLAY` env var points to socket
3. Container shares `$XDG_RUNTIME_DIR`
4. GNOME Shell connects as Wayland client

## Security Considerations

### SELinux Disabled (`--security-opt label=disable`)

**Why needed:**
- SELinux prevents container access to host Wayland sockets by default
- Label mismatch between host socket and container process
- Alternative would require custom SELinux policy

**Risks:**
- Container process runs unconfined
- Could access more host resources than intended
- Root in container = potential host compromise

**Mitigations:**
- Don't run untrusted code in desktop containers
- Use for personal workstations, not servers
- Consider user namespaces (future improvement)

### IPC Namespace Sharing (`--ipc=host`)

**Why needed:**
- Shared memory for X11/Wayland graphics performance
- Without it, graphics would be slow (copying instead of sharing)

**Risks:**
- Container can access host IPC objects
- Potential information leak between containers

**Acceptable because:**
- Desktop use case prioritizes performance
- User already has access to display

## File System Layout

### Host System
```
/usr/local/bin/
├── weston-gnome-launcher.sh    # Entry point from login manager
└── gnome-session.sh                # Distrobox launcher

/usr/share/wayland-sessions/
└── distrobox-gnome.desktop         # Login manager session entry
```

### Container (gnome-box)
```
~/.local/bin/
└── start-gnome.sh                  # GNOME startup script

~/.config/
└── (GNOME user configuration)      # Persistent across container rebuilds
```

## Session Flow

### Login Process

1. **User selects "GNOME (Distrobox)" at login screen**
   - Display manager reads `/usr/share/wayland-sessions/distrobox-gnome.desktop`
   - Executes: `/usr/local/bin/weston-gnome-launcher.sh`

2. **Cage launcher starts compositor**
   ```bash
   exec weston -- /usr/local/bin/gnome-session.sh
   ```
   - Cage creates Wayland display server
   - Forks child process for session script

3. **Session launcher enters container**
   ```bash
   exec distrobox enter gnome-box -- ~/.local/bin/start-gnome.sh
   ```
   - Distrobox sets up namespace bindings
   - Executes script inside container

4. **GNOME starts inside container**
   ```bash
   exec dbus-run-session -- gnome-shell --display-server
   ```
   - D-Bus session bus started
   - GNOME Shell connects to Wayland socket
   - Desktop environment fully running

### Logout Process

1. User logs out from GNOME
2. `gnome-shell` process exits
3. Container process terminates
4. Cage compositor exits
5. Display manager shows login screen

Container persists (not destroyed), ready for next login.

## Performance Characteristics

### Overhead
- **CPU:** Negligible (no emulation, native syscalls)
- **Memory:** ~100MB for container runtime (shared libraries deduped)
- **GPU:** Native performance (direct device access)
- **Audio:** Native performance (direct PipeWire connection)

### Benefits over VM
- No hypervisor overhead
- Shared kernel (faster syscalls)
- Direct hardware access
- Instant startup (no boot time)

## Expansion: Multiple Desktop Environments

### Adding KDE Plasma

1. Create `containers/plasma/Containerfile`
2. Create `containers/plasma/create.sh` (similar bindings)
3. Create `containers/plasma/start-plasma.sh`
4. Create `host/bin/plasma-session.sh`
5. Create `host/wayland-sessions/distrobox-plasma.desktop`

### Switching Between Desktops

At login screen, select:
- GNOME (Distrobox)
- Plasma (Distrobox)
- SteamOS Gaming Session (future)

Each runs in separate container, zero interference.

## Troubleshooting

### Container won't start

**Check container exists:**
```bash
distrobox list
```

**Recreate container:**
```bash
distrobox rm gnome-box
bash containers/gnome/create.sh
```

### GPU not working

**Verify device access:**
```bash
ls -la /dev/dri
# Should show card0, renderD128, etc.
```

**Check mesa drivers:**
```bash
# Inside container
glxinfo | grep "OpenGL renderer"
```

**Common issue:** Missing mesa-dri-drivers in container

### Audio not working

**Check PipeWire running on host:**
```bash
systemctl --user status pipewire
```

**Verify socket exists:**
```bash
ls -la $XDG_RUNTIME_DIR/pipewire-*
```

**Inside container:**
```bash
pactl info
# Should connect to host PipeWire
```

### Wayland socket issues

**Check socket path:**
```bash
echo $XDG_RUNTIME_DIR
echo $WAYLAND_DISPLAY
ls -la $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY
```

**Ensure directory is bind-mounted:**
```bash
# Inside container
mount | grep $XDG_RUNTIME_DIR
```

## Future Improvements

### 1. User Namespaces
- Map container root to unprivileged host user
- Improve security without label=disable
- Requires kernel support for device access in user-ns

### 2. Custom SELinux Policy
- Replace label=disable with targeted policy
- Allow only necessary socket access
- Better isolation

### 3. Container Templates
- `distrobox create --desktop-session gnome`
- Automatic binding configuration
- Pre-built images

### 4. Session Management
- Switch containers without logout
- Multiple simultaneous desktops (different TTYs)
- Container suspend/resume

## References

- [Distrobox Documentation](https://distrobox.it/)
- [Podman Container Security](https://docs.podman.io/en/latest/markdown/podman-run.1.html#security-opt-option)
- [Wayland Architecture](https://wayland.freedesktop.org/architecture.html)
- [PipeWire Wiki](https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/home)
- [Mesa DRI](https://www.mesa3d.org/)
