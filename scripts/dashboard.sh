#!/usr/bin/env bash
# Dashboard popup: shows last N lines from every pane in the current window

if [ -z "$TMUX" ]; then
    echo "Not in a tmux session" >&2
    exit 1
fi

pane_count=$(tmux list-panes -F '#{pane_id}' | wc -l | tr -d ' ')
if [ "$pane_count" -le 1 ]; then
    tmux display-message "Only one pane — nothing to dashboard"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

tmux display-popup -w 80% -h 80% -T " Claude Team Dashboard " \
    -E "bash '$SCRIPT_DIR/dashboard-render.sh'"
