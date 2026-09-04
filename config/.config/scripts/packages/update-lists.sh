#!/usr/bin/env bash
# Refresh the package lists from what is installed right now.
#
# WARNING: the committed lists are hand-trimmed (149 -> 80 native, 10 -> 8 AUR:
# 65 unused Nerd Fonts, fish, vifm, alacritty, tmux, brave-bin, zen-browser-bin).
# Running this replaces them with a raw snapshot and undoes that trim.
# Review `git diff` afterwards and re-drop anything you did not mean to add back.
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

read -rp "This overwrites the trimmed lists with a full snapshot. Continue? [y/N] " ans
[[ "$ans" == [yY]* ]] || { echo "Aborted."; exit 1; }

pacman -Qqen > "$src/pkglist-native.txt"   # explicit, from official repos
pacman -Qqem > "$src/pkglist-aur.txt"      # explicit, from the AUR
echo "native: $(wc -l < "$src/pkglist-native.txt")  aur: $(wc -l < "$src/pkglist-aur.txt")"
echo "Review with: git -C ~/dotfiles diff"
