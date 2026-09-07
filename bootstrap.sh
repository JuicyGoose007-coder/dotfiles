#!/usr/bin/env bash
# Set up a fresh Arch machine from this repo.
#   1. install every package this system had
#   2. install stow
#   3. symlink every package into $HOME
#   4. make zsh the login shell
#
# Assumes a working base Arch install with sudo and a network connection.
# Does NOT touch /etc -- run system/restore.sh for that.
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ":: Installing packages"
"$src/config/.config/scripts/packages/install.sh"

echo ":: Installing stow"
sudo pacman -S --needed --noconfirm stow

echo ":: Linking configs into \$HOME"
stow --dir="$src" --target="$HOME" --restow config shell homescripts

# zsh is in pkglist, so it is installed by now. chsh prompts for your password.
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
