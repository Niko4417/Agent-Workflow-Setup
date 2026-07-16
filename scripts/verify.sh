#!/usr/bin/env bash
#
# verify.sh — local pre-PR gate. Run from the TARGET repo root before opening a PR.
#
# Prefers the repo's CANONICAL `codex:pre-pr` aggregate
# (scripts/codex-pre-pr.mjs — owner-maintained, kept in sync with ci.yml) when it
# exists, so this gate stays drift-free and inherits new checks automatically.
# Falls back to the legacy inline CI-mirror step list on branches that don't have
# `codex:pre-pr` yet (older branches not rebased on dev).
#
# Usage (from the Keiko repo root):
#   bash /path/to/Agent-Workflow-Setup/scripts/verify.sh          # full canonical pre-PR check
#   bash /path/to/Agent-Workflow-Setup/scripts/verify.sh --fast   # quick legacy smoke (skips full test)
#
# Note: a few CI jobs cannot be mirrored locally and remain CI-only:
#   installable-package smoke (needs a clean `npm ci`), CodeQL,
#   dependency-review, actionlint, pinned-SHA assertion.

set -uo pipefail

FAST=0
[[ "${1:-}" == "--fast" ]] && FAST=1

if [[ ! -f package.json ]]; then
  echo "ERROR: run this from the target repo root (no package.json here)." >&2
  exit 1
fi

here="$(cd "$(dirname "$0")" && pwd -P)"
# shellcheck source=/dev/null
. "$here/profile-detect.sh"

# keiko-native: the local green bar is `npm run quality` (+ npm audit). See
# profiles/keiko-native.md. --fast skips the audit for a quick smoke.
if [[ "$KEIKO_PROFILE" == "keiko-native" ]]; then
  echo "─── npm run quality (keiko-native green bar) ───"
  if ! npm run quality; then
    echo
    echo "✗ verify RED (npm run quality) — fix before opening the PR"
    exit 1
  fi
  if [[ $FAST -eq 0 ]]; then
    echo "─── npm audit --audit-level=high ───"
    if ! npm audit --audit-level=high; then
      echo
      echo "✗ verify RED (npm audit --audit-level=high) — fix before opening the PR"
      exit 1
    fi
  fi
  echo
  echo "✓ verify GREEN (keiko-native: npm run quality$([[ $FAST -eq 0 ]] && echo ' + audit')) — safe to open the PR"
  exit 0
fi

# Does the repo define a given npm script? (node is always present in this repo.)
has_script() { node -e "process.exit(((require('./package.json').scripts)||{})['$1']?0:1)" 2>/dev/null; }

# Canonical path: run the owner-maintained codex:pre-pr aggregate (broader + CI-synced).
# Skipped in --fast mode, which is a quick local smoke via the legacy steps below.
if [[ $FAST -eq 0 ]] && has_script "codex:pre-pr"; then
  echo "─── npm run codex:pre-pr (canonical pre-PR gate) ───"
  if npm run codex:pre-pr; then
    echo
    echo "✓ verify GREEN (codex:pre-pr) — safe to open the PR"
    exit 0
  fi
  echo
  echo "✗ verify RED (codex:pre-pr) — fix before opening the PR"
  exit 1
fi

# Fallback: legacy inline CI-mirror steps (ci.yml order) — used when codex:pre-pr
# is absent, or in --fast mode.
steps=(
  "typecheck"
  "check:version-consistency"
  "lint"
  "arch:check"
  "arch:check:negative"
  "check:qi-supply-chain"
)
[[ $FAST -eq 0 ]] && steps+=("test")

fail=0
for s in "${steps[@]}"; do
  echo "─── npm run $s ───"
  if ! npm run "$s" --silent; then
    echo "✗ FAILED: $s"
    fail=1
    break   # fail fast, like CI
  fi
  echo "✓ $s"
done

echo
if [[ $fail -eq 0 ]]; then
  echo "✓ verify GREEN (legacy mirror$([[ $FAST -eq 1 ]] && echo ', fast: full test skipped')) — safe to open the PR"
else
  echo "✗ verify RED — fix before opening the PR"
fi
exit $fail
