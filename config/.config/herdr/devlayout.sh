#!/usr/bin/env bash
# Herdr "dev layout" — two workspaces: code gets a whole screen to itself, and
# everything else lives next door, so the editor is never squeezed into a column.
#
#   workspace "<label>"             workspace "<label>-run"
#   ┌───────────────────────────┐   ┌─────────────┬─────────────┐
#   │                           │   │             │             │
#   │   editor (full width)     │   │  test       │  ai         │
#   │   plain `nvim`            │   │  (env vars) │  (bare sh)  │
#   │   your daily driver       │   │             │             │
#   └───────────────────────────┘   └─────────────┴─────────────┘
#
# Why two workspaces: a sidebar pane is too narrow to paste code into. Long lines
# get truncated at the pane width and re-indented on the way in, which silently
# corrupts anything you paste. A full-width editor fixes that.
#
# The `test` pane is created with any KEY=VALUE args in its environment, so a
# bare command typed there always runs the thing under construction — never the
# daily driver.
#
# Usage:
#   devlayout.sh <project-dir> [label] [KEY=VALUE ...]
#
# Examples:
#   devlayout.sh ~/Projects/nvim nvim-dev NVIM_APPNAME=nvim-dev
#   devlayout.sh ~/Projects/api                       # label defaults to basename
#
# Notes:
#   - jq is not installed on this machine; IDs are parsed with python3 (already a
#     dependency of the Claude/Herdr integration hook).
#   - --no-focus on the second workspace leaves you in the editor.
#   - Pane IDs change across sessions. Never hardcode them; resolve with
#     `herdr pane list --workspace <id>`.
#   - Switch workspaces with prefix+w (picker).

set -euo pipefail

if [ $# -lt 1 ]; then
	sed -n '2,36p' "$0" >&2
	exit 64
fi

PROJ=$1
shift
[ -d "$PROJ" ] || {
	echo "devlayout: not a directory: $PROJ" >&2
	exit 66
}
PROJ=$(cd "$PROJ" && pwd)

LABEL=$(basename "$PROJ")
if [ $# -gt 0 ] && [[ $1 != *=* ]]; then
	LABEL=$1
	shift
fi

# Remaining args are KEY=VALUE pairs for the test pane only.
ENV_ARGS=()
for kv in "$@"; do
	[[ $kv == *=* ]] || {
		echo "devlayout: not a KEY=VALUE pair: $kv" >&2
		exit 64
	}
	ENV_ARGS+=(--env "$kv")
done

command -v herdr >/dev/null || {
	echo "devlayout: herdr not found on PATH" >&2
	exit 69
}

# Pull a nested key out of herdr's JSON responses.
j() {
	python3 -c 'import json,sys
d = json.load(sys.stdin)
for k in sys.argv[1:]:
    d = d[k]
print(d)' "$@"
}

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

# Workspace 1: the editor, alone, whole screen.
herdr workspace create --cwd "$PROJ" --label "$LABEL" --focus >"$TMP"
EDITOR_PANE=$(j result root_pane pane_id <"$TMP")
WS_CODE=$(j result root_pane workspace_id <"$TMP")

# Workspace 2: test on the left (carrying the injected env), ai on the right.
herdr workspace create --cwd "$PROJ" --label "$LABEL-run" \
	${ENV_ARGS[@]+"${ENV_ARGS[@]}"} --no-focus >"$TMP"
TEST_PANE=$(j result root_pane pane_id <"$TMP")
WS_RUN=$(j result root_pane workspace_id <"$TMP")

AI_PANE=$(herdr pane split --pane "$TEST_PANE" --direction right --ratio 0.5 \
	--cwd "$PROJ" --no-focus | j result pane pane_id)

herdr pane rename "$EDITOR_PANE" editor >/dev/null
herdr pane rename "$TEST_PANE" test >/dev/null
herdr pane rename "$AI_PANE" ai >/dev/null

# Only the editor pane gets a command. Starting Claude and running the thing
# under construction are both deliberate acts, left to you.
herdr pane run "$EDITOR_PANE" "nvim" >/dev/null

cat <<EOF
cwd $PROJ

  $WS_CODE  $LABEL
       $EDITOR_PANE  editor  (nvim, daily driver, whole screen)

  $WS_RUN  $LABEL-run
       $TEST_PANE  test    (bare shell${ENV_ARGS[*]+, env: $*})
       $AI_PANE  ai      (bare shell)

workspaces: prefix+w (picker)    focus: prefix+h/j/k/l
zoom: prefix+z    detach: prefix+q    reattach: herdr
EOF
