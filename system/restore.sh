#!/usr/bin/env bash
# Restore the system-level config that lives outside $HOME.
# Run AFTER install.sh, on a fresh machine. Not managed by stow: these paths
# need root, and stow only links into $HOME.
#
# WARNING: this overwrites files in /etc. Read `etc/` first if unsure.
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

read -rp "Overwrite /etc files from this repo? [y/N] " ans
[[ "$ans" == [yY]* ]] || { echo "Aborted."; exit 1; }

echo ":: Copying /etc files"
sudo cp -av "$src/etc/." /etc/

# services-enabled.txt is the single source of truth. It is one unit per line,
# with a "# User services" comment marking where the system half ends and the
# --user half begins. Blank lines and comments are skipped.
sys_units=(); user_units=(); target="sys"
while IFS= read -r line; do
  [[ "$line" == *"User services"* ]] && target="user"
  line="${line%%#*}"; line="${line// /}"
  [[ -z "$line" ]] && continue
  if [[ "$target" == "sys" ]]; then sys_units+=("$line"); else user_units+=("$line"); fi
done < "$src/services-enabled.txt"

echo ":: Enabling ${#sys_units[@]} system services"
sudo systemctl enable "${sys_units[@]}"

echo ":: Enabling ${#user_units[@]} user services"
systemctl --user enable "${user_units[@]}"

echo ":: Rebuilding the UKI (mkinitcpio.conf and linux.preset just changed)"
sudo mkinitcpio -P

echo ":: Done. Reboot."
