#!/usr/bin/env bash
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sudo install -Dm644 "$src/limine.conf" /boot/EFI/BOOT/limine.conf
sudo install -Dm644 "$src/sushi.jpg"   /boot/limine/sushi.jpg
echo "Limine theme installed. Reboot to see it."
