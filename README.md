# tmux-claude

tmux plugin for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and [Codex](https://openai.com/index/introducing-codex/) session save/restore.

## Requirements

- tmux >= 3.2
- [TPM](https://github.com/tmux-plugins/tpm)
- [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- SessionStart hooks that write pane variables (see below)

## Install

```tmux
set -g @plugin 'bezlant/tmux-claude'
```

`prefix + I` to install.

### SessionStart hooks (required)

The plugin reads `@claude_session_id` and `@codex_session_id` tmux pane variables to map sessions. These are set by SessionStart hooks.

**Claude Code** (`~/.claude/settings.json`):
```json
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "bash ~/.claude/hooks/tmux-session-tracker.sh"
      }]
    }]
  }
}
```

**Codex** (`~/.codex/hooks.json`):
```json
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "bash ~/.config/codex/bin/tmux-session-tracker.sh"
      }]
    }]
  }
}
```

Each hook reads `session_id` and `cwd` from the JSON stdin, writes them to tmux pane variables, and clears the other tool's variables (handles pane reuse).

### Shell wrapper (optional)

Auto-resumes Claude sessions by window name. On launch it finds the previous session for that pane and passes `--resume <uuid>`:

```sh
# Fish
cp ~/.config/tmux/plugins/tmux-claude/shell/__tmux_claude_session_args.fish ~/.config/fish/functions/
cp ~/.config/tmux/plugins/tmux-claude/shell/__tmux_claude_find_session.fish ~/.config/fish/functions/

# Bash (add to ~/.bashrc)
source ~/.config/tmux/plugins/tmux-claude/shell/claude.bash

# Zsh (add to ~/.zshrc)
source ~/.config/tmux/plugins/tmux-claude/shell/claude.zsh
```

## Features

### Session save/restore

Automatically saves which panes run Claude/Codex/nvim/just and restores them after reboot.

**How it works:**

1. `prefix + S` (resurrect save) triggers the post-save hook which records all pane→session mappings
2. `prefix + R` (resurrect restore) triggers the post-restore hook which sends resume commands to each pane

**Mapping format:** `session:window.pane|tool|session_id|cwd|window_name`

**Tools supported:**
- `claude` → `ccy --resume <uuid>` (direct resume, no picker)
- `codex` → `cxy resume <uuid>` (direct resume when hook has fired)
- `nvim` → `nvim`
- `just` → `just <recipe>`

**Safety:**
- Atomic save (temp file + mv) — partial saves can't corrupt the mapping
- Zero-pane enumeration preserves the previous mapping instead of clobbering it
- Hooks clear stale pane variables when a pane switches between Claude and Codex

**Manual usage:**

```bash
# Save current state
bash ~/.config/tmux/plugins/tmux-claude/scripts/session-save.sh

# Preview restore commands
bash ~/.config/tmux/plugins/tmux-claude/scripts/session-restore.sh --dry-run

# Restore
bash ~/.config/tmux/plugins/tmux-claude/scripts/session-restore.sh
```

**Prunes old resurrect files** — keeps the last 20 saves by default:

```tmux
set-environment -g TMUX_CLAUDE_MAX_SAVES 30
```

## Configuration

| Option | Default | Description |
|--------|---------|-------------|
| `@tmux-claude-auto-install-wrapper` | `on` | Set to `off` to skip shell wrapper install |
| `TMUX_CLAUDE_MAX_SAVES` | `20` | Max resurrect save files to keep |

## License

MIT
