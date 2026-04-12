# tmux-claude:session-name
# Tags Claude Code sessions with tmux pane coordinates for crash recovery.
# Install: source this file from ~/.bashrc

claude() {
    local extra_args=()
    if [ -n "$TMUX" ]; then
        local skip=0
        for arg in "$@"; do
            case "$arg" in
                --name|--name=*|--resume|-r|--resume=*|--continue|-c|--continue=*|--print|-p)
                    skip=1; break ;;
            esac
        done
        if [ "$skip" -eq 0 ]; then
            local sess win pane
            sess=$(tmux display-message -p '#{session_name}' 2>/dev/null)
            win=$(tmux display-message -p '#{window_index}' 2>/dev/null)
            pane=$(tmux display-message -p '#{pane_index}' 2>/dev/null)
            if [ -n "$sess" ] && [ -n "$win" ] && [ -n "$pane" ]; then
                extra_args=(--name "$sess:$win.$pane")
            fi
        fi
    fi
    command claude "${extra_args[@]}" "$@"
}
