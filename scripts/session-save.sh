#!/usr/bin/env bash
# tmux-claude: Post-save hook for tmux-resurrect
# 1. Prune old resurrect files (keep last N)
# 2. Record which panes run Claude Code, with session UUIDs when determinable
#
# Runs automatically after every tmux-resurrect save (manual or continuum).

RESURRECT_DIR=$(tmux show-option -gqv @resurrect-dir 2>/dev/null)
RESURRECT_DIR="${RESURRECT_DIR:-$HOME/.tmux/resurrect}"
# Expand ~ if present
RESURRECT_DIR="${RESURRECT_DIR/#\~/$HOME}"

MAPPING_FILE="${RESURRECT_DIR}/claude-panes.txt"
CLAUDE_PROJECTS="${HOME}/.claude/projects"
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
matched_panes=""
while read -r tty rest; do
    [ -z "$tty" ] || [ "$tty" = "??" ] && continue
    full_tty="/dev/$tty"
    match=$(echo "$pane_info" | grep "|${full_tty}|" | head -1)
    [ -z "$match" ] && continue
    target=$(echo "$match" | cut -d'|' -f1)
    cwd=$(echo "$match" | cut -d'|' -f3)
    matched_panes="${matched_panes}${target}|${cwd}"$'\n'
done < <(ps -eo tty=,args= 2>/dev/null | awk '$2 == "claude"')

[ -z "$matched_panes" ] && : > "$MAPPING_FILE" && exit 0

# --- Count claudes per project dir to decide UUID strategy ---
# Claude encodes project paths: /Users/foo/.bar -> -Users-foo--bar
encode_project_path() {
    echo "$1" | sed 's|[/.]|-|g'
}

dir_counts=$(echo "$matched_panes" | grep -v '^$' | cut -d'|' -f2 | sort | uniq -c | awk '{print $1 "|" $2}')

# --- Write mapping with UUIDs where possible ---
: > "$MAPPING_FILE"
while IFS='|' read -r target cwd; do
    [ -z "$target" ] && continue
    uuid=""

    project_path=$(encode_project_path "$cwd")
    project_dir="${CLAUDE_PROJECTS}/${project_path}"

    if [ -d "$project_dir" ]; then
        count=$(echo "$dir_counts" | grep "|${cwd}$" | cut -d'|' -f1 | tr -d ' ')
        count=${count:-0}

        if [ "$count" -eq 1 ]; then
            # IMPORTANT: Single claude in this dir — most recently modified
            # .jsonl is definitively this session's UUID.
            uuid=$(ls -t "$project_dir"/*.jsonl 2>/dev/null | head -1 | xargs basename 2>/dev/null | sed 's/\.jsonl$//')
        fi
        # Multiple claudes in same dir: can't determine UUID reliably.
        # Falls back to --name tag matching on restore.
    fi

    echo "${target}|${cwd}|${uuid}" >> "$MAPPING_FILE"
done <<< "$matched_panes"
