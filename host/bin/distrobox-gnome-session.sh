#!/bin/bash
# Hybrid GNOME session: Host handles PAM/systemd, container provides shell/apps
# This allows proper session registration while keeping desktop in container

set -e

CONTAINER_NAME="gnome-box"

# Verify container exists
if ! distrobox list | grep -q "$CONTAINER_NAME"; then
    echo "ERROR: Container $CONTAINER_NAME does not exist" >&2
    exit 1
fi

# Export container shell path for gnome-session to use
# gnome-session will exec this as the window manager
export GNOME_SHELL_SESSION_MODE=user
export DISTROBOX_CONTAINER="$CONTAINER_NAME"

# Create a custom gnome-session that uses containerized gnome-shell
# We'll use a temporary session file
SESSION_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/gnome-session/sessions"
mkdir -p "$SESSION_DIR"

# Create custom session file that points to container's gnome-shell
cat > "$SESSION_DIR/distrobox-gnome.session" <<'EOF'
[GNOME Session]
Name=Distrobox GNOME
RequiredComponents=org.gnome.Shell;org.gnome.SettingsDaemon.A11ySettings;org.gnome.SettingsDaemon.Color;org.gnome.SettingsDaemon.Datetime;org.gnome.SettingsDaemon.Housekeeping;org.gnome.SettingsDaemon.Keyboard;org.gnome.SettingsDaemon.MediaKeys;org.gnome.SettingsDaemon.Power;org.gnome.SettingsDaemon.PrintNotifications;org.gnome.SettingsDaemon.Rfkill;org.gnome.SettingsDaemon.ScreensaverProxy;org.gnome.SettingsDaemon.Sharing;org.gnome.SettingsDaemon.Smartcard;org.gnome.SettingsDaemon.Sound;org.gnome.SettingsDaemon.Wacom;org.gnome.SettingsDaemon.XSettings;
EOF

# Create desktop files that wrap container commands
APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$APPS_DIR"

# Wrapper for gnome-shell from container
cat > "$APPS_DIR/org.gnome.Shell.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=GNOME Shell
Exec=distrobox-enter -n $CONTAINER_NAME -- /usr/bin/gnome-shell
NoDisplay=true
X-GNOME-Autostart-Phase=DisplayServer
X-GNOME-Provides=windowmanager;
X-GNOME-Autostart-Notify=true
EOF

# Run host's gnome-session with our custom session
# This handles PAM registration, systemd user session, etc.
exec /usr/bin/gnome-session --session=distrobox-gnome
