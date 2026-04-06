#!/usr/bin/env bash
# Auto-log a single pane when it's created
# Triggered by tmux after-split-window / after-new-window hooks

LOG_DIR="${TMPDIR:-/tmp}/claude-team-logs"
mkdir -p "$LOG_DIR"

pane_id=$(tmux display-message -p '#{pane_id}')
pane_idx=$(tmux display-message -p '#{pane_index}')
window_idx=$(tmux display-message -p '#{window_index}')
timestamp=$(date +%Y%m%d-%H%M%S)

log_file="$LOG_DIR/w${window_idx}-p${pane_idx}-${timestamp}.log"

tmux pipe-pane -t "$pane_id" -o "cat >> '$log_file'"
