#!/usr/bin/env bash
# tmux-claude test runner
# Usage: bash tests/run.sh

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$TESTS_DIR")"
PASS=0
FAIL=0

red() { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        green "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        red "  FAIL: $desc"
        red "    expected: $expected"
        red "    actual:   $actual"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        green "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        red "  FAIL: $desc"
        red "    expected to contain: $needle"
        red "    actual: $haystack"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if ! echo "$haystack" | grep -qF "$needle"; then
        green "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        red "  FAIL: $desc"
        red "    expected NOT to contain: $needle"
        red "    actual: $haystack"
        FAIL=$((FAIL + 1))
    fi
}

# ============================================================
echo "=== session-save: process matching ==="
# ============================================================

# Simulate ps output and test awk filter
ps_output="ttys001  claude --dangerously-skip-permissions --teammate-mode tmux
ttys002  /bin/bash /Users/foo/.claude/statusline-simple.sh
ttys003  node /opt/homebrew/bin/claude-limitline
ttys001  fish -c claude --version
ttys004  claude --resume abc123
??       /bin/zsh -c source /Users/foo/.claude/shell-snapshots/snap.sh"

matched=$(echo "$ps_output" | awk '$2 == "claude"')

assert_contains "matches claude binary" "ttys001" "$matched"
assert_contains "matches claude --resume" "ttys004" "$matched"
assert_not_contains "rejects .claude/ paths" "statusline" "$matched"
assert_not_contains "rejects claude-limitline" "limitline" "$matched"
assert_not_contains "rejects shell-snapshots" "shell-snapshots" "$matched"
assert_not_contains "rejects fish -c claude" "fish" "$matched"

# ============================================================
echo ""
echo "=== session-restore: mapping file parsing ==="
# ============================================================

tmpdir=$(mktemp -d)
cat > "$tmpdir/claude-panes.txt" <<'EOF'
0:1.1|/Users/foo/project-a
0:2.1|/Users/foo/project-b
0:3.1|/Users/foo/project-a
EOF

# Simulate restore logic
cmds=""
while IFS='|' read -r target cwd; do
    [ -z "$target" ] && continue
    cmds="${cmds}claude --resume '${target}'\n"
done < "$tmpdir/claude-panes.txt"

assert_contains "pane 1 resumes by name" "claude --resume '0:1.1'" "$cmds"
assert_contains "pane 2 resumes by name" "claude --resume '0:2.1'" "$cmds"
assert_contains "pane 3 resumes by name" "claude --resume '0:3.1'" "$cmds"
assert_eq "exactly 3 commands" "3" "$(echo -e "$cmds" | grep -c 'claude --resume')"

rm -rf "$tmpdir"

# ============================================================
echo ""
echo "=== session-restore: multiple panes same project dir ==="
# ============================================================

tmpdir=$(mktemp -d)
cat > "$tmpdir/claude-panes.txt" <<'EOF'
main:0.0|/Users/foo/monorepo
main:0.1|/Users/foo/monorepo
main:1.0|/Users/foo/monorepo
EOF

cmds=""
while IFS='|' read -r target cwd; do
    [ -z "$target" ] && continue
    cmds="${cmds}claude --resume '${target}'\n"
done < "$tmpdir/claude-panes.txt"

assert_contains "first pane gets own name" "claude --resume 'main:0.0'" "$cmds"
assert_contains "second pane gets own name" "claude --resume 'main:0.1'" "$cmds"
assert_contains "third pane gets own name" "claude --resume 'main:1.0'" "$cmds"
assert_eq "3 distinct commands for same-dir panes" "3" "$(echo -e "$cmds" | grep -c 'claude --resume')"

rm -rf "$tmpdir"

# ============================================================
echo ""
echo "=== session-restore: blank lines and whitespace in mapping ==="
# ============================================================

tmpdir=$(mktemp -d)
# Blank lines, trailing newlines — should be skipped gracefully
printf '0:0.0|/Users/foo/project\n\n\n0:1.0|/Users/foo/other\n' > "$tmpdir/claude-panes.txt"

cmds=""
while IFS='|' read -r target cwd; do
    [ -z "$target" ] && continue
    cmds="${cmds}claude --resume '${target}'\n"
done < "$tmpdir/claude-panes.txt"

assert_eq "blank lines skipped, exactly 2 commands" "2" "$(echo -e "$cmds" | grep -c 'claude --resume')"

rm -rf "$tmpdir"

# ============================================================
echo ""
echo "=== session-restore: special chars in session name ==="
# ============================================================

tmpdir=$(mktemp -d)
# Session names can contain hyphens, underscores, dots
cat > "$tmpdir/claude-panes.txt" <<'EOF'
my-session_2:3.1|/Users/foo/project
work.dotfiles:0.0|/Users/foo/.config
EOF

cmds=""
while IFS='|' read -r target cwd; do
    [ -z "$target" ] && continue
    cmds="${cmds}claude --resume '${target}'\n"
done < "$tmpdir/claude-panes.txt"

assert_contains "hyphen/underscore session name" "claude --resume 'my-session_2:3.1'" "$cmds"
assert_contains "dotted session name" "claude --resume 'work.dotfiles:0.0'" "$cmds"

rm -rf "$tmpdir"

# ============================================================
echo ""
echo "=== fish wrapper: skip flag detection ==="
# ============================================================

if command -v fish &>/dev/null; then
    test_skip() {
        local flags="$1" expected="$2"
        local result
        result=$(fish -c "
            source $PLUGIN_DIR/shell/__tmux_claude_session_args.fish
            set -gx TMUX '/tmp/test,1,0'
            # Mock tmux to return predictable values
            function tmux
                switch \$argv[3]
                    case '#{session_name}'; echo test
                    case '#{window_index}'; echo 0
                    case '#{pane_index}'; echo 1
                end
            end
            set result (__tmux_claude_session_args $flags)
            test -n \"\$result\"; and echo 'injected'; or echo 'skipped'
        " 2>/dev/null)
        assert_eq "flags '$flags' -> $expected" "$expected" "$result"
    }

    test_skip "" "injected"
    test_skip "--dangerously-skip-permissions" "injected"
    test_skip "--teammate-mode tmux" "injected"
    test_skip "--resume abc" "skipped"
    test_skip "-r abc" "skipped"
    test_skip "--continue" "skipped"
    test_skip "-c" "skipped"
    test_skip "--print" "skipped"
    test_skip "-p" "skipped"
    test_skip "--name custom" "skipped"
else
    echo "  SKIP: fish not installed"
fi

# ============================================================
echo ""
echo "=== fish wrapper: no helper installed (graceful degradation) ==="
# ============================================================

if command -v fish &>/dev/null; then
    tmpbin=$(mktemp -d)
    printf '#!/bin/sh\necho "MOCK_ARGS: $@"\n' > "$tmpbin/claude"
    chmod +x "$tmpbin/claude"
    result=$(fish -c "
        set -gx PATH $tmpbin \$PATH
        set -gx TMUX '/tmp/test,1,0'
        # Don't source the helper — simulate it not being installed
        functions -e __tmux_claude_session_args 2>/dev/null
        source $PLUGIN_DIR/shell/claude.fish
        claude --version
    " 2>/dev/null)
    rm -rf "$tmpbin"
    assert_contains "runs without helper" "MOCK_ARGS:" "$result"
    assert_not_contains "no --name when helper missing" "MOCK_ARGS: --name" "$result"
else
    echo "  SKIP: fish not installed"
fi

# ============================================================
echo ""
echo "=== fish wrapper: outside tmux (no injection) ==="
# ============================================================

if command -v fish &>/dev/null; then
    result=$(fish -c "
        source $PLUGIN_DIR/shell/__tmux_claude_session_args.fish
        set -e TMUX 2>/dev/null
        set result (__tmux_claude_session_args --version)
        test -n \"\$result\"; and echo 'injected'; or echo 'skipped'
    " 2>/dev/null)
    assert_eq "no injection outside tmux" "skipped" "$result"
else
    echo "  SKIP: fish not installed"
fi

# ============================================================
echo ""
echo "=== session-save: autoprune ==="
# ============================================================

tmpdir=$(mktemp -d)
# Create 25 fake resurrect files
for i in $(seq -w 1 25); do
    touch "$tmpdir/tmux_resurrect_202604${i}T120000.txt"
done
assert_eq "25 files before prune" "25" "$(ls "$tmpdir"/tmux_resurrect_*.txt | wc -l | tr -d ' ')"

# Prune keeping 20 (run in subshell to avoid cd side effects)
(cd "$tmpdir" && ls -t tmux_resurrect_*.txt 2>/dev/null | tail -n +21 | xargs rm -f 2>/dev/null)
assert_eq "20 files after prune" "20" "$(ls "$tmpdir"/tmux_resurrect_*.txt | wc -l | tr -d ' ')"

rm -rf "$tmpdir"

# ============================================================
echo ""
echo "=== session-restore: empty/missing mapping file ==="
# ============================================================

tmpdir=$(mktemp -d)

# No file at all
result=$(RESURRECT_DIR="$tmpdir" bash -c '
    MAPPING_FILE="$RESURRECT_DIR/claude-panes.txt"
    [ -f "$MAPPING_FILE" ] || { echo "skipped"; exit 0; }
    echo "ran"
')
assert_eq "missing file -> skip" "skipped" "$result"

# Empty file
touch "$tmpdir/claude-panes.txt"
result=$(bash -c "
    MAPPING_FILE='$tmpdir/claude-panes.txt'
    [ -f \"\$MAPPING_FILE\" ] || { echo 'skipped'; exit 0; }
    [ -s \"\$MAPPING_FILE\" ] || { echo 'skipped-empty'; exit 0; }
    echo 'ran'
")
assert_eq "empty file -> skip" "skipped-empty" "$result"

rm -rf "$tmpdir"

# ============================================================
echo ""
echo "=== claude.tmux: hook chaining ==="
# ============================================================

if [ -n "$TMUX" ]; then
    # Save current values
    orig_save=$(tmux show-option -gqv @resurrect-hook-post-save-all 2>/dev/null)
    orig_restore=$(tmux show-option -gqv @resurrect-hook-post-restore-all 2>/dev/null)

    # Clear and set a fake existing hook
    tmux set-option -g @resurrect-hook-post-save-all "echo existing-save" 2>/dev/null
    tmux set-option -g @resurrect-hook-post-restore-all "echo existing-restore" 2>/dev/null

    # Run plugin entry point
    bash "$PLUGIN_DIR/claude.tmux" 2>/dev/null

    save_hook=$(tmux show-option -gqv @resurrect-hook-post-save-all 2>/dev/null)
    restore_hook=$(tmux show-option -gqv @resurrect-hook-post-restore-all 2>/dev/null)

    assert_contains "save hook chains existing" "echo existing-save" "$save_hook"
    assert_contains "save hook adds session-save" "session-save.sh" "$save_hook"
    assert_contains "restore hook chains existing" "echo existing-restore" "$restore_hook"
    assert_contains "restore hook adds session-restore" "session-restore.sh" "$restore_hook"

    # Restore originals
    if [ -n "$orig_save" ]; then
        tmux set-option -g @resurrect-hook-post-save-all "$orig_save" 2>/dev/null
    else
        tmux set-option -gu @resurrect-hook-post-save-all 2>/dev/null
    fi
    if [ -n "$orig_restore" ]; then
        tmux set-option -g @resurrect-hook-post-restore-all "$orig_restore" 2>/dev/null
    else
        tmux set-option -gu @resurrect-hook-post-restore-all 2>/dev/null
    fi

    # Re-run plugin to restore correct hooks
    bash "$PLUGIN_DIR/claude.tmux" 2>/dev/null
else
    echo "  SKIP: not in tmux"
fi

# ============================================================
echo ""
echo "=== Results ==="
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
[ "$FAIL" -eq 0 ] && green "  ALL TESTS PASSED" || red "  SOME TESTS FAILED"
exit "$FAIL"
