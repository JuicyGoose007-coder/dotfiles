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

mapfile -t pkgs < "$src/pkglist.txt"

# Add microcode and GPU drivers for the hardware in this machine.
found=("cpu:$(awk -F': ' '/^vendor_id/{print $2; exit}' /proc/cpuinfo)")
for d in /sys/bus/pci/devices/*; do
  [[ "$(<"$d/class")" == 0x03* ]] && found+=("gpu:$(<"$d/vendor")")   # 0x03 = display
done
while read -r -a row; do
  match="${row[0]:-}" extra=("${row[@]:1}")
  [[ -z "$match" || "$match" == \#* ]] && continue
  for f in "${found[@]}"; do
    [[ "$f" == "$match" ]] && { echo ":: Found $match, adding ${extra[*]}"; pkgs+=("${extra[@]}"); break; }
  done
done < "$src/hardware.txt"

echo ":: Installing ${#pkgs[@]} packages"
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
