#!/usr/bin/env bash
#################
# JuicyGoose007 #
#################
set -euo pipefail

# One column on a workspace fills the screen, two columns split it in half.
# Three or more are left alone. Widths only change when the column count does,
# so manual resizes stick until a window opens or closes.

skip_workspaces='["Gaming"]'

declare -A last_count

relayout() {
    local workspaces wid count ids width applied
    workspaces=$(niri msg --json workspaces) || return 0

    while read -r wid count ids; do
        [[ "${last_count[$wid]:-}" == "$count" ]] && continue
        last_count[$wid]=$count

        case $count in
            1) width="100%" ;;
            2) width="50%" ;;
            *) continue ;;
        esac

        # A window can close between the query and the resize. Forget the
        # count on failure so the next event tries again.
        applied=1
        for id in $ids; do
            niri msg action set-window-width --id "$id" "$width" || applied=0
        done
        ((applied)) || unset "last_count[$wid]"
    done < <(niri msg --json windows | jq -r --argjson ws "$workspaces" --argjson skip "$skip_workspaces" '
        [.[] | select((.is_floating | not) and .workspace_id != null and .layout.pos_in_scrolling_layout != null)] as $tiled
        | $ws[]
        | select(.name as $n | $skip | any(. == $n) | not)
        | .id as $wid
        | [$tiled[] | select(.workspace_id == $wid)]
        | group_by(.layout.pos_in_scrolling_layout[0])
        | map(.[0].id | tostring)
        | "\($wid) \(length) \(join(" "))"
    ')
}

niri msg --json event-stream | while read -r event; do
    case $event in
        '{"WindowsChanged"'* | '{"WindowOpenedOrChanged"'* | '{"WindowClosed"'* | '{"WindowLayoutsChanged"'*)
            relayout
            ;;
    esac
done

#################
# End of Script #
#################
