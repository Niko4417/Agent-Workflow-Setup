#!/usr/bin/env bash
#
# verify-receipt.sh — run verify.sh (the local CI mirror) and, ONLY if it passes
# green, write a SHA-bound receipt proving HEAD passed local verification. No
# receipt is written on failure.
#
# Unlike the audit findings (self-reported by the skill), this is trustworthy: the
# script runs verify.sh itself, so the receipt's existence IS the proof. The
# PR-create gate (verify-gate.sh) and the epic-merge gate require it at HEAD.
#
# Usage (from the target repo root):
#   verify-receipt.sh [issue-number] [args forwarded to verify.sh, e.g. --fast]

set -uo pipefail

issue="${1:-}"
[ $# -gt 0 ] && shift

here="$(cd "$(dirname "$0")" && pwd -P)"
if ! bash "$here/verify.sh" "$@"; then
  printf '[verify-receipt] verify.sh FAILED — no receipt written. Fix and re-run until green.\n' >&2
  exit 1
fi

gd="$(git rev-parse --git-dir)"
branch="$(git symbolic-ref --quiet --short HEAD || echo detached)"
slug="$(printf '%s' "$branch" | tr '/' '_')"
sha="$(git rev-parse HEAD)"
dir="$gd/keiko-verify"
mkdir -p "$dir"

printf '{"branch":"%s","issue":"%s","verified_sha":"%s","ts":"%s"}\n' \
  "$branch" "$issue" "$sha" "$(date -u +%FT%TZ)" > "$dir/$slug.json"

printf 'verify receipt written: %s @ %s (verify.sh green)\n' "$branch" "${sha:0:8}"
