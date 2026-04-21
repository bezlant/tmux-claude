#!/usr/bin/env bash
# tmux-claude: Post-restore hook for tmux-resurrect
# Resume Claude Code sessions using exact UUIDs from PID file mapping.
#
# Format: target|uuid (one per line)
# UUID present  → claude --resume UUID   (direct, guaranteed correct)
# UUID missing  → claude --resume        (opens picker, user chooses)

RESURRECT_DIR=$(tmux show-option -gqv @resurrect-dir 2>/dev/null)
RESURRECT_DIR="${RESURRECT_DIR:-$HOME/.tmux/resurrect}"
RESURRECT_DIR="${RESURRECT_DIR/#\~/$HOME}"

MAPPING_FILE="${RESURRECT_DIR}/claude-panes.txt"

[ -f "$MAPPING_FILE" ] || exit 0
[ -s "$MAPPING_FILE" ] || exit 0

# Give shells time to initialize after restore
sleep 1

while IFS='|' read -r target uuid; do
    [ -z "$target" ] && continue
    if [ -n "$uuid" ]; then
        tmux send-keys -t "$target" "claude --resume '$uuid'" Enter 2>/dev/null
    else
        tmux send-keys -t "$target" "claude --resume" Enter 2>/dev/null
    fi
    sleep 0.3
done < "$MAPPING_FILE"
