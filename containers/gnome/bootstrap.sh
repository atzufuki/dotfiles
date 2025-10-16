#!/usr/bin/env bash

sudo dnf update -y

if ! sudo dnf group list installed | grep -q "workstation-product-environment"; then
    sudo dnf group install workstation-product-environment -y
else
    echo "workstation-product-environment group is already installed."
fi

# Enable systemd user services for session management
echo "[INFO] Enabling systemd user services..."
sudo systemctl enable --global systemd-user-sessions.service 2>/dev/null || true

echo "GNOME container bootstrap complete!"
