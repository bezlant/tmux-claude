# tmux-claude:session-name
# Finds a Claude Code session ID by matching its original customTitle.

function __tmux_claude_find_session
    set -l target $argv[1]
    set -l project_dir "$HOME/.claude/projects/"(pwd | tr '/.' '--')

    test -d "$project_dir"; or return

    python3 -c "
import os, sys

d, target = sys.argv[1], sys.argv[2]
target_b = ('\"' + target + '\"').encode()
files = []
for f in os.listdir(d):
    if f.endswith('.jsonl'):
        fp = os.path.join(d, f)
        files.append((os.path.getmtime(fp), fp, f))
files.sort(reverse=True)

for _, fp, fname in files:
    with open(fp, 'rb') as fh:
        for raw in fh:
            if b'\"custom-title\"' in raw:
                if target_b in raw:
                    print(fname[:-6])
                    sys.exit(0)
                break
" "$project_dir" "$target" 2>/dev/null
end
