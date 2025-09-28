#!/bin/bash

# xhost +SI:localuser:$USER # We are using Wayland

/usr/bin/distrobox-enter -T -n fedora-gnome -- /usr/bin/gnome-session
