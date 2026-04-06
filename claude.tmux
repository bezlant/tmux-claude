#!/usr/bin/env bash
# tmux-claude: Better tmux integration for Claude Code agent teams
# TPM-compatible plugin entry point

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Dashboard popup: prefix + D
tmux bind-key D run-shell "$CURRENT_DIR/scripts/dashboard.sh"

# Auto-logging: enable pipe-pane logging for all panes in current window
# Can be triggered manually or via hook
tmux bind-key M-l run-shell "$CURRENT_DIR/scripts/log-panes.sh"

# Notification support: set environment so hooks can find our scripts
tmux set-environment -g TMUX_CLAUDE_SCRIPTS "$CURRENT_DIR/scripts"
