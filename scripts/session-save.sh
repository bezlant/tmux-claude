#!/usr/bin/env bash
# tmux-claude: Post-save hook for tmux-resurrect
# 1. Prune old resurrect files (keep last N)
# 2. Record pane→session UUID mapping using Claude Code's own PID files
#
# Claude Code writes ~/.claude/sessions/<pid>.json for every running
# instance, containing the exact sessionId. We read these directly
# instead of heuristics — no guessing, no name collisions.

RESURRECT_DIR=$(tmux show-option -gqv @resurrect-dir 2>/dev/null)
RESURRECT_DIR="${RESURRECT_DIR:-$HOME/.tmux/resurrect}"
RESURRECT_DIR="${RESURRECT_DIR/#\~/$HOME}"

MAPPING_FILE="${RESURRECT_DIR}/claude-panes.txt"
CLAUDE_SESSIONS="${HOME}/.claude/sessions"
MAX_SAVES=${TMUX_CLAUDE_MAX_SAVES:-20}

# --- Prune old saves ---
if [ -d "$RESURRECT_DIR" ]; then
    cd "$RESURRECT_DIR" || exit 0
    ls -t tmux_resurrect_*.txt 2>/dev/null | tail -n +$((MAX_SAVES + 1)) | xargs rm -f 2>/dev/null
fi

# --- Build TTY → pane lookup ---
pane_info=$(tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index}|#{pane_tty}' 2>/dev/null)

# --- Match claude processes to panes via TTY, get UUID from PID files ---
: > "$MAPPING_FILE"
while read -r tty pid rest; do
    [ -z "$tty" ] || [ "$tty" = "??" ] && continue
    full_tty="/dev/$tty"

    # Match TTY to pane
    target=$(echo "$pane_info" | grep "|${full_tty}$" | head -1 | cut -d'|' -f1)
    [ -z "$target" ] && continue

    # Read session UUID from Claude Code's own PID file
    pidfile="${CLAUDE_SESSIONS}/${pid}.json"
    uuid=""
    if [ -f "$pidfile" ]; then
        uuid=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['sessionId'])" "$pidfile" 2>/dev/null)
    fi

    echo "${target}|${uuid}" >> "$MAPPING_FILE"
done < <(ps -eo tty=,pid=,args= 2>/dev/null | awk '$3 == "claude"')
