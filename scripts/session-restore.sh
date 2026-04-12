#!/usr/bin/env bash
# tmux-claude: Post-restore hook for tmux-resurrect
# Resume Claude Code sessions in panes that had them before crash.
#
# Strategy per pane:
#   UUID known   -> claude --resume UUID      (direct, no picker)
#   UUID unknown -> claude --resume 'TARGET'  (name-filtered picker)
#
# The name filter works when sessions were tagged via the shell wrapper
# (--name "SESSION:WIN.PANE"). For untagged sessions, the user picks
# from the full list.

RESURRECT_DIR=$(tmux show-option -gqv @resurrect-dir 2>/dev/null)
RESURRECT_DIR="${RESURRECT_DIR:-$HOME/.tmux/resurrect}"
RESURRECT_DIR="${RESURRECT_DIR/#\~/$HOME}"

MAPPING_FILE="${RESURRECT_DIR}/claude-panes.txt"

[ -f "$MAPPING_FILE" ] || exit 0
[ -s "$MAPPING_FILE" ] || exit 0

# Give shells time to initialize after restore
sleep 1

while IFS='|' read -r target cwd uuid; do
    [ -z "$target" ] && continue

    if [ -n "$uuid" ]; then
        tmux send-keys -t "$target" "claude --resume '$uuid'" Enter 2>/dev/null
    else
        tmux send-keys -t "$target" "claude --resume '$target'" Enter 2>/dev/null
    fi

    sleep 0.3
done < "$MAPPING_FILE"
