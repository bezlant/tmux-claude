# tmux-claude: helper that returns --name args for session tagging.
# Called by claude.fish wrappers (both plugin's and user's custom).

function __tmux_claude_session_args
    test -z "$TMUX"; and return
    for arg in $argv
        switch $arg
            case --name '--name=*' --resume '-r' '--resume=*' --continue '-c' '--continue=*' --print '-p'
                return
        end
    end
    set -l sess (tmux display-message -p '#{session_name}' 2>/dev/null)
    set -l win (tmux display-message -p '#{window_index}' 2>/dev/null)
    set -l pane (tmux display-message -p '#{pane_index}' 2>/dev/null)
    test -n "$sess" -a -n "$win" -a -n "$pane"; and echo -- --name "$sess:$win.$pane"
end
