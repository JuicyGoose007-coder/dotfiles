#!/usr/bin/env bash
# Refresh pkglist.txt from what is installed right now.
# The committed list is hand-trimmed; a raw snapshot adds the junk back
# (unused Nerd Fonts, *-debug packages). Review the diff afterwards.
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

read -rp "This overwrites the trimmed list with a full snapshot. Continue? [y/N] " ans
[[ "$ans" == [yY]* ]] || { echo "Aborted."; exit 1; }

pacman -Qqe > "$src/pkglist.txt"   # every explicitly installed package, repo + AUR
echo "packages: $(wc -l < "$src/pkglist.txt")"
echo "Review with: git -C ~/dotfiles diff"
