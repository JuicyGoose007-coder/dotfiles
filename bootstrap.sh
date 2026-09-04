#!/usr/bin/env bash
# Set up a fresh Arch machine from this repo.
#   1. install every package this system had
#   2. install stow
#   3. symlink every package into $HOME
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ":: Installing packages"
"$src/config/.config/scripts/packages/install.sh"

echo ":: Installing stow"
sudo pacman -S --needed --noconfirm stow

echo ":: Linking configs into \$HOME"
stow --dir="$src" --target="$HOME" --restow config shell homescripts

echo ":: Done. Log out and back in."
