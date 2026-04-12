# tmux-claude

tmux plugin for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) agent teams.

## Requirements

- tmux >= 3.2
- [TPM](https://github.com/tmux-plugins/tpm)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI

### Optional (for session restore)

- [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) — save/restore tmux sessions
- [tmux-continuum](https://github.com/tmux-plugins/tmux-continuum) — auto-save every N minutes

## Install

```tmux
set -g @plugin 'bezlant/tmux-claude'
```

`prefix + I` to install.

### Shell wrapper (recommended)

The shell wrapper tags each Claude Code session with its tmux pane coordinates, enabling automatic session restore after a crash. Install for your shell:

**Fish:**
```sh
cp ~/.config/tmux/plugins/tmux-claude/shell/claude.fish ~/.config/fish/functions/claude.fish
```

**Bash** (add to `~/.bashrc`):
```sh
source ~/.config/tmux/plugins/tmux-claude/shell/claude.bash
```

**Zsh** (add to `~/.zshrc`):
```sh
source ~/.config/tmux/plugins/tmux-claude/shell/claude.zsh
```

If you have an existing `claude` wrapper, add the `--name` injection from `shell/claude.fish` (or `.bash`/`.zsh`) to it. Look for the `# tmux-claude:session-name` marker.

## Features

### Dashboard popup

`prefix + d` opens a floating popup showing the last few lines from every pane in the current window. Useful for checking what all teammates are doing without switching panes. Press `q` to dismiss.

### Session save/restore

Automatically saves which tmux panes are running Claude Code and restores them after a crash. Requires [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect).

**How it works:**

1. After every resurrect save (`prefix + S` or continuum auto-save), the plugin records which panes are running Claude Code and their working directories.
2. For panes with a single Claude process per project directory, the session UUID is saved for direct resume (no picker).
3. For panes with multiple Claude processes in the same directory (agent teams), it falls back to name-based matching via the shell wrapper.
4. After `prefix + R` (restore), each pane that had Claude Code gets `claude --resume` sent automatically.

**Also prunes old resurrect files** — keeps the last 20 saves by default. Configure with:

```tmux
set-environment -g TMUX_CLAUDE_MAX_SAVES 30
```

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

## Configuration

| Option | Default | Description |
|--------|---------|-------------|
| `@tmux-claude-auto-install-wrapper` | `on` | Set to `off` to skip shell wrapper installation hints |
| `TMUX_CLAUDE_MAX_SAVES` | `20` | Max resurrect save files to keep |

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
