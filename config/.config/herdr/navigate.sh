#!/bin/sh
#################
# JuicyGoose007 #
#################
# Ctrl+h/j/k/l move to the neighboring herdr pane, even inside nvim.
# fzf (and fzf-tab) keeps the key, since Ctrl+j/k move through its list.
# Usage: navigate.sh <left|down|up|right> <h|j|k|l>
dir=$1
key=$2

# Matched on the FOREGROUND process only.
names=$(herdr pane process-info --current | jq -r '.result.process_info.foreground_processes[].name')
if printf '%s\n' "$names" | grep -iqE '^fzf$'; then
	pane=$(herdr pane current | jq -r '.result.pane.pane_id')
	herdr pane send-keys "$pane" "ctrl+$key"
else
	herdr pane focus --current --direction "$dir"
fi

#################
# End of Script #
#################
