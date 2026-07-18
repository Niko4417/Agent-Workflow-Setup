#!/usr/bin/env bash
#
# self-update.sh — keep the Agent-Workflow-Setup PRIMARY checkout current on `main`
# so the operator's symlinked skills/gates always reflect merged remote `main`.
#
# Wired into SessionStart (Claude + Codex). Deliberately conservative and non-fatal:
# it fast-forwards `main` ONLY when the primary checkout is on a clean `main`, so an
# in-progress edit worktree (see edit-worktree.sh) is never disturbed and a dirty tree
# is never clobbered. Any failure (offline, no remote) is swallowed — a session must
# never be blocked by this.

set -uo pipefail

# Resolve this script's real directory through symlinks -> the workflow repo root
# (the target repo reaches it as .keiko-scripts/self-update.sh, a symlink).
src="${BASH_SOURCE[0]}"
while [ -L "$src" ]; do
  dir="$(cd -P "$(dirname "$src")" && pwd)"
  src="$(readlink "$src")"
  case "$src" in /*) ;; *) src="$dir/$src" ;; esac
done
root="$(cd -P "$(dirname "$src")/.." && pwd)"

cd "$root" 2>/dev/null || exit 0

# Only self-update a clean primary checkout that is on `main`. Never touch WIP.
[ "$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" = "main" ] || exit 0
[ -z "$(git status --porcelain 2>/dev/null)" ] || exit 0

git pull --ff-only --quiet origin main 2>/dev/null || true
exit 0
