#!/usr/bin/env bash
# SHA-bound evidence describes committed bytes only, never a dirty tracked tree.
set -uo pipefail
if ! dirty="$(git status --porcelain --untracked-files=no 2>/dev/null)"; then
  printf '[proof-worktree] BLOCKED: cannot establish tracked worktree state.\n' >&2
  exit 1
fi
if [ -n "$dirty" ]; then
  printf '[proof-worktree] BLOCKED: tracked edits must be committed before proof creation or consumption.\n' >&2
  exit 1
fi
