#!/usr/bin/env bash
# Auto-log all panes in the current window to files

if [ -z "$TMUX" ]; then
    echo "Not in a tmux session" >&2
    exit 1
fi

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_DIR="${TMPDIR:-/tmp}/claude-team-logs/$TIMESTAMP"
mkdir -p "$LOG_DIR"

window_id=$(tmux display-message -p '#{window_id}')
enabled=0

tmux list-panes -t "$window_id" -F '#{pane_id}|#{pane_index}|#{pane_current_command}' | \
while IFS='|' read -r pane_id pane_idx pane_cmd; do
    label=$(echo "${pane_cmd:-pane}" | tr -cd '[:alnum:]-_')
    log_file="$LOG_DIR/${pane_idx}-${label}.log"

    tmux pipe-pane -t "$pane_id" ""
    tmux pipe-pane -t "$pane_id" -o "cat >> '$log_file'"
    enabled=$((enabled + 1))
done

tmux display-message "Logging panes to $LOG_DIR"
