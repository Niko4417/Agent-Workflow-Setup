#!/usr/bin/env bash
#
# audit-receipt.sh — record proof that keiko-issue-audit ran against current HEAD.
#
# Called by the keiko-issue-audit skill as its final step. Writes a receipt under
# .git/keiko-audit/<branch>.json (per-clone, never committed) binding the audit to
# the exact commit it covered. The audit-gate then checks this before a PR.
#
# Usage (from the target repo root):  audit-receipt.sh [issue-number]

set -euo pipefail

issue="${1:-}"
gd="$(git rev-parse --git-dir)"
branch="$(git symbolic-ref --quiet --short HEAD || echo detached)"
slug="$(printf '%s' "$branch" | tr '/' '_')"
sha="$(git rev-parse HEAD)"
dir="$gd/keiko-audit"
mkdir -p "$dir"

printf '{"branch":"%s","issue":"%s","audited_sha":"%s","ts":"%s"}\n' \
  "$branch" "$issue" "$sha" "$(date -u +%FT%TZ)" > "$dir/$slug.json"

printf 'audit receipt written: %s @ %s\n' "$branch" "${sha:0:8}"
