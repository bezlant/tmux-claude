#!/usr/bin/env bash
# Dashboard popup: shows last N lines from every pane in the current window
# Triggered by prefix + D

LINES_PER_PANE=8
SEPARATOR="━"

generate_dashboard() {
    local current_pane
    current_pane=$(tmux display-message -p '#{pane_id}')
    local window_id
    window_id=$(tmux display-message -p '#{window_id}')

    local panes
    panes=$(tmux list-panes -t "$window_id" -F '#{pane_id}:#{pane_index}:#{pane_title}:#{pane_current_command}')

    local output=""
    local sep_line
    sep_line=$(printf '%0.s━' $(seq 1 60))

    while IFS= read -r pane_info; do
        local pane_id pane_idx pane_title pane_cmd
        pane_id=$(echo "$pane_info" | cut -d: -f1)
        pane_idx=$(echo "$pane_info" | cut -d: -f2)
        pane_title=$(echo "$pane_info" | cut -d: -f3)
        pane_cmd=$(echo "$pane_info" | cut -d: -f4-)

        local marker=""
        if [ "$pane_id" = "$current_pane" ]; then
            marker=" (you)"
        fi

        local label="${pane_title:-$pane_cmd}"
        output+="$(printf '\033[1;35mPane %s: %s%s \033[0m\n' "$pane_idx" "$label" "$marker")"
        output+="$(printf '\033[2m%s\033[0m\n' "$sep_line")"

        local captured
        captured=$(tmux capture-pane -p -t "$pane_id" -S -"$LINES_PER_PANE" 2>/dev/null | tail -"$LINES_PER_PANE")

        if [ -n "$captured" ]; then
            output+="$captured"
        else
            output+="  (empty)"
        fi
        output+=$'\n\n'
    done <<< "$panes"

    echo "$output"
}

# Show in a popup, 80% width/height, dismiss with q or Escape
tmux display-popup -w 80% -h 80% -T " Claude Team Dashboard " \
    -E "bash -c '$(declare -f generate_dashboard); generate_dashboard | less -R -S --prompt=\"Press q to close\"'"
