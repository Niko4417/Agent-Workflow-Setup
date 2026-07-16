#!/usr/bin/env bash
#
# ui-verify-receipt.sh — run a user-facing change's Playwright test plan and, ONLY
# if it passes green, write a SHA-bound receipt proving the UI was verified at HEAD.
#
# This makes ui_verified non-self-reported, the same way verify-receipt.sh does for
# verify.sh: the script RUNS Playwright and the receipt's existence is the proof.
# The epic-merge gate requires this receipt (matching the audited commit) before it
# will auto-merge a user-facing child.
#
# Usage (from the target repo root):
#   ui-verify-receipt.sh <issue> -- <command that runs the Playwright plan>
#   e.g. ui-verify-receipt.sh 1632 -- npx playwright test tests/plan-1632.spec.ts
#
# Note: this raises the bar (a real Playwright run must exit green) but is not
# cryptographically airtight — the agent still chooses the spec. The gh-checked
# test-plan comment is the human-auditable record of what the plan should cover.

set -uo pipefail

issue="${1:-}"
[ $# -gt 0 ] && shift
[ "${1:-}" = "--" ] && shift

if [ $# -eq 0 ]; then
  printf '[ui-verify-receipt] no journey command given (usage: ui-verify-receipt.sh <issue> -- <cmd>)\n' >&2
  exit 2
fi

here="$(cd "$(dirname "$0")" && pwd -P)"
# shellcheck source=/dev/null
. "$here/profile-detect.sh"

# Guard: the command must run the profile's user-facing verification harness.
# keiko-web is a browser app, so the plan must invoke Playwright. keiko-native is a
# desktop app whose Acceptance Journey may run a native / Computer-Use / e2e harness,
# so any real command is accepted; the gh-checked test-plan comment remains the
# human-auditable record of what the journey must cover.
if [ "$KEIKO_PROFILE" != "keiko-native" ]; then
  printf '%s ' "$@" | grep -qi 'playwright' || {
    printf '[ui-verify-receipt] keiko-web: the command must run Playwright (got: %s)\n' "$*" >&2
    exit 2
  }
fi

if ! "$@"; then
  printf '[ui-verify-receipt] journey plan FAILED — no receipt written. Fix and re-run, or hand to human review.\n' >&2
  exit 1
fi

gd="$(git rev-parse --git-dir)"
branch="$(git symbolic-ref --quiet --short HEAD || echo detached)"
slug="$(printf '%s' "$branch" | tr '/' '_')"
sha="$(git rev-parse HEAD)"
dir="$gd/keiko-ui-verify"
mkdir -p "$dir"

printf '{"branch":"%s","issue":"%s","ui_verified_sha":"%s","ts":"%s"}\n' \
  "$branch" "$issue" "$sha" "$(date -u +%FT%TZ)" > "$dir/$slug.json"

printf 'ui-verify receipt written: %s @ %s (%s journey plan green)\n' "$branch" "${sha:0:8}" "$KEIKO_PROFILE"
