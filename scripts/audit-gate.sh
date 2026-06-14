#!/usr/bin/env bash
#
# audit-gate.sh — deterministic proof-of-audit check before a PR.
#
# Passes (exit 0) only when a keiko-issue-audit receipt exists for the current
# branch AND it was taken against the current HEAD. Enforced on issue/* and epic/*
# branches; other branches pass through untouched.
#
# Exit 0 = ok / not applicable.  Exit 1 = blocked (no receipt or stale).
# Used by the PR PreToolUse hook and runnable by hand from the target repo root.

set -uo pipefail

branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo)"
case "$branch" in
  issue/*|epic/*) ;;                 # enforce only on issue/epic branches
  *) exit 0 ;;
esac

gd="$(git rev-parse --git-dir 2>/dev/null)"
slug="$(printf '%s' "$branch" | tr '/' '_')"
receipt="$gd/keiko-audit/$slug.json"
head="$(git rev-parse HEAD 2>/dev/null)"

if [ ! -f "$receipt" ]; then
  printf '[audit-gate] BLOCKED: no keiko-issue-audit receipt for %s.\n  Run keiko-issue-audit before this PR can be ready.\n' "$branch" >&2
  exit 1
fi

audited="$(sed -n 's/.*"audited_sha":"\([a-f0-9]*\)".*/\1/p' "$receipt")"
if [ "$audited" != "$head" ]; then
  printf '[audit-gate] BLOCKED: audit receipt is stale (audited %s, HEAD %s).\n  Re-run keiko-issue-audit after the latest commits.\n' "${audited:0:8}" "${head:0:8}" >&2
  exit 1
fi

printf '[audit-gate] OK: keiko-issue-audit ran against HEAD %s on %s.\n' "${head:0:8}" "$branch"
exit 0
