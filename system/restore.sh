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

# Rebuild the boot image. Which command is right depends on how this machine
# boots, so detect it rather than assume.
#
# With limine-mkinitcpio-hook installed, /etc/pacman.d/hooks/90-mkinitcpio-install.hook
# shadows Arch's stock hook of the same name (/etc/pacman.d/hooks wins over
# /usr/share/libalpm/hooks), and kernel builds go through
# limine-mkinitcpio-install instead. That calls `mkinitcpio --generate` directly
# and ignores /etc/mkinitcpio.d/*.preset entirely: vmlinuz and initramfs land in
# /boot/<machine-id>/<kernel>/ and are registered in limine.conf. On such a
# machine the preset's UKI is never rebuilt and never booted, so checking it
# would pass while telling you nothing.
if command -v limine-mkinitcpio >/dev/null 2>&1; then
  echo ":: Rebuilding initramfs via limine-mkinitcpio"
  sudo limine-mkinitcpio

  # Check what actually boots: every kernel directory needs both halves, and
  # limine.conf needs at least one entry to point at them.
  #
  # Find kernel directories by looking for a plain `vmlinuz`, not by listing
  # subdirectories. limine-snapper-sync keeps a limine_history/ store next to
  # them holding the snapshots' kernels, and those are hash-suffixed
  # (vmlinuz_sha256_...), so listing directories would flag it as a broken
  # kernel and fail every run.
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
fi

echo ":: Done. Reboot."
if [[ -n "$backup" ]]; then
  echo "   /etc backup, if you need to undo this: $backup"
fi
