#!/usr/bin/env bash
#################
# JuicyGoose007 #
#################
# Save or restore Noctalia's GUI settings (~/.local/state/noctalia/settings.toml).
# Not a stow package: Noctalia saves through a temp file and a rename, which
# would replace a symlink with a plain file and silently stop tracking it.
# The hand-written ~/.config/noctalia/noctalia.toml is stowed as usual.
#
#   noctalia.sh save      live -> repo   (run after changing settings in Noctalia)
#   noctalia.sh restore   repo -> live   (bootstrap.sh runs this)
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/settings.toml"
live="$HOME/.local/state/noctalia/settings.toml"

case "${1:-}" in
save)
  cp "$live" "$repo"
  echo ":: Saved Noctalia settings from $live"
  ;;
restore)
  if pgrep -x noctalia >/dev/null; then
    echo "Noctalia is running and would overwrite this. Log out to a TTY first." >&2
    exit 1
  fi
  mkdir -p "$(dirname "$live")"
  [[ -f "$live" ]] && cp "$live" "$live.bak-$(date +%Y%m%d-%H%M%S)"
  # Wallpaper paths hold the home folder of the machine that saved them.
  sed -E "s|\"/home/[^/\"]+/|\"$HOME/|g" "$repo" >"$live"
  echo ":: Restored Noctalia settings into $live"
  ;;
*)
  echo "Usage: $0 save|restore" >&2
  exit 1
  ;;
esac

#################
# End of Script #
#################
