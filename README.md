# tmux-claude

tmux plugin for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) agent teams.

Requires tmux >= 3.2 and [TPM](https://github.com/tmux-plugins/tpm).

## Install

```tmux
set -g @plugin 'bezlant/tmux-claude'
```

`prefix + I` to install.

## Keybindings

| Key | Action |
|-----|--------|
| `prefix + D` | Dashboard popup — last lines from every pane |
| `prefix + Alt-l` | Start logging all panes to `$TMPDIR/claude-team-logs/` |

## Hooks

Add to Claude Code `settings.json` for teammate notifications:

```json
{
  "hooks": {
    "TeammateIdle": [{ "command": "$TMUX_CLAUDE_SCRIPTS/notify.sh 'Idle' 'Teammate idle'" }],
    "TaskCompleted": [{ "command": "$TMUX_CLAUDE_SCRIPTS/notify.sh 'Done' 'Task completed'" }]
  }
}
```

## License

MIT
