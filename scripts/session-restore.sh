#!/usr/bin/env bash
# tmux-claude: Post-restore hook for tmux-resurrect
# Resume Claude Code sessions in panes that had them before crash.
#
# Uses `claude --resume TARGET` where TARGET is the --name tag
# (e.g. "main:1.0") set by the shell wrapper. Claude's --resume
# filters the session list by name, so tagged sessions restore
# directly. Untagged sessions show the full picker.

RESURRECT_DIR=$(tmux show-option -gqv @resurrect-dir 2>/dev/null)
RESURRECT_DIR="${RESURRECT_DIR:-$HOME/.tmux/resurrect}"
RESURRECT_DIR="${RESURRECT_DIR/#\~/$HOME}"

MAPPING_FILE="${RESURRECT_DIR}/claude-panes.txt"

[ -f "$MAPPING_FILE" ] || exit 0
[ -s "$MAPPING_FILE" ] || exit 0

# Give shells time to initialize after restore
sleep 1

while IFS='|' read -r target cwd; do
    [ -z "$target" ] && continue
    tmux send-keys -t "$target" "claude --resume '$target'" Enter 2>/dev/null
    sleep 0.3
done < "$MAPPING_FILE"
