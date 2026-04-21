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

ps_output="ttys001  55588 claude --dangerously-skip-permissions --teammate-mode tmux
ttys002  12345 /bin/bash /Users/foo/.claude/statusline-simple.sh
ttys003  23456 node /opt/homebrew/bin/claude-limitline
ttys001  34567 fish -c claude --version
ttys004  45678 claude --resume abc123
??       56789 /bin/zsh -c source /Users/foo/.claude/shell-snapshots/snap.sh"

matched=$(echo "$ps_output" | awk '$3 == "claude"')

assert_contains "matches claude binary" "ttys001" "$matched"
assert_contains "matches claude --resume" "ttys004" "$matched"
assert_not_contains "rejects .claude/ paths" "statusline" "$matched"
assert_not_contains "rejects claude-limitline" "limitline" "$matched"
assert_not_contains "rejects shell-snapshots" "shell-snapshots" "$matched"
assert_not_contains "rejects fish -c claude" "fish" "$matched"

# ============================================================
echo ""
echo "=== session-save: PID file UUID extraction ==="
# ============================================================

tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/sessions"

# Valid PID file
echo '{"pid":12345,"sessionId":"aaaaaaaa-1111-2222-3333-444444444444","cwd":"/foo"}' > "$tmpdir/sessions/12345.json"
uuid=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['sessionId'])" "$tmpdir/sessions/12345.json" 2>/dev/null)
assert_eq "extracts UUID from PID file" "aaaaaaaa-1111-2222-3333-444444444444" "$uuid"

# Missing PID file
uuid=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['sessionId'])" "$tmpdir/sessions/99999.json" 2>/dev/null)
assert_eq "missing PID file returns empty" "" "$uuid"

# Malformed PID file
echo 'not json' > "$tmpdir/sessions/88888.json"
uuid=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['sessionId'])" "$tmpdir/sessions/88888.json" 2>/dev/null)
assert_eq "malformed PID file returns empty" "" "$uuid"

rm -rf "$tmpdir"

# ============================================================
echo ""
echo "=== session-restore: UUID-based resume ==="
# ============================================================

tmpdir=$(mktemp -d)
cat > "$tmpdir/claude-panes.txt" <<'EOF'
0:1.1|aaaaaaaa-1111-2222-3333-444444444444
0:2.1|bbbbbbbb-5555-6666-7777-888888888888
0:3.1|
EOF

cmds=""
while IFS='|' read -r target uuid; do
    [ -z "$target" ] && continue
    if [ -n "$uuid" ]; then
        cmds="${cmds}claude --resume '${uuid}'\n"
    else
        cmds="${cmds}claude --resume\n"
    fi
done < "$tmpdir/claude-panes.txt"

assert_contains "UUID pane gets direct resume" "claude --resume 'aaaaaaaa-1111-2222-3333-444444444444'" "$cmds"
assert_contains "second UUID pane gets direct resume" "claude --resume 'bbbbbbbb-5555-6666-7777-888888888888'" "$cmds"
assert_contains "no-UUID pane gets picker" "claude --resume" "$cmds"
assert_eq "exactly 3 commands" "3" "$(echo -e "$cmds" | grep -c 'claude --resume')"

rm -rf "$tmpdir"

# ============================================================
echo ""
echo "=== session-restore: empty/missing mapping file ==="
# ============================================================

tmpdir=$(mktemp -d)

result=$(bash -c "
    MAPPING_FILE='$tmpdir/claude-panes.txt'
    [ -f \"\$MAPPING_FILE\" ] || { echo 'skipped'; exit 0; }
    echo 'ran'
")
assert_eq "missing file -> skip" "skipped" "$result"

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
echo "=== session-save: autoprune ==="
# ============================================================

tmpdir=$(mktemp -d)
for i in $(seq -w 1 25); do
    touch "$tmpdir/tmux_resurrect_202604${i}T120000.txt"
done
assert_eq "25 files before prune" "25" "$(ls "$tmpdir"/tmux_resurrect_*.txt | wc -l | tr -d ' ')"

(cd "$tmpdir" && ls -t tmux_resurrect_*.txt 2>/dev/null | tail -n +21 | xargs rm -f 2>/dev/null)
assert_eq "20 files after prune" "20" "$(ls "$tmpdir"/tmux_resurrect_*.txt | wc -l | tr -d ' ')"

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
echo "=== fish wrapper: graceful degradation ==="
# ============================================================

if command -v fish &>/dev/null; then
    tmpbin=$(mktemp -d)
    printf '#!/bin/sh\necho "MOCK_ARGS: $@"\n' > "$tmpbin/claude"
    chmod +x "$tmpbin/claude"
    result=$(fish -c "
        set -gx PATH $tmpbin \$PATH
        set -gx TMUX '/tmp/test,1,0'
        functions -e __tmux_claude_session_args 2>/dev/null
        source $PLUGIN_DIR/shell/claude.fish
        claude --version
    " 2>/dev/null)
    rm -rf "$tmpbin"
    assert_contains "runs without helper" "MOCK_ARGS:" "$result"
    assert_not_contains "no --name when helper missing" "MOCK_ARGS: --name" "$result"

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
echo "=== claude.tmux: hook chaining ==="
# ============================================================

if [ -n "$TMUX" ]; then
    orig_save=$(tmux show-option -gqv @resurrect-hook-post-save-all 2>/dev/null)
    orig_restore=$(tmux show-option -gqv @resurrect-hook-post-restore-all 2>/dev/null)

    tmux set-option -g @resurrect-hook-post-save-all "echo existing-save" 2>/dev/null
    tmux set-option -g @resurrect-hook-post-restore-all "echo existing-restore" 2>/dev/null

    bash "$PLUGIN_DIR/claude.tmux" 2>/dev/null

    save_hook=$(tmux show-option -gqv @resurrect-hook-post-save-all 2>/dev/null)
    restore_hook=$(tmux show-option -gqv @resurrect-hook-post-restore-all 2>/dev/null)

    assert_contains "save hook chains existing" "echo existing-save" "$save_hook"
    assert_contains "save hook adds session-save" "session-save.sh" "$save_hook"
    assert_contains "restore hook chains existing" "echo existing-restore" "$restore_hook"
    assert_contains "restore hook adds session-restore" "session-restore.sh" "$restore_hook"

    # Restore originals before idempotency test
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

    bash "$PLUGIN_DIR/claude.tmux" 2>/dev/null
else
    echo "  SKIP: not in tmux"
fi

# ============================================================
echo ""
echo "=== claude.tmux: idempotent reload ==="
# ============================================================

if [ -n "$TMUX" ]; then
    orig_save=$(tmux show-option -gqv @resurrect-hook-post-save-all 2>/dev/null)
    orig_restore=$(tmux show-option -gqv @resurrect-hook-post-restore-all 2>/dev/null)

    # Start clean
    tmux set-option -gu @resurrect-hook-post-save-all 2>/dev/null
    tmux set-option -gu @resurrect-hook-post-restore-all 2>/dev/null

    # Load plugin twice (simulates prefix+I reload)
    bash "$PLUGIN_DIR/claude.tmux" 2>/dev/null
    bash "$PLUGIN_DIR/claude.tmux" 2>/dev/null

    save_hook=$(tmux show-option -gqv @resurrect-hook-post-save-all 2>/dev/null)
    restore_hook=$(tmux show-option -gqv @resurrect-hook-post-restore-all 2>/dev/null)

    save_count=$(echo "$save_hook" | grep -o 'session-save\.sh' | wc -l | tr -d ' ')
    restore_count=$(echo "$restore_hook" | grep -o 'session-restore\.sh' | wc -l | tr -d ' ')

    assert_eq "save hook appears exactly once after double load" "1" "$save_count"
    assert_eq "restore hook appears exactly once after double load" "1" "$restore_count"

    # Also test: reload preserves existing user hooks
    tmux set-option -gu @resurrect-hook-post-save-all 2>/dev/null
    tmux set-option -g @resurrect-hook-post-save-all "echo user-hook" 2>/dev/null
    bash "$PLUGIN_DIR/claude.tmux" 2>/dev/null
    bash "$PLUGIN_DIR/claude.tmux" 2>/dev/null
    save_hook=$(tmux show-option -gqv @resurrect-hook-post-save-all 2>/dev/null)
    save_count=$(echo "$save_hook" | grep -o 'session-save\.sh' | wc -l | tr -d ' ')
    assert_contains "user hook preserved after double load" "echo user-hook" "$save_hook"
    assert_eq "save hook once even with user hook + double load" "1" "$save_count"

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

    bash "$PLUGIN_DIR/claude.tmux" 2>/dev/null
else
    echo "  SKIP: not in tmux"
fi

# ============================================================
echo ""
echo "=== session-save: live PID file mapping ==="
# ============================================================

if [ -n "$TMUX" ] && [ -d "$HOME/.claude/sessions" ]; then
    # Count running claude processes
    claude_count=$(ps -eo args= | awk '$1 == "claude"' | wc -l | tr -d ' ')
    # Count PID files for running PIDs
    matched=0
    for pidfile in "$HOME/.claude/sessions"/*.json; do
        [ -f "$pidfile" ] || continue
        pid=$(basename "$pidfile" .json)
        if ps -p "$pid" > /dev/null 2>&1; then
            matched=$((matched + 1))
        fi
    done
    assert_eq "PID files exist for all running claudes" "$claude_count" "$matched"
else
    echo "  SKIP: not in tmux or no session dir"
fi

# ============================================================
echo ""
echo "=== Results ==="
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
[ "$FAIL" -eq 0 ] && green "  ALL TESTS PASSED" || red "  SOME TESTS FAILED"
exit "$FAIL"
