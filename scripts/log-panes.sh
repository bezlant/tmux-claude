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
panes=$(tmux list-panes -t "$window_id" -F '#{pane_id}:#{pane_index}:#{pane_title}')
enabled=0

while IFS= read -r pane_info; do
    pane_id=$(echo "$pane_info" | cut -d: -f1)
    pane_idx=$(echo "$pane_info" | cut -d: -f2)
    pane_title=$(echo "$pane_info" | cut -d: -f3)

    label=$(echo "${pane_title:-pane-$pane_idx}" | tr ' /' '-_')
    log_file="$LOG_DIR/${pane_idx}-${label}.log"

    # pipe-pane toggles: if already piping, this stops it. We always start fresh.
    tmux pipe-pane -t "$pane_id" ""
    tmux pipe-pane -t "$pane_id" -o "cat >> '$log_file'"
    enabled=$((enabled + 1))
done <<< "$panes"

tmux display-message "Logging $enabled panes to $LOG_DIR"
