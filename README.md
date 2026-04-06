# tmux-claude

Better tmux integration for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) agent teams.

## Features

- **Dashboard popup** (`prefix + D`) — floating overlay showing the last few lines from every pane in the current window. Quick way to check what all teammates are doing without switching panes.
- **Auto-logging** (`prefix + Alt-l`) — captures all pane output to timestamped log files for post-mortem review.
- **Notification popups** — hook scripts for `TeammateIdle` and `TaskCompleted` events that show tmux popups.

## Requirements

- tmux >= 3.2 (for `display-popup` support)
- [TPM](https://github.com/tmux-plugins/tpm)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) v2.1.32+

## Installation

Add to your `.tmux.conf`:

```tmux
set -g @plugin 'bezlant/tmux-claude'
```

Then press `prefix + I` to install via TPM.

## Usage

### Dashboard

Press `prefix + D` to open a floating popup that shows the last 8 lines from every pane in the current window. Useful for monitoring teammate activity at a glance. Press `q` to dismiss.

### Auto-logging

Press `prefix + Alt-l` to start logging all panes in the current window. Logs are saved to `$TMPDIR/claude-team-logs/{timestamp}/` with one file per pane.

### Notification hooks

Configure Claude Code hooks in your `settings.json` to show tmux popups on team events:

```json
{
  "hooks": {
    "TeammateIdle": [
      {
        "command": "$TMUX_CLAUDE_SCRIPTS/notify.sh 'Teammate Idle' 'A teammate needs attention'"
      }
    ],
    "TaskCompleted": [
      {
        "command": "$TMUX_CLAUDE_SCRIPTS/notify.sh 'Task Done' 'A task was completed'"
      }
    ]
  }
}
```

The `$TMUX_CLAUDE_SCRIPTS` environment variable is set automatically by the plugin.

## Claude Code setup

Enable agent teams and tmux teammate mode:

```json
// ~/.claude.json
{
  "teammateMode": "tmux",
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

## License

MIT
