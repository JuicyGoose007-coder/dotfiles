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

# Back up whatever is about to be overwritten. The list comes from the repo's
# own etc/ tree, so it never drifts. On a fresh machine some of these do not
# exist yet -- skip those rather than failing.
backup="$HOME/etc-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
mapfile -t want < <(cd "$src/etc" && find . -type f -printf '%P\n')
have=()
for f in "${want[@]}"; do [[ -e "/etc/$f" ]] && have+=("$f"); done
if ((${#have[@]})); then
  sudo tar czf "$backup" -C /etc "${have[@]}"
  sudo chown "$USER" "$backup"
  echo ":: Backed up ${#have[@]} existing /etc files to $backup"
else
  backup=""
  echo ":: Nothing in /etc to back up yet"
fi

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

# Enable one at a time. A unit that is missing deserves a warning, not an abort
# that leaves /etc holding a new mkinitcpio.conf the boot image never matched.
echo ":: Enabling ${#sys_units[@]} system services"
for u in "${sys_units[@]}"; do
  sudo systemctl enable "$u" || echo "!! could not enable $u (skipped)"
done

echo ":: Enabling ${#user_units[@]} user services"
for u in "${user_units[@]}"; do
  systemctl --user enable "$u" || echo "!! could not enable --user $u (skipped)"
done

echo ":: Rebuilding the UKI (mkinitcpio.conf and linux.preset just changed)"
sudo mkinitcpio -P

# linux.preset builds a single image (PRESETS=('default'), fallback commented
# out) and limine.conf has one entry pointing at it. If it is missing there is
# nothing else to boot, so check before saying "done".
uki="/boot/EFI/Linux/arch-linux.efi"
if ! sudo test -s "$uki"; then
  echo "!! $uki is missing or empty -- DO NOT REBOOT."
  echo "   There is no fallback image. Fix /etc/mkinitcpio.conf, then re-run:"
  echo "     sudo mkinitcpio -P"
  exit 1
fi
echo ":: UKI built: $uki"

echo ":: Done. Reboot."
if [[ -n "$backup" ]]; then
  echo "   /etc backup, if you need to undo this: $backup"
fi
