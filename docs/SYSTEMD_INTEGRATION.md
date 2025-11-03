# Systemd Integration Issue

## Problem Summary

GDM session returns to login screen after 30-60 seconds when launching containerized GNOME desktop. The session works perfectly when launched from TTY (Ctrl+Alt+F3), but fails consistently when launched through GDM.

## Root Cause Analysis

Based on extensive testing and log analysis, the issue has two interconnected problems:

### 1. GDM Session Lifecycle Tracking

GDM expects the session launcher process to remain running for the entire duration of the user session. When the launcher process exits, GDM interprets this as the session ending and returns to the login screen.

**Current behavior:**
- `weston-gnome-launcher.sh` starts Weston and `gnome-session.sh`
- `gnome-session.sh` uses `distrobox enter` to run `start-gnome.sh` in container
- `start-gnome.sh` launches `gnome-session`
- `gnome-session` fails to initialize properly due to missing systemd user session
- Process chain exits prematurely
- GDM detects launcher process termination and returns to login

**Why it works in TTY:**
When launching from TTY, there is no display manager monitoring the process lifecycle. The user remains logged in regardless of which processes are running.

### 2. GNOME Session Requires Systemd

GNOME session (`gnome-session`) is designed to integrate deeply with systemd user sessions. Without systemd as PID 1 in the container, we see this error:

```
Trying to run as user instance, but the system has not been booted with systemd.
```

Log evidence from `start-gnome-20251103-002909.log`:
```
** Message: 00:29:09.531: Starting GNOME session target: gnome-session-wayland@gnome.target
```

The session attempts to start systemd units but fails because:
- Container created without `--init` flag → no systemd as PID 1
- Manual `systemd --user` start fails → systemd user session requires systemd system session
- `gnome-session` cannot activate its systemd targets
- Session initialization fails silently
- Process exits, triggering GDM logout

## Why Previous Solutions Failed

### Attempt 1: `exec gnome-session`
**Problem:** `exec` replaces the shell process, but `gnome-session` itself exits immediately due to systemd dependency.

### Attempt 2: Background `gnome-session` with keepalive loop
**Problem:** Still doesn't solve the fact that `gnome-session` exits prematurely. The loop detects the exit and the script ends, closing the session.

### Attempt 3: Creating container without `--init`
**Problem:** No systemd means GNOME session cannot initialize properly.

### Attempt 4: Creating container with `--init`
**Status:** Ready to test. GDM should wait for the init process to complete (timeout is usually 90+ seconds).

## Proposed Solution: Container with --init

### Strategy

Use Distrobox `--init` flag to provide systemd as PID 1. GDM has sufficient timeout to wait for container systemd initialization (typically 90 seconds or more), so the 30-60 second boot delay should not cause issues. This needs to be tested to identify if there are other problems beyond the init delay.

### Implementation Plan

#### 1. Modify Container Creation

Update `containers/gnome/create.sh` to use `--init`:

```bash
distrobox create \
    --name "$CONTAINER_NAME" \
    --image "$IMAGE_NAME" \
    --init \
    --additional-flags "\
        --ipc=host \
        --security-opt label=disable \
        --privileged \
        --device /dev/dri \
        --device /dev/snd \
        --env XDG_RUNTIME_DIR=\$XDG_RUNTIME_DIR \
        $EXTRA_ENV"
```

**Testing hypothesis:** GDM will wait for the init process to complete. If session still fails after successful systemd initialization, logs will reveal the actual failure point.

#### 2. Update start-gnome.sh

With systemd available, simplify the startup script:

```bash
#!/bin/bash
# Start GNOME desktop environment inside Distrobox container
# Assumes systemd is running (container created with --init)

# Enable logging
LOG_DIR="$HOME/dotfiles/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/start-gnome-$(date +%Y%m%d-%H%M%S).log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo "=== GNOME Session start at $(date) ==="

# Set up Wayland session environment
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=GNOME
export XDG_SESSION_CLASS=user
export XDG_SESSION_DESKTOP=gnome
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus

# Ensure XDG_RUNTIME_DIR is set
if [ -z "$XDG_RUNTIME_DIR" ]; then
    echo "ERROR: XDG_RUNTIME_DIR is not set"
    exit 1
fi

# Wait for Wayland display to be available
echo "Waiting for Wayland display..."
timeout=30
while [ -z "$WAYLAND_DISPLAY" ] && [ $timeout -gt 0 ]; do
    if ls "$XDG_RUNTIME_DIR"/wayland-* &>/dev/null; then
        export WAYLAND_DISPLAY=$(basename "$XDG_RUNTIME_DIR"/wayland-* | head -n1 | cut -d- -f2)
        echo "Found Wayland display: $WAYLAND_DISPLAY"
        break
    fi
    sleep 0.5
    timeout=$((timeout - 1))
done

if [ -z "$WAYLAND_DISPLAY" ]; then
    echo "ERROR: No Wayland display found after 15 seconds"
    exit 1
fi

echo "Container environment ready:"
echo "  WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
echo "  XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
echo ""

# Systemd is already running (container created with --init)
# Verify systemd user session is ready
echo "Verifying systemd user session..."
if ! systemctl --user is-system-running &>/dev/null; then
    echo "WARNING: Systemd user session not ready, waiting..."
    systemctl --user is-system-running --wait || true
fi

echo "Starting GNOME Session..."
echo "Logs saved to: $LOG_FILE"

# Start GNOME Session via systemd target
# This is the proper way to start GNOME with systemd integration
exec systemctl --user start gnome-session-wayland@gnome.target
```

#### 4. Alternative: Use gnome-session directly with exec

If systemd target approach has issues:

```bash
# Start GNOME Session
# With systemd available, gnome-session will properly initialize
exec gnome-session --session=gnome --systemd
```

The `--systemd` flag tells gnome-session to use systemd activation.

### Testing with --init

#### Steps to Test

1. **Recreate container with --init:**
   ```bash
   distrobox rm gnome-box -f
   cd ~/dotfiles/containers/gnome
   bash create.sh  # Now with --init flag
   ```

2. **Copy updated start-gnome.sh:**
   ```bash
   distrobox enter gnome-box -- mkdir -p ~/.local/bin
   distrobox enter gnome-box -- cp ~/dotfiles/containers/gnome/start-gnome.sh ~/.local/bin/
   distrobox enter gnome-box -- chmod +x ~/.local/bin/start-gnome.sh
   ```

3. **Test from GDM:**
   - Reboot or restart GDM: `sudo systemctl restart gdm`
   - Login via GDM with "Distrobox GNOME" session
   - **Observe:** 30-60 second delay during "Firing up init system"
   - **Expected:** GDM waits, then GNOME starts successfully
   - **If fails:** Check new logs to see what happens AFTER systemd is ready

4. **Collect detailed logs:**
   ```bash
   # GDM session logs
   journalctl -u gdm -b --no-pager > ~/gdm-init-test.log
   
   # Container systemd status
   distrobox enter gnome-box -- systemctl --user status > ~/container-systemd.log
   distrobox enter gnome-box -- journalctl --user --no-pager > ~/container-journal.log
   
   # GNOME session logs
   ls -lt ~/dotfiles/logs/
   cat ~/dotfiles/logs/start-gnome-*.log
   cat ~/dotfiles/logs/weston-gnome-launcher-*.log
   ```

### Expected Behavior (with --init)

1. **User login via GDM:**
   - User selects "Distrobox GNOME" session and enters password
   - `weston-gnome-launcher.sh` starts Weston
   - `gnome-session.sh` enters container
   - **First-time/cold boot:** Container systemd initialization (30-60s delay, GDM waits)
   - **Subsequent logins:** Container already initialized (fast, <5s)
   - `start-gnome.sh` runs
   - Systemd is already operational
   - `gnome-session` starts successfully with systemd integration
   - GNOME desktop appears
   - Session remains active as long as user is logged in

2. **User logout:**
   - User clicks logout
   - `gnome-session` exits cleanly
   - `start-gnome.sh` exits
   - `gnome-session.sh` exits  
   - `weston-gnome-launcher.sh` exits
   - GDM detects launcher exit (expected behavior)
   - Returns to login screen

### Advantages

- ✅ Proper systemd integration
- ✅ GNOME session works as designed
- ✅ Clean logout behavior
- ✅ Simple implementation (just add --init flag)
- ✅ No additional services or complexity

### Disadvantages

- ⚠️ First login after container creation: 30-60s delay
- ⚠️ First login after system reboot: 30-60s delay (if container was stopped)
- ✅ Subsequent logins: Fast (<5s) - container remains running

### Unknown (Needs Testing)

- ❓ Does GDM successfully wait for the full init process?
- ❓ Does gnome-session work properly once systemd is ready?
- ❓ Are there other issues beyond systemd that cause session termination?
- ❓ Does the session remain stable after the initial delay?

## Alternative Approaches Considered

### A. Use Alternative Desktop Environment

**Option:** Switch from GNOME to a desktop environment that doesn't require systemd:
- KDE Plasma (also uses systemd nowadays)
- XFCE (lighter, less systemd dependency)
- i3/Sway (window manager, no systemd needed)

**Verdict:** Defeats the purpose of this project which aims for full GNOME containerization.

### B. Run GNOME Shell Directly

**Option:** Skip `gnome-session` and run `gnome-shell --wayland --display-server` directly.

**Problem:** GNOME Shell also expects systemd integration for many features (notifications, settings daemon, etc.)

### C. Custom Session Manager

**Option:** Write a lightweight session manager that wraps GNOME components without systemd dependency.

**Verdict:** Extremely complex, would need to reimplement much of what gnome-session does.

### D. Keep Session Alive with Dummy Process

**Option:** Create a long-running dummy process that GDM tracks, while GNOME runs independently.

**Problem:** Doesn't solve the core issue that GNOME itself needs systemd. Session would appear to work but have missing functionality.

## Testing Plan

Test with --init flag to determine actual failure point:

1. **Initial test with --init:**
   - Create container with --init flag
   - Attempt GDM login
   - Accept the 30-60s delay during systemd initialization
   - **Goal:** Determine if session works AFTER systemd is ready
   - Document exact point of failure if it still fails

2. **Session stability test (if login succeeds):**
   - Login and leave session idle for 30+ minutes
   - Verify session doesn't auto-logout
   - Expected: Stays logged in indefinitely

3. **Repeated login test:**
   - Logout from GNOME session
   - Login again immediately (container still running)
   - Expected: Fast login (<5s) without init delay

4. **TTY comparison:**
   - Login via TTY (Ctrl+Alt+F3)
   - Login via GDM
   - Verify both work identically
   - Expected: Same functionality both ways

5. **Log analysis (if it fails):**
   - Collect GDM, systemd, and GNOME session logs
   - Identify exact failure point AFTER systemd initialization
   - Determine if failure is:
     - Session timeout/tracking issue
     - GNOME component failure
     - D-Bus/IPC issue
     - Permission/capability issue
     - Other systemd integration problem

## Monitoring and Debugging

### Check Container Systemd Status

```bash
distrobox enter gnome-box -- systemctl --user status
distrobox enter gnome-box -- systemctl --user list-units --state=failed
distrobox enter gnome-box -- systemctl is-system-running
```

### Check GNOME Session Status

```bash
distrobox enter gnome-box -- systemctl --user status gnome-session-wayland@gnome.target
distrobox enter gnome-box -- journalctl --user -u gnome-session-wayland@gnome.target
```

### GDM Logs

```bash
journalctl -u gdm -b
loginctl list-sessions
loginctl show-session <session-id>
```

### Check Init Process in Container

```bash
distrobox enter gnome-box -- ps aux | grep systemd
distrobox enter gnome-box -- systemctl status
```

### Detailed Session Logs

```bash
# All logs from latest login attempt
ls -lt ~/dotfiles/logs/
tail -100 ~/dotfiles/logs/start-gnome-*.log
tail -100 ~/dotfiles/logs/weston-gnome-launcher-*.log
```

## References

- GNOME Session systemd integration: https://wiki.gnome.org/Projects/SessionManagement/SystemdIntegration
- Distrobox init flag: https://distrobox.it/usage/distrobox-create/#init
- GDM session management: https://help.gnome.org/admin/gdm/stable/configuration.html.en

## Next Steps

1. ✅ Update create.sh to use --init flag
2. ✅ Update start-gnome.sh for systemd integration
3. ⏳ **TEST:** Create container and attempt GDM login
4. ⏳ **ANALYZE:** Collect logs from test to determine actual failure point
5. ⏳ **DOCUMENT:** Update this issue with findings
6. ⏳ **ITERATE:** Address specific issues found in testing

## Current Status

**Phase:** Ready for testing with --init flag  
**Hypothesis:** GDM timeout is sufficient for systemd init; failure may be due to other issues  
**Action Required:** Test and collect detailed logs to identify actual problem
