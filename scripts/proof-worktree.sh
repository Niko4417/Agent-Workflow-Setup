#!/usr/bin/env bash
# SHA-bound evidence describes committed bytes only, never dirty or untracked implementation.
set -uo pipefail
if ! dirty="$(git status --porcelain --untracked-files=normal 2>/dev/null)"; then
  printf '[proof-worktree] BLOCKED: cannot establish worktree state.\n' >&2
  exit 1
fi
if [ -n "$dirty" ]; then
  printf '[proof-worktree] BLOCKED: tracked edits and non-ignored untracked files must be committed before proof creation or consumption.\n' >&2
  exit 1
fi
