#!/bin/bash

xhost +si:localuser:$USER
# Only Wayland mounts and flags
/usr/bin/distrobox-enter -T -n fedora-gnome --additional-flags "--env XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR --env WAYLAND_DISPLAY=$WAYLAND_DISPLAY" -- /usr/bin/gnome-session
