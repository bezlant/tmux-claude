# tmux-claude

tmux plugin for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) agent teams.

Requires tmux >= 3.2 and [TPM](https://github.com/tmux-plugins/tpm).

## Install

```tmux
set -g @plugin 'bezlant/tmux-claude'
```

`prefix + I` to install.

## Features

### Dashboard popup

`prefix + d` opens a floating popup showing the last few lines from every pane in the current window. Useful for checking what all teammates are doing without switching panes. Press `q` to dismiss.

### Auto-logging

Log all teammate pane output to files for post-mortem review:

```bash
~/.config/tmux/plugins/tmux-claude/scripts/log-panes.sh
```

Logs are saved to `$TMPDIR/claude-team-logs/{timestamp}/` with one file per pane.

### Notification popups

Add to Claude Code `settings.json` for teammate event notifications:

```json
{
  "hooks": {
    "TeammateIdle": [{ "command": "$TMUX_CLAUDE_SCRIPTS/notify.sh 'Idle' 'Teammate needs attention'" }],
    "TaskCompleted": [{ "command": "$TMUX_CLAUDE_SCRIPTS/notify.sh 'Done' 'Task completed'" }]
  }
}
```

`$TMUX_CLAUDE_SCRIPTS` is set automatically by the plugin.

## Claude Code setup

Enable agent teams and tmux teammate mode in `~/.claude.json`:

```json
{
  "teammateMode": "tmux",
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

## License

MIT
