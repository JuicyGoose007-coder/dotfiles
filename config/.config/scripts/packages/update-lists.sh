#!/usr/bin/env bash
# Refresh the package lists from what is installed right now.
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pacman -Qqen > "$src/pkglist-native.txt"   # explicit, from official repos
pacman -Qqem > "$src/pkglist-aur.txt"      # explicit, from the AUR
echo "native: $(wc -l < "$src/pkglist-native.txt")  aur: $(wc -l < "$src/pkglist-aur.txt")"
