#!/bin/bash
# Add the shared Games drive to /etc/fstab.
# nofail: a missing drive must not drop the boot to an emergency shell.
set -euo pipefail

uuid="0ca9f5bb-3aa4-4050-8e12-5b69d3296659"
mnt="/run/media/$USER/Games"
line="UUID=$uuid  $mnt ext4 defaults,nofail 0 0"

if [[ ! -e "/dev/disk/by-uuid/$uuid" ]]; then
  echo "Games drive not found on this machine, nothing to do."
  exit 0
fi

if grep -q "$uuid" /etc/fstab; then
  echo "Already in /etc/fstab, nothing to do."
  exit 0
fi

echo "$line" | sudo tee -a /etc/fstab >/dev/null
echo "Added: $line"
