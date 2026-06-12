#!/usr/bin/env bash
#
# verify.sh — local CI mirror. Run from the TARGET repo root before opening a PR.
#
# Runs the exact gate sequence from .github/workflows/ci.yml so CI becomes a
# confirmation, not a discovery. Does NOT modify package.json — it just invokes
# the scripts the repo already defines.
#
# Usage (from the Keiko repo root):
#   bash /path/to/Agent-Workflow-Setup/scripts/verify.sh
#   bash /path/to/Agent-Workflow-Setup/scripts/verify.sh --fast   # skip the full test run
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

# CI order from ci.yml.
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
  echo "✓ verify GREEN — safe to open the PR$([[ $FAST -eq 1 ]] && echo ' (fast: full test run skipped)')"
else
  echo "✗ verify RED — fix before opening the PR"
fi
exit $fail
