#!/usr/bin/env bash
# Reinstall every package this system had, on a fresh Arch install.
# Regenerate the list with ./update-lists.sh
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ":: Bootstrapping"
sudo pacman -Sy --needed --noconfirm base-devel git

if ! command -v yay >/dev/null 2>&1; then
  echo ":: Building yay"
  tmp="$(mktemp -d)"
  git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
  (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$tmp"
fi

echo ":: Installing $(wc -l < "$src/pkglist.txt") packages"
mapfile -t pkgs < "$src/pkglist.txt"
yay -Syu --needed --noconfirm "${pkgs[@]}"

echo ":: Done."
