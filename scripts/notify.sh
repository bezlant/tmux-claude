#!/usr/bin/env bash
# Notification popup for Claude Code hooks (TeammateIdle, TaskCompleted)
# Usage: notify.sh "Title" "Message body"

TITLE="${1:-Notification}"
BODY="${2:-}"

if [ -z "$TMUX" ]; then
    echo "$TITLE: $BODY"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

tmux display-popup -w 50% -h 25% -T " $TITLE " \
    -E "bash '$SCRIPT_DIR/notify-render.sh' $(printf '%q' "$BODY")"
