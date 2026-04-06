#!/usr/bin/env bash
# tmux-claude: Better tmux integration for Claude Code agent teams
# TPM-compatible plugin entry point

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Dashboard popup: prefix + d
tmux bind-key d run-shell "$CURRENT_DIR/scripts/dashboard.sh"

# Notification support: set environment so hooks can find our scripts
tmux set-environment -g TMUX_CLAUDE_SCRIPTS "$CURRENT_DIR/scripts"
