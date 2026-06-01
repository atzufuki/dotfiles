# Managed by dotfiles. Extends the distro default bash_profile.

if [ -f /usr/etc/skel/.bash_profile ]; then
    . /usr/etc/skel/.bash_profile
elif [ -f /etc/skel/.bash_profile ]; then
    . /etc/skel/.bash_profile
fi

export PATH="/home/atzufuki/.local/bin:$PATH"
