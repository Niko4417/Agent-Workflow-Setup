#!/usr/bin/env bash
#
# ready-gate.sh — block marking a USER-FACING PR "ready for review" until its
# Playwright test-plan comment is posted on the PR.
#
# The ui-verify RUN (a real Playwright pass) is already enforced at PR-create by
# audit-gate; this enforces the DOCUMENTATION comment at the human handoff, which
# is the only point a ->dev PR is checked (a human, not an agent, merges it). For
# ->epic PRs the same comment is enforced at the child->epic auto-merge instead, so
# those never reach `gh pr ready`.
#
# Fires via a PreToolUse hook on `gh pr ready`; receives the command to resolve the
# PR number. exit 0 = ok / not applicable, exit 1 = blocked.

set -uo pipefail

cmd="${1:-}"
marker="keiko:manual-test-plan"

branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo)"
case "$branch" in
  issue/*|epic/*) ;;
  *) exit 0 ;;
esac

gd="$(git rev-parse --git-dir 2>/dev/null)"
slug="$(printf '%s' "$branch" | tr '/' '_')"
receipt="$gd/keiko-audit/$slug.json"
# No audit receipt yet -> audit-gate handles that at create; nothing to enforce here.
[ -f "$receipt" ] || exit 0

user_facing="$(sed -n 's/.*"user_facing":"\([^"]*\)".*/\1/p' "$receipt")"
# Only user-facing PRs need the documented test plan.
[ "$user_facing" = "true" ] || exit 0

prnum="$(printf '%s' "$cmd" | grep -oE 'ready[[:space:]]+[0-9]+' | grep -oE '[0-9]+' || true)"
if [ -n "$prnum" ]; then
  comments="$(gh pr view "$prnum" --json comments -q '.comments[].body' 2>/dev/null || true)"
else
  comments="$(gh pr view --json comments -q '.comments[].body' 2>/dev/null || true)"
fi

if ! printf '%s' "$comments" | grep -q "$marker"; then
  printf '[ready-gate] BLOCKED: user-facing PR has no manual-test-plan comment (<!-- %s -->). Post the Playwright test plan before marking it ready for review.\n' "$marker" >&2
  exit 1
fi

printf '[ready-gate] OK: user-facing test-plan comment present.\n'
exit 0
