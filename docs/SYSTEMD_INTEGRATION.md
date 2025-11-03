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

### Updated Implementation

Fix start-gnome.sh to use correct gnome-session invocation:

```bash
echo "Starting GNOME Session..."
echo "Logs saved to: $LOG_FILE"

# Try systemd target first (cleanest approach)
if systemctl --user list-unit-files gnome-session-wayland@gnome.target &>/dev/null; then
    echo "Starting via systemd target..."
    exec systemctl --user --wait start gnome-session-wayland@gnome.target
else
    # Fallback: direct gnome-session invocation
    echo "Starting gnome-session directly..."
    exec gnome-session --session=gnome
fi
```

### Next Steps for Debugging

1. **Fix gnome-session invocation** (remove --systemd flag):
   ```bash
   # Test in container directly
   distrobox enter gnome-box
   export WAYLAND_DISPLAY=1
   export XDG_RUNTIME_DIR=/run/user/1000
   gnome-session --session=gnome  # Without --systemd flag
   ```

2. **Investigate failed systemd units**:
   ```bash
   distrobox enter gnome-box -- systemctl --user list-units --state=failed
   distrobox enter gnome-box -- systemctl --user status gnome-session-wayland@gnome.target
   ```

3. **Check why gnome-session-wayland@gnome.target stays inactive**:
   ```bash
   distrobox enter gnome-box -- systemctl --user cat gnome-session-wayland@gnome.target
   distrobox enter gnome-box -- journalctl --user -u gnome-session-wayland@gnome.target
   ```

4. **Investigate PAM/keyring issues**:
   - "gkr-pam: unable to locate daemon control file"
   - May need gnome-keyring-daemon to be running
   - Check if gnome-keyring is installed in container

5. **Test direct gnome-session start** (bypass systemd target):
   - Modify start-gnome.sh to use `exec gnome-session --session=gnome`
   - See if it starts GNOME successfully
   - Check if GDM session registration works

### Known Issues to Address

1. **gnome-session --systemd flag doesn't exist**
   - Solution: Remove the flag, use `gnome-session --session=gnome`
   
2. **GDM session never registers**
   - Possible causes:
     - gnome-session crashes before registration
     - Missing DBus session setup
     - PAM integration broken in container
     - gnome-keyring-daemon not running
   
3. **Container systemd degraded state**
   - Need to identify which 19 units failed
   - May be unrelated to GNOME session (e.g., networking, hardware services)
   
4. **systemd-userwork processes waiting**
   - Might be waiting for D-Bus activation
   - Could indicate service startup deadlock

### Immediate Action Items

**Priority 1:** Fix start-gnome.sh to remove --systemd flag

**Priority 2:** Test direct gnome-session invocation

**Priority 3:** Debug GDM session registration failure

## GNOME Session Requires Systemd

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
**Status:** Tested. Systemd initializes successfully but new issues discovered.

**Test Results (2025-11-03):**
- ✅ Container systemd boots successfully (30-60s delay)
- ✅ Systemd user session reports "OK"
- ❌ `gnome-session --systemd` flag not recognized (Unknown option --systemd)
- ❌ GDM reports "Session never registered, failing"
- ❌ Session returns to login screen after gnome-session crashes

**New Problems Identified:**
1. `gnome-session` in Fedora 43 doesn't accept `--systemd` flag
2. GDM session registration failing: `gkr-pam: unable to locate daemon control file`
3. PAM/GDM integration issues: `pam_gdm: couldn't set environment variable`

## Updated Solution: Fix gnome-session Invocation and GDM Registration

### Strategy

GDM successfully waits for systemd initialization (confirmed by testing). However, two new issues emerged:

1. **gnome-session command line syntax** - The `--systemd` flag doesn't exist in current gnome-session
2. **GDM session registration** - Session fails to register with GDM even when GNOME starts

Focus shifts to proper gnome-session invocation and ensuring GDM session tracking works correctly.

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

**Update:** The `--systemd` flag doesn't exist in gnome-session (Fedora 43). Use without flags:

```bash
# Start GNOME Session
# With systemd available, gnome-session will automatically detect and use it
exec gnome-session --session=gnome
```

Or start via systemd target (preferred method):

```bash
# Start GNOME via systemd target - let systemd manage the session
exec systemctl --user --wait start gnome-session-wayland@gnome.target
```

### Test Results (2025-11-03)

#### What Works ✅

1. **Container systemd initialization**: Containerbootted with --init successfully starts systemd
   ```
   Setting up init system...                 [ OK ]
   Firing up init system...                  [ OK ]
   Container Setup Complete!
   ```

2. **Systemd user session**: Properly initialized and reports OK
   ```
   Verifying systemd user session...
   Systemd user session: OK
   ```

3. **Wayland display detection**: Successfully finds and connects to Weston's Wayland socket
   ```
   Found Wayland display: 1
   ```

#### What Fails ❌

1. **gnome-session --systemd flag**:
   ```
   ** (gnome-session:1484): ERROR **: 07:45:15.350: Unknown option --systemd
   Jäljitys/katkaisupisteansa (core dumped)
   ```
   
   **Root cause**: The `--systemd` flag doesn't exist in current gnome-session version

2. **GDM session registration**:
   ```
   gdm-password: pam_gdm: couldn't set environment variable
   gdm-password: gkr-pam: unable to locate daemon control file
   gdm[950]: Gdm: GdmDisplay: Session never registered, failing
   ```
   
   **Root cause**: gnome-session crashes before it can register with GDM. Also PAM/keyring integration issues.

3. **Session persistence**: After gnome-session crashes, launcher exits and GDM returns to login screen

#### Container Systemd Status

From screenshots:
- `systemctl` shows system state as **degraded**
- `gnome-session-wayland@gnome.target` is **loaded** but **inactive (dead)**
- Multiple `systemd-userwork` processes waiting
- 19 units failed (need to identify which ones)

### Updated Implementation

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
