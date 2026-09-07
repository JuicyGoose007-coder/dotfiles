#!/usr/bin/env bash
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# limine.conf ships with a @ROOT_PARTUUID@ placeholder rather than a real value,
# so a stale UUID from another machine can never be deployed by accident. Fill it
# in from whatever is actually mounted at / right now.
root_dev="$(findmnt -no SOURCE /)"
root_partuuid="$(blkid -s PARTUUID -o value "$root_dev")"
[[ -n "$root_partuuid" ]] || { echo "could not read PARTUUID of $root_dev"; exit 1; }
echo "Root is $root_dev, PARTUUID $root_partuuid"

sed "s/@ROOT_PARTUUID@/$root_partuuid/" "$src/limine.conf" \
  | sudo install -Dm644 /dev/stdin /boot/EFI/BOOT/limine.conf
sudo install -Dm644 "$src/sushi.jpg"   /boot/limine/sushi.jpg
echo "Limine theme installed. Reboot to see it."
