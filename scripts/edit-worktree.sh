#!/usr/bin/env bash
#
# edit-worktree.sh — create/enter an isolated git worktree for editing this repo, so
# the PRIMARY checkout stays permanently on `main` (the branch the operator's symlinked
# skills/gates read from). NEVER edit skills/gates in the primary checkout — a WIP
# branch there would leak unmerged work into live sessions.
#
# Usage:
#   scripts/edit-worktree.sh <branch-name>     # prints the worktree path; cd into it
#   cd "$(scripts/edit-worktree.sh feat/foo)"  # one-liner
#
# Worktrees live under ${AWS_WORKTREES:-<repo-parent>/.aws-worktrees}. Each is a normal
# checkout of a fresh branch off origin/main — edit, commit, push, and open the PR from
# there. After merge, the primary checkout self-updates on the next session start
# (self-update.sh) or via `git -C <primary> pull --ff-only`.

set -euo pipefail

branch="${1:?usage: edit-worktree.sh <branch-name>}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
wt_root="${AWS_WORKTREES:-$(cd "$root/.." && pwd)/.aws-worktrees}"
slug="$(printf '%s' "$branch" | tr '/' '_')"
path="$wt_root/$slug"

mkdir -p "$wt_root"
git -C "$root" fetch --quiet origin main || true

if git -C "$root" worktree list --porcelain | grep -qxF "worktree $path"; then
  echo "$path"
  exit 0
fi

git -C "$root" worktree add -b "$branch" "$path" origin/main >&2
echo "$path"
