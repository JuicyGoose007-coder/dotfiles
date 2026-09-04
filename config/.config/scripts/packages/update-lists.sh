#!/usr/bin/env bash
# Refresh pkglist.txt from what is installed right now.
#
# WARNING: the committed list is hand-trimmed (65 unused Nerd Fonts, fish,
# vifm, alacritty, tmux, brave-bin, zen-browser-bin). A raw snapshot adds them
# all back. Review `git -C ~/dotfiles diff` afterwards.
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

read -rp "This overwrites the trimmed list with a full snapshot. Continue? [y/N] " ans
[[ "$ans" == [yY]* ]] || { echo "Aborted."; exit 1; }

pacman -Qqe > "$src/pkglist.txt"   # every explicitly installed package, repo + AUR
echo "packages: $(wc -l < "$src/pkglist.txt")"
echo "Review with: git -C ~/dotfiles diff"
