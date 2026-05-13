# Managed by dotfiles. Extends the distro default bashrc.

if [ -f /usr/etc/skel/.bashrc ]; then
    . /usr/etc/skel/.bashrc
elif [ -f /etc/skel/.bashrc ]; then
    . /etc/skel/.bashrc
fi
