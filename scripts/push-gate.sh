#!/usr/bin/env bash
#
# push-gate.sh — re-run the QA gates when pushing a fix onto an OPEN PR that
# targets `dev`.
#
# `-> dev` PRs are the ones with GitHub CI, so they're the ones with a
# watch-CI-then-fix-then-repush loop (pr-shepherd / keiko-issue / keiko-epic), and
# the ones a human tells the agent to fix after an external review. GitHub CI
# re-runs verify on each push, but NOT the keiko audit or the ui-verify Playwright
# plan — so a repush must re-qualify those locally before it lands.
#
# It delegates to verify-gate + audit-gate (same checks as PR-open) at the new
# HEAD, so there is no duplicated logic. Pre-PR pushes and non-`dev` PRs (e.g.
# child -> epic) pass through untouched.
#
# Fires via a PreToolUse hook on `git push`. exit 0 = ok / n-a, exit 1 = blocked.

set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd -P)"

branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo)"
case "$branch" in
  issue/*|epic/*) ;;
  *) exit 0 ;;
esac

# Only gate when this branch has an OPEN PR whose base is dev.
info="$(gh pr view --json state,baseRefName 2>/dev/null || true)"
[ -n "$info" ] || exit 0     # no PR yet -> pre-PR WIP push, free
state="$(printf '%s' "$info" | sed -n 's/.*"state":"\([^"]*\)".*/\1/p')"
base="$(printf '%s' "$info" | sed -n 's/.*"baseRefName":"\([^"]*\)".*/\1/p')"
{ [ "$state" = "OPEN" ] && [ "$base" = "dev" ]; } || exit 0

# Re-apply the PR-open QA at the current HEAD by delegating to the existing gates.
if ! "$here/verify-gate.sh"; then
  printf '[push-gate] fix push blocked — verify not green at HEAD. Re-run verify-receipt.sh before repushing to the ->dev PR.\n' >&2
  exit 1
fi
if ! "$here/audit-gate.sh"; then
  printf '[push-gate] fix push blocked — audit not clean at HEAD. Re-run keiko-issue-audit (+ ui-verify when user-facing) before repushing to the ->dev PR.\n' >&2
  exit 1
fi

# A user-facing fix changes the UI, so its sha-bound test-plan comment must be
# reposted for the new commit (the automated ui-verify already re-ran via audit-gate).
gd="$(git rev-parse --git-dir 2>/dev/null)"
slug="$(printf '%s' "$branch" | tr '/' '_')"
head="$(git rev-parse HEAD 2>/dev/null)"
user_facing="$(sed -n 's/.*"user_facing":"\([^"]*\)".*/\1/p' "$gd/keiko-audit/$slug.json" 2>/dev/null || true)"
if [ "$user_facing" = "true" ]; then
  comments="$(gh pr view --json comments -q '.comments[].body' 2>/dev/null || true)"
  if ! printf '%s' "$comments" | grep -q "keiko:manual-test-plan sha=$head"; then
    printf '[push-gate] fix push blocked — repost the manual-test-plan comment for the new commit (<!-- keiko:manual-test-plan sha=%s -->).\n' "$head" >&2
    exit 1
  fi
fi

printf '[push-gate] OK: verify + clean audit at HEAD for the ->dev PR update.\n'
exit 0
