#!/usr/bin/env bash
# Refresh pkglist.txt from what is installed right now.
# The committed list is hand-trimmed; a raw snapshot adds the junk back
# (unused Nerd Fonts, *-debug packages). Review the diff afterwards.
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

read -rp "This overwrites the trimmed list with a full snapshot. Continue? [y/N] " ans
[[ "$ans" == [yY]* ]] || { echo "Aborted."; exit 1; }

# Every explicitly installed package, repo + AUR, minus the hardware.txt ones.
pacman -Qqe | grep -vxF -f <(awk '!/^#/{for (i = 2; i <= NF; i++) print $i}' "$src/hardware.txt") \
  > "$src/pkglist.txt"
echo "packages: $(wc -l < "$src/pkglist.txt")"
echo "Review with: git -C ~/dotfiles diff"
