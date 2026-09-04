#!/usr/bin/env bash
#################
# JuicyGoose007 #
#################
set -euo pipefail

# powerdown - close Vesktop and Steam, confirm they're gone, then power off.
#
#   powerdown.sh       close both, then poweroff
#   powerdown.sh -n    close both, skip the poweroff

TIMEOUT=${TIMEOUT:-45}
do_poweroff=1

while getopts "n" opt; do
  case "$opt" in
    n) do_poweroff=0 ;;
    *) echo "Usage: powerdown.sh [-n]" >&2; exit 1 ;;
  esac
done

alive() { kill -0 "$1" 2>/dev/null; }

cmdline_of() {
  tr '\0' ' ' < "/proc/$1/cmdline" 2>/dev/null || true
}

# Vesktop is 5 electron processes. Only the main one lacks --type=, and killing
# it takes the children with it.
vesktop_pid() {
  local pid
  for pid in $(pgrep -f 'vesktop.*app\.asar' || true); do
    case "$(cmdline_of "$pid")" in
      *--type=*) ;;
      *) echo "$pid"; return 0 ;;
    esac
  done
}

# Every process of an app shares one systemd user cgroup (KillMode=control-group),
# so killing it reaps the whole tree - including Steam's bwrap sandbox. Scope
# names are PID-derived, so read them at runtime.
#
# The *.scope test is a safety check, not a formality: how an app was launched
# decides its cgroup, and it is not always its own. Launched through
# `niri msg action spawn` it lands in niri.service, and killing that would take
# the whole compositor down. Only ever kill a transient app-*.scope.
scope_of() {
  local path name
  path=$(grep -m1 '^0::' "/proc/$1/cgroup" 2>/dev/null | cut -d: -f3 || true)
  [[ $path == *.scope ]] || return 0
  name=$(basename "$path")
  [[ $name == app-* ]] || return 0
  echo "$name"
}

# Fallback for the rare case where the app has no private scope of its own.
# Best-effort only: this reaches the anchor's descendants, not its ancestors.
descendants() {
  local child
  echo "$1"
  for child in $(pgrep -P "$1" || true); do
    descendants "$child"
  done
}

pids=()
names=()

# pgrep exits 1 when nothing matches, which set -e treats as fatal.
steam_pid=$(pgrep -x steam || true)
vesk_pid=$(vesktop_pid || true)

# SIGTERM rather than `steam -shutdown`: the NixOS steam binary is an FHS
# wrapper, so -shutdown boots a second bwrap sandbox just to deliver the
# message. Measured 2026-08-20, it never reached the client. The sandbox shares
# our PID namespace, so signalling the client directly works and is instant.
if [[ -n $steam_pid ]]; then
  echo "Asking Steam to exit (pid $steam_pid)..."
  kill -TERM "$steam_pid" 2>/dev/null || true
  pids+=("$steam_pid"); names+=("Steam")
else
  echo "Steam not running."
fi

if [[ -n $vesk_pid ]]; then
  echo "Asking Vesktop to exit (pid $vesk_pid)..."
  kill -TERM "$vesk_pid" 2>/dev/null || true
  pids+=("$vesk_pid"); names+=("Vesktop")
else
  echo "Vesktop not running."
fi

# An app launched from a terminal inherits that terminal's scope rather than
# owning one. Killing the scope would then take the terminal with it, so fall
# back to the bare pid whenever the scope is the one we're running in.
my_scope=$(scope_of $$ || true)

force() {
  local pid=$1 name=$2 scope p n=0
  scope=$(scope_of "$pid" || true)
  if [[ -n $scope && $scope != "$my_scope" ]]; then
    echo "  SIGKILL $name ($scope)"
    systemctl --user kill --signal=SIGKILL "$scope" || true
    return 0
  fi
  for p in $(descendants "$pid"); do
    kill -KILL "$p" 2>/dev/null || true
    n=$(( n + 1 ))
  done
  echo "  SIGKILL $name (no private scope - killed $n procs under pid $pid)"
  echo "  note: $name had no scope of its own; wrapper processes above it may survive" >&2
}

if (( ${#pids[@]} == 0 )); then
  echo "Nothing to close."
else
  start=$SECONDS
  # Record each app's own exit time, not just the total wait, so a slow one is
  # named rather than averaged in with a fast one.
  took=()
  for i in "${!pids[@]}"; do took[i]=-1; done

  while (( SECONDS - start < TIMEOUT )); do
    any=0
    for i in "${!pids[@]}"; do
      if alive "${pids[$i]}"; then
        any=1
      elif (( took[i] < 0 )); then
        took[i]=$(( SECONDS - start ))
      fi
    done
    (( any )) || break
    printf '.'
    sleep 1
  done
  printf '\n'

  for i in "${!pids[@]}"; do
    if alive "${pids[$i]}"; then
      echo "${names[$i]} still running after ${TIMEOUT}s - forcing."
      force "${pids[$i]}" "${names[$i]}"
    else
      (( took[i] < 0 )) && took[i]=$(( SECONDS - start ))
      echo "${names[$i]} exited cleanly after ${took[$i]}s."
    fi
  done

  sleep 1
  for i in "${!pids[@]}"; do
    if alive "${pids[$i]}"; then
      echo "  WARNING: ${names[$i]} survived SIGKILL" >&2
    fi
  done
fi

if (( do_poweroff )); then
  echo "Powering off."
  systemctl poweroff
else
  echo "Dry run - not powering off."
fi

#################
# End of Script #
#################
