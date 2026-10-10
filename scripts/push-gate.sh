#!/usr/bin/env bash
#
# push-gate.sh — require fresh local QA before updating any open work-branch PR.
# Explicit successful empty GitHub PR inventory permits a pre-PR WIP push.
# API errors, malformed responses, and multiple open PRs fail closed. Child
# updates into an epic receive the same verify/audit/UI checks as dev updates.

set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd -P)"

branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo)"
case "$branch" in
  issue/*|epic/*|codex/*) ;;
  *) exit 0 ;;
esac

# A failed lookup is not proof that a branch has no PR. Query the explicit list;
# only a successful empty result permits a pre-PR WIP push.
if ! info="$(gh pr list --head "$branch" --state open --json state,baseRefName 2>/dev/null)"; then
  printf '[push-gate] BLOCKED: cannot establish open PR state.\n' >&2
  exit 1
fi
if ! printf '%s' "$info" | jq -e 'type == "array" and all(.[]; .state == "OPEN" and (.baseRefName | type == "string"))' >/dev/null 2>&1; then
  printf '[push-gate] BLOCKED: malformed open PR lookup.\n' >&2
  exit 1
fi
[ "$(printf '%s' "$info" | jq 'length')" = 0 ] && exit 0
[ "$(printf '%s' "$info" | jq 'length')" = 1 ] || {
  printf '[push-gate] BLOCKED: ambiguous multiple open PRs.\n' >&2
  exit 1
}

# Re-apply the PR-open QA at the current HEAD by delegating to the existing gates.
if ! "$here/verify-gate.sh"; then
  printf '[push-gate] fix push blocked — verify not green at HEAD. Re-run verify-receipt.sh before repushing to the delivery PR.\n' >&2
  exit 1
fi
if ! "$here/audit-gate.sh"; then
  printf '[push-gate] fix push blocked — audit not clean at HEAD. Re-run keiko-issue-audit (+ ui-verify when user-facing) before repushing to the delivery PR.\n' >&2
  exit 1
fi

# A user-facing fix changes the UI, so its sha-bound test-plan comment must be
# reposted for the new commit (the automated ui-verify already re-ran via audit-gate).
here="$(cd "$(dirname "$0")" && pwd -P)"
bash "$here/proof-worktree.sh" || exit 1

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

printf '[push-gate] OK: verify + clean audit at HEAD for the delivery PR update.\n'
exit 0
