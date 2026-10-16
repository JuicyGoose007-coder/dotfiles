#!/usr/bin/env bash
#################
# JuicyGoose007 #
#################
# Save or restore Zen Browser settings: prefs, CSS, mods, script mods,
# shortcuts, containers.
# Not a stow package -- Zen names its profile folder at random, so this finds
# it through profiles.ini and copies files in or out. Copies, not symlinks:
# Zen rewrites several of these files itself, which would replace a symlink.
# Personal data (passwords, cookies, history, bookmarks) stays out; Zen Sync
# brings that back.
#
#   zen.sh save      profile -> repo   (run after changing settings in Zen)
#   zen.sh restore   repo -> profile   (Zen must be closed)
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/profile"
root="$HOME/.config/zen"
app=/opt/zen-browser-bin

# Top-level files copied as-is. Folders are replaced whole.
dirs=(chrome/zen-themes chrome/utils chrome/JS)
files=(
  user.js
  chrome/userChrome.css
  chrome/userContent.css
  chrome/zen-themes.css
  zen-themes.json
  zen-keyboard-shortcuts.json
  containers.json
)

# The profile Zen actually opens is the Default= in its [Install...] section.
rel=""
[[ -f "$root/profiles.ini" ]] &&
  rel=$(awk -F= '/^\[Install/{i=1;next} /^\[/{i=0} i&&$1=="Default"{print $2;exit}' "$root/profiles.ini")
if [[ -z "$rel" || ! -d "$root/$rel" ]]; then
  echo "No Zen profile found. Start Zen once, quit it, then run this again." >&2
  exit 1
fi
profile="$root/$rel"

case "${1:-}" in
save)
  for f in "${files[@]}"; do
    mkdir -p "$src/$(dirname "$f")"
    cp "$profile/$f" "$src/$f"
  done
  for d in "${dirs[@]}"; do
    rm -rf "${src:?}/$d"
    cp -r "$profile/$d" "$src/$d"
  done

  # Mod settings live in prefs.js among ~300 other lines of browser state.
  # Keep only the prefs the installed mods declare in their preferences.json,
  # plus Tab Groups' sections (zen.sitegroups.*), which it doesn't declare.
  cat "$profile"/chrome/zen-themes/*/preferences.json 2>/dev/null |
    jq -r '.[].property' | sort -u |
    awk 'NR==FNR{want[$0];next}
         match($0,/^user_pref\("[^"]+"/){n=substr($0,12,RLENGTH-12); if(n in want || n ~ /^zen\.sitegroups\./) print}' \
      - "$profile/prefs.js" >"$src/mod-prefs.js"
  echo ":: Saved Zen settings from $profile"
  ;;
restore)
  if pgrep -x zen-bin >/dev/null; then
    echo "Zen is running. Quit it first -- it overwrites its files on exit." >&2
    exit 1
  fi
  for f in "${files[@]}"; do
    mkdir -p "$profile/$(dirname "$f")"
    cp "$src/$f" "$profile/$f"
  done
  # The Noctalia imports hold an absolute path saved on another machine.
  # Point them at this user's home instead.
  sed -i -E "s|@import \"[^\"]*/\.cache/noctalia/|@import \"$HOME/.cache/noctalia/|" \
    "$profile/chrome/userChrome.css" "$profile/chrome/userContent.css"
  for d in "${dirs[@]}"; do
    rm -rf "${profile:?}/$d"
    cp -r "$src/$d" "$profile/$d"
  done

  # fx-autoconfig runs chrome/JS/*.uc.js scripts, but only once its two
  # starter files sit in Zen's install folder. Root owns that folder.
  for f in config.js defaults/pref/config-prefs.js; do
    cmp -s "$src/../program/$f" "$app/$f" ||
      sudo install -Dm644 "$src/../program/$f" "$app/$f"
  done
  rm -rf "$HOME/.cache/zen/$rel/startupCache"

  # Swap in the saved mod settings, dropping any old copies of the same prefs.
  touch "$profile/prefs.js"
  awk 'NR==FNR{if(match($0,/^user_pref\("[^"]+"/)) have[substr($0,1,RLENGTH)];next}
       !(match($0,/^user_pref\("[^"]+"/) && substr($0,1,RLENGTH) in have)' \
    "$src/mod-prefs.js" "$profile/prefs.js" >"$profile/prefs.js.new"
  cat "$src/mod-prefs.js" >>"$profile/prefs.js.new"
  mv "$profile/prefs.js.new" "$profile/prefs.js"
  echo ":: Restored Zen settings into $profile"
  ;;
*)
  echo "Usage: $0 save|restore" >&2
  exit 1
  ;;
esac

#################
# End of Script #
#################
