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

# Add microcode, GPU drivers and boot tooling for this machine.
found=("cpu:$(awk -F': ' '/^vendor_id/{print $2; exit}' /proc/cpuinfo)")
for d in /sys/bus/pci/devices/*; do
  [[ "$(<"$d/class")" == 0x03* ]] && found+=("gpu:$(<"$d/vendor")")   # 0x03 = display
done
# Choosing Limine in the Arch install is what installs the limine package.
pacman -Q limine >/dev/null 2>&1 && found+=("boot:limine")
found+=("fs:$(findmnt -no FSTYPE /)")

has() { local f; for f in "${found[@]}"; do [[ "$f" == "$1" ]] && return 0; done; return 1; }
while read -r -a row; do
  match="${row[0]:-}" extra=("${row[@]:1}")
  [[ -z "$match" || "$match" == \#* ]] && continue
  IFS=+ read -r -a need <<< "$match"   # a+b: needs both
  ok=1
  for n in "${need[@]}"; do has "$n" || ok=0; done
  if ((ok)); then
    echo ":: Found $match, adding ${extra[*]}"
    pkgs+=("${extra[@]}")
  fi
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
