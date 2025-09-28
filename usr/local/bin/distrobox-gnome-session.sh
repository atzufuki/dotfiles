#!/usr/bin/env bash
/usr/bin/distrobox-enter -n fedora-gnome --additional-flags "--env XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR --env WAYLAND_DISPLAY=$WAYLAND_DISPLAY" -- /usr/bin/gnome-session > /home/atzufuki/gnome-session.log 2>&1
