#!/bin/sh
#################
# JuicyGoose007 #
#################
# Focus the agent that most needs you: blocked (waiting on input) first,
# then done. Does nothing if every agent is working or idle.
pane=$(herdr agent list | jq -r '
	.result.agents
	| (map(select(.agent_status == "blocked")) + map(select(.agent_status == "done")))
	| first | .pane_id // empty')
[ -n "$pane" ] && herdr agent focus "$pane"

#################
# End of Script #
#################
