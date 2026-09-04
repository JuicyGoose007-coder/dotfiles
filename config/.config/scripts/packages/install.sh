#!/usr/bin/env bash
# Reinstall every package this system had, on a fresh Arch install.
# Regenerate the lists with ./update-lists.sh
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ":: Syncing package databases"
sudo pacman -Syu --noconfirm

echo ":: Installing $(wc -l < "$src/pkglist-native.txt") packages from the official repos"
sudo pacman -S --needed --noconfirm - < "$src/pkglist-native.txt"

if ! command -v yay >/dev/null 2>&1; then
  echo ":: Bootstrapping yay (no AUR helper found)"
  sudo pacman -S --needed --noconfirm base-devel git
  tmp="$(mktemp -d)"
  git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
  (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$tmp"
fi

echo ":: Installing $(wc -l < "$src/pkglist-aur.txt") packages from the AUR"
mapfile -t aur < "$src/pkglist-aur.txt"
yay -S --needed --noconfirm "${aur[@]}"

echo ":: Done."
