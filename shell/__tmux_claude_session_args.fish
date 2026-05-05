# tmux-claude:session-name
# Returns --resume/--name args for pane-aware session resume.

function __tmux_claude_session_args
    test -z "$TMUX"; and return
    for arg in $argv
        switch $arg
            case --name '--name=*' --resume '-r' '--resume=*' --continue '-c' '--continue=*' --print '-p'
                return
        end
    end
    set -l wname (tmux display-message -p -t "$TMUX_PANE" '#{window_name}' 2>/dev/null)
    set -l pane_count (tmux display-message -p -t "$TMUX_PANE" '#{window_panes}' 2>/dev/null)
    set -l pane (tmux display-message -p -t "$TMUX_PANE" '#{pane_index}' 2>/dev/null)
    if test -n "$wname"
        set -l name $wname
        if test -n "$pane_count" -a "$pane_count" -gt 1 -a -n "$pane" 2>/dev/null
            set name "$wname.$pane"
        end
        set -l sid (__tmux_claude_find_session "$name" 2>/dev/null)
        if test -n "$sid"
            printf '%s\n' --resume "$sid" --name "$name"
        else
            printf '%s\n' --name "$name"
        end
    end
end
