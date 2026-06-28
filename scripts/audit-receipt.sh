#!/usr/bin/env bash
#
# audit-receipt.sh — record proof that keiko-issue-audit ran against current HEAD.
#
# Called by the keiko-issue-audit skill as its final step. Writes a receipt under
# .git/keiko-audit/<branch>.json (per-clone, never committed) binding the audit to
# the exact commit it covered. audit-gate.sh checks it before a PR; epic-merge-gate.sh
# reads the findings/user_facing fields before an epic auto-merge.
#
# Usage (from the target repo root):
#   audit-receipt.sh [issue-number] [--findings N] [--user-facing true|false]
#
# Flags are optional and default to "unknown" (fail-closed). They feed the
# epic-merge auto-merge decision: it auto-merges into an epic branch only when
# findings=0 AND either user_facing=false, or user_facing=true with a green
# ui-verify receipt (the Playwright plan actually ran green, see
# ui-verify-receipt.sh) at this commit plus a manual-test-plan comment on the PR.
# A standalone audit can omit the flags safely.

set -euo pipefail

issue=""
findings="unknown"
user_facing="unknown"

while [ $# -gt 0 ]; do
  case "$1" in
    --findings) findings="${2:-unknown}"; shift 2 ;;
    --user-facing) user_facing="${2:-unknown}"; shift 2 ;;
    *) [ -z "$issue" ] && issue="$1"; shift ;;
  esac
done

gd="$(git rev-parse --git-dir)"
branch="$(git symbolic-ref --quiet --short HEAD || echo detached)"
slug="$(printf '%s' "$branch" | tr '/' '_')"
sha="$(git rev-parse HEAD)"
dir="$gd/keiko-audit"
mkdir -p "$dir"

printf '{"branch":"%s","issue":"%s","audited_sha":"%s","findings":"%s","user_facing":"%s","ts":"%s"}\n' \
  "$branch" "$issue" "$sha" "$findings" "$user_facing" "$(date -u +%FT%TZ)" > "$dir/$slug.json"

printf 'audit receipt written: %s @ %s (findings=%s, user_facing=%s)\n' \
  "$branch" "${sha:0:8}" "$findings" "$user_facing"
