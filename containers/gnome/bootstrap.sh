#!/usr/bin/env bash

sudo dnf update -y

if ! sudo dnf group list installed | grep -q "workstation-product-environment"; then
    sudo dnf group install workstation-product-environment -y
else
    echo "workstation-product-environment group is already installed."
fi

echo "GNOME container bootstrap complete!"
