#!/usr/bin/env bash
# Renders dashboard content inside the popup
# Separated from dashboard.sh so we don't need declare -f tricks

LINES_PER_PANE=8

current_pane=$(tmux display-message -p '#{pane_id}')
window_id=$(tmux display-message -p '#{window_id}')
sep_line=$(printf '%0.s━' $(seq 1 60))

tmux list-panes -t "$window_id" -F '#{pane_id}|#{pane_index}|#{pane_current_command}' | \
while IFS='|' read -r pane_id pane_idx pane_cmd; do
    marker=""
    if [ "$pane_id" = "$current_pane" ]; then
        marker=" (you)"
    fi

    printf '\033[1;35mPane %s: %s%s \033[0m\n' "$pane_idx" "$pane_cmd" "$marker"
    printf '\033[2m%s\033[0m\n' "$sep_line"

    captured=$(tmux capture-pane -p -t "$pane_id" -S -"$LINES_PER_PANE" 2>/dev/null | tail -"$LINES_PER_PANE")
    if [ -n "$captured" ]; then
        echo "$captured"
    else
        echo "  (empty)"
    fi
    echo ""
done | less -R -S --prompt "Press q to close"
