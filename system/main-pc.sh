#!/usr/bin/env bash
#################
# JuicyGoose007 #
#################
# Settings that only fit the main PC (DP-1 1920x1080 left, DP-2 2560x1440
# right). Run after restore.sh, and again after any later restore.sh run,
# since that copies greeter.toml back without these. Do not run on other PCs.
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The second drive with the Steam library.
"$src/../homescripts/scripts/fstab.sh"

greeter=/var/lib/noctalia-greeter/greeter.toml

# Login screen on the right monitor only. Its name comes from the port it is
# plugged into, so it differs on other machines.
if sudo grep -q '^\[output\]' "$greeter"; then
  echo ":: $greeter already has an [output] section, leaving it"
else
  sudo tee -a "$greeter" >/dev/null <<'EOF'

[output]
# Show the greeter only on this connector; all other outputs stay off.
name = "DP-2"
EOF
  echo ":: Login screen limited to DP-2"
fi

echo ":: Done. Takes effect the next time the login screen starts."

#################
# End of Script #
#################
