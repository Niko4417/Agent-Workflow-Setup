# implementor memory

- 2026-06-15 — Bash: `((PASS++))` returns non-zero when the pre-increment value is 0, so under `set -e` it aborts the script. Use `PASS=$((PASS + 1))` instead. (Hit while writing `tests/test-worktree-hook.sh`.)
- Memory path is `.agents/memory/<role>/` (canonical), NOT `.claude/agent-memory/<role>/` (legacy — writes there are stray and get cleaned up).
