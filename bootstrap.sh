#!/usr/bin/env bash
# Set up a fresh Arch machine: packages, stow symlinks, login shell.
# Assumes a base Arch install with sudo and network.
# Does NOT touch /etc -- run system/restore.sh for that.
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ":: Installing packages"
"$src/scripts/packages/install.sh"

echo ":: Installing stow"
sudo pacman -S --needed --noconfirm stow

echo ":: Linking configs into \$HOME"
stow --dir="$src" --target="$HOME" --restow config shell homescripts homepictures

if [[ "$SHELL" != *zsh ]]; then
  echo ":: Making zsh the login shell"
  chsh -s /usr/bin/zsh
else
  echo ":: Login shell is already zsh"
fi

cat <<EOF

:: Packages, configs and shell are done. One step left:

   System config (/etc, services, UKI) -- needs root, review first:
     $src/system/restore.sh

   Then reboot.
EOF
