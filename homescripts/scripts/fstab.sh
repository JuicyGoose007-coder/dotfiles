#!/bin/bash
# Add the shared Games drive to /etc/fstab. It is shared between distros, so
# nofail matters: without it a boot with the drive absent or claimed elsewhere
# drops to an emergency shell instead of carrying on.
set -euo pipefail

uuid="0ca9f5bb-3aa4-4050-8e12-5b69d3296659"
mnt="/run/media/juicygoose007/Games"
line="UUID=$uuid  $mnt ext4 defaults,nofail 0 0"

if grep -q "$uuid" /etc/fstab; then
  echo "Already in /etc/fstab, nothing to do."
  exit 0
fi

echo "$line" | sudo tee -a /etc/fstab >/dev/null
echo "Added: $line"
