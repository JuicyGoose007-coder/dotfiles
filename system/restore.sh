#!/usr/bin/env bash
# Restore system config outside $HOME: /etc, services, boot image.
# Run after install.sh. WARNING: overwrites files in /etc.
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

read -rp "Overwrite /etc files from this repo? [y/N] " ans
[[ "$ans" == [yY]* ]] || { echo "Aborted."; exit 1; }

# Back up only the /etc files this repo is about to overwrite.
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

# Add every name in pins.txt to IgnorePkg. pacman.conf is edited in place
# rather than copied in, so the rest of it stays stock.
while read -r pin _; do
  [[ -z "$pin" || "$pin" == \#* ]] && continue
  if pacman-conf IgnorePkg 2>/dev/null | grep -qx "$pin"; then
    echo ":: $pin is already pinned"
  elif grep -qE '^[[:space:]]*IgnorePkg[[:space:]]*=' /etc/pacman.conf; then
    sudo sed -i -E "0,/^[[:space:]]*IgnorePkg[[:space:]]*=.*/s//& $pin/" /etc/pacman.conf
    echo ":: Added $pin to IgnorePkg"
  elif grep -qE '^[[:space:]]*#[[:space:]]*IgnorePkg[[:space:]]*=' /etc/pacman.conf; then
    sudo sed -i -E "0,/^[[:space:]]*#[[:space:]]*IgnorePkg[[:space:]]*=.*/s//IgnorePkg   = $pin/" /etc/pacman.conf
    echo ":: Pinned $pin"
  else
    echo "!! No IgnorePkg line in /etc/pacman.conf -- add '$pin' by hand."
  fi
  pacman-conf IgnorePkg | grep -qx "$pin" || echo "!! $pin is still not pinned"
done < "$src/../scripts/packages/pins.txt"

# Split services-enabled.txt at its "User services" marker.
sys_units=(); user_units=(); target="sys"
while IFS= read -r line; do
  [[ "$line" == *"User services"* ]] && target="user"
  line="${line%%#*}"; line="${line// /}"
  [[ -z "$line" ]] && continue
  if [[ "$target" == "sys" ]]; then sys_units+=("$line"); else user_units+=("$line"); fi
done < "$src/services-enabled.txt"

# Warn on a missing unit rather than aborting mid-restore.
echo ":: Enabling ${#sys_units[@]} system services"
for u in "${sys_units[@]}"; do
  sudo systemctl enable "$u" || echo "!! could not enable $u (skipped)"
done

echo ":: Enabling ${#user_units[@]} user services"
for u in "${user_units[@]}"; do
  systemctl --user enable "$u" || echo "!! could not enable --user $u (skipped)"
done

# Rebuild the boot image with whichever tool this machine boots through.
# limine-mkinitcpio-hook bypasses mkinitcpio presets entirely.
if command -v limine-mkinitcpio >/dev/null 2>&1; then
  echo ":: Rebuilding initramfs via limine-mkinitcpio"
  sudo limine-mkinitcpio

  # Verify what boots. Match on a plain `vmlinuz` so limine_history/'s
  # hash-suffixed snapshot kernels are not mistaken for broken ones.
  mid="$(cat /etc/machine-id)"
  kdirs=()
  mapfile -t kdirs < <(
    sudo find "/boot/$mid" -mindepth 2 -maxdepth 2 -type f -name vmlinuz -printf '%h\n' 2>/dev/null | sort -u
  )

  ok=1
  if ((${#kdirs[@]} == 0)); then
    echo "!! No kernel found under /boot/$mid"
    ok=0
  fi
  for d in "${kdirs[@]}"; do
    for f in vmlinuz initramfs; do
      sudo test -s "$d/$f" || { echo "!! $d/$f is missing or empty"; ok=0; }
    done
  done

  entries="$(sudo grep -c '^/' /boot/limine.conf 2>/dev/null || true)"
  ((${entries:-0} > 0)) || { echo "!! /boot/limine.conf has no boot entries"; ok=0; }

  if ((ok == 0)); then
    echo "   DO NOT REBOOT. Fix /etc/mkinitcpio.conf, then re-run:"
    echo "     sudo limine-mkinitcpio"
    exit 1
  fi
  echo ":: Boot files OK: ${#kdirs[@]} kernel(s) under /boot/$mid, $entries entries in limine.conf"
else
  echo ":: Rebuilding the UKI (mkinitcpio.conf and linux.preset just changed)"
  sudo mkinitcpio -P

  # Single image, no fallback -- check it exists before saying done.
  uki="/boot/EFI/Linux/arch-linux.efi"
  if ! sudo test -s "$uki"; then
    echo "!! $uki is missing or empty -- DO NOT REBOOT."
    echo "   There is no fallback image. Fix /etc/mkinitcpio.conf, then re-run:"
    echo "     sudo mkinitcpio -P"
    exit 1
  fi
  echo ":: UKI built: $uki"
fi

echo ":: Done. Reboot."
if [[ -n "$backup" ]]; then
  echo "   /etc backup, if you need to undo this: $backup"
fi
