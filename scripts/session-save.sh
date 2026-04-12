#!/usr/bin/env bash
# tmux-claude: Post-save hook for tmux-resurrect
# 1. Prune old resurrect files (keep last N)
# 2. Record which panes run Claude Code (target|cwd)
#
# Restore relies on --name tags set by the shell wrapper for session
# matching. No UUID heuristics — they're fragile and silently resume
# wrong sessions when they guess wrong.
#
# Runs automatically after every tmux-resurrect save (manual or continuum).

RESURRECT_DIR=$(tmux show-option -gqv @resurrect-dir 2>/dev/null)
RESURRECT_DIR="${RESURRECT_DIR:-$HOME/.tmux/resurrect}"
# Expand ~ if present
RESURRECT_DIR="${RESURRECT_DIR/#\~/$HOME}"

MAPPING_FILE="${RESURRECT_DIR}/claude-panes.txt"
MAX_SAVES=${TMUX_CLAUDE_MAX_SAVES:-20}

# --- Prune old saves ---
if [ -d "$RESURRECT_DIR" ]; then
    cd "$RESURRECT_DIR" || exit 0
    ls -t tmux_resurrect_*.txt 2>/dev/null | tail -n +$((MAX_SAVES + 1)) | xargs rm -f 2>/dev/null
fi

# --- Build TTY -> pane info lookup ---
pane_info=$(tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index}|#{pane_tty}|#{pane_current_path}' 2>/dev/null)

# --- Find claude processes and match to panes ---
# IMPORTANT: Match only the claude binary, not paths containing '.claude/'
# or tools like 'claude-limitline'. awk checks command name is exactly "claude".
: > "$MAPPING_FILE"
while read -r tty rest; do
    [ -z "$tty" ] || [ "$tty" = "??" ] && continue
    full_tty="/dev/$tty"
    match=$(echo "$pane_info" | grep "|${full_tty}|" | head -1)
    [ -z "$match" ] && continue
    target=$(echo "$match" | cut -d'|' -f1)
    cwd=$(echo "$match" | cut -d'|' -f3)
    echo "${target}|${cwd}" >> "$MAPPING_FILE"
done < <(ps -eo tty=,args= 2>/dev/null | awk '$2 == "claude"')
