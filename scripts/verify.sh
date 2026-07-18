#!/usr/bin/env bash
#
# verify.sh — local pre-PR gate. Run from the TARGET repo root before opening a PR.
#
# Precedence (drift-free — the target owns its gate list):
#   1. `agent:pre-pr`  — the repository-owned canonical agent gate (issue #12), if present.
#   2. keiko-native    → `npm run quality` + `npm audit`; keiko-web → `codex:pre-pr`.
#   3. legacy inline CI-mirror steps (older Keiko branches without `codex:pre-pr`).
# The highest-precedence command that exists runs EXACTLY ONCE; nothing else runs.
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

# Does the repo define a given npm script? (node is always present in this repo.)
has_script() { node -e "process.exit(((require('./package.json').scripts)||{})['$1']?0:1)" 2>/dev/null; }

# Repository-owned canonical gate (issue #12): when the target exposes `agent:pre-pr`
# it owns its full gate list — run it EXACTLY ONCE and defer entirely to it, in either
# profile, before any profile-specific or codex:pre-pr fallback. A non-zero result is a
# verification failure (no green receipt). --fast keeps the quick local smoke below.
if [[ $FAST -eq 0 ]] && has_script "agent:pre-pr"; then
  echo "─── npm run agent:pre-pr (repository-owned canonical gate) ───"
  if npm run agent:pre-pr; then
    echo
    echo "✓ verify GREEN (agent:pre-pr) — safe to open the PR"
    exit 0
  fi
  echo
  echo "✗ verify RED (agent:pre-pr) — fix before opening the PR"
  exit 1
fi

# keiko-native fallback (no agent:pre-pr): the local green bar is `npm run quality`
# (+ npm audit). See profiles/keiko-native.md. --fast skips the audit for a quick smoke.
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
