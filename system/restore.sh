#!/usr/bin/env bash
# Restore the system-level config that lives outside $HOME.
# Run AFTER install.sh, on a fresh machine. Not managed by stow: these paths
# need root, and stow only links into $HOME.
#
# WARNING: this overwrites files in /etc. Read `etc/` first if unsure.
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

read -rp "Overwrite /etc files from this repo? [y/N] " ans
[[ "$ans" == [yY]* ]] || { echo "Aborted."; exit 1; }

echo ":: Copying /etc files"
sudo cp -av "$src/etc/." /etc/

echo ":: Enabling system services"
sudo systemctl enable greetd.service NetworkManager.service fstrim.timer

echo ":: Enabling user services"
systemctl --user enable pipewire.service pipewire-pulse.service wireplumber.service

echo ":: Rebuilding the UKI (mkinitcpio.conf and linux.preset just changed)"
sudo mkinitcpio -P

echo ":: Done. Reboot."
