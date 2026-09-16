#!/usr/bin/env bash
# Reinstall every package this system had, on a fresh Arch install.
# Regenerate the list with ./update-lists.sh
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ":: Bootstrapping"
sudo pacman -Sy --needed --noconfirm base-devel git

# Source build, not paru-bin: the prebuilt binary breaks on libalpm soname bumps.
if ! command -v paru >/dev/null 2>&1; then
  echo ":: Building paru"
  tmp="$(mktemp -d)"
  git clone --depth=1 https://aur.archlinux.org/paru.git "$tmp/paru"
  (cd "$tmp/paru" && makepkg -si --noconfirm)
  rm -rf "$tmp"
fi

echo ":: Installing $(wc -l < "$src/pkglist.txt") packages"
mapfile -t pkgs < "$src/pkglist.txt"
paru -Syu --needed --noconfirm "${pkgs[@]}"

# Apply pins.txt. The pass above installs the newest build, so this rolls the
# pinned packages back to the version that works.
while read -r name ver; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  [[ "$(pacman -Q "$name" 2>/dev/null | awk '{print $2}')" == "$ver" ]] && continue
  echo ":: Pinning $name to $ver"
  url="https://archive.archlinux.org/packages/${name:0:1}/$name/$name-$ver"
  sudo pacman -U --noconfirm "$url-x86_64.pkg.tar.zst" \
    || sudo pacman -U --noconfirm "$url-any.pkg.tar.zst"
done < "$src/pins.txt"

echo ":: Done."
