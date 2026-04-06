#!/usr/bin/env bash
# Notification popup for Claude Code hooks (TeammateIdle, TaskCompleted)
# Usage: notify.sh "Title" "Message body"
#
# Configure in Claude Code settings.json hooks:
#   "TeammateIdle": [{ "command": "$TMUX_CLAUDE_SCRIPTS/notify.sh 'Teammate Idle' '$CLAUDE_TEAMMATE_NAME is idle'" }]
#   "TaskCompleted": [{ "command": "$TMUX_CLAUDE_SCRIPTS/notify.sh 'Task Done' '$CLAUDE_TASK_SUBJECT completed'" }]

TITLE="${1:-Notification}"
BODY="${2:-}"

if [ -z "$TMUX" ]; then
    echo "$TITLE: $BODY"
    exit 0
fi

# Show a small popup in the center, auto-closes after 5 seconds
tmux display-popup -w 50% -h 25% -T " $TITLE " \
    -E "echo ''; echo '  $BODY'; echo ''; echo '  Press q to dismiss'; read -n1"
