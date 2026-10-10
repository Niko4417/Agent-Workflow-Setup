#!/usr/bin/env bash
#
# verify-gate.sh — deterministic proof-of-verify check before a PR.
#
# Passes (exit 0) only when a verify receipt exists for the current branch AND it
# was taken against the current HEAD. Enforced on issue/*, epic/*, and codex/* branches;
# other branches pass through. Used by the PR PreToolUse hook (gh pr create/ready)
# and runnable by hand from the target repo root.
#
#   exit 0 = ok / not applicable      exit 1 = blocked (no receipt or stale)

set -uo pipefail

branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo)"
case "$branch" in
  issue/*|epic/*|codex/*) ;;
  *) exit 0 ;;
esac

here="$(cd "$(dirname "$0")" && pwd -P)"
bash "$here/proof-worktree.sh" || exit 1

gd="$(git rev-parse --git-dir 2>/dev/null)"
slug="$(printf '%s' "$branch" | tr '/' '_')"
receipt="$gd/keiko-verify/$slug.json"
head="$(git rev-parse HEAD 2>/dev/null)"

if [ ! -f "$receipt" ]; then
  printf '[verify-gate] BLOCKED: verify.sh has not passed green for %s.\n  Run .keiko-scripts/verify-receipt.sh (loop until green) before this PR.\n' "$branch" >&2
  exit 1
fi

if ! jq -e '.mode == "full"' "$receipt" >/dev/null 2>&1; then
  printf '[verify-gate] BLOCKED: receipt does not prove full delivery verification.\n' >&2
  exit 1
fi

verified="$(sed -n 's/.*"verified_sha":"\([a-f0-9]*\)".*/\1/p' "$receipt")"
if [ "$verified" != "$head" ]; then
  printf '[verify-gate] BLOCKED: verify receipt is stale (verified %s, HEAD %s).\n  Re-run verify-receipt.sh after the latest commits.\n' "${verified:0:8}" "${head:0:8}" >&2
  exit 1
fi

printf '[verify-gate] OK: verify.sh green at HEAD %s on %s.\n' "${head:0:8}" "$branch"
exit 0
