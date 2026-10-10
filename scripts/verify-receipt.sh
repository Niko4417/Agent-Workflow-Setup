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
#   verify-receipt.sh [issue-number] (full delivery verification; no smoke arguments)

set -uo pipefail

issue="${1:-}"
[ $# -gt 0 ] && shift

# Only current target checking scripts may augment full verification.
args=("$@")
while [ "$#" -gt 0 ]; do
  [ "$1" = '--also' ] && [ "$#" -ge 2 ] || {
    printf '[verify-receipt] use [issue-number] [--also <current npm checking script>]; full verification is required.\n' >&2
    exit 1
  }
  shift 2
done
set -- ${args[@]+"${args[@]}"}

here="$(cd "$(dirname "$0")" && pwd -P)"
commands='[]'
if [ -f docs/adr/ADR-0145-retire-the-agent-pre-pr-aggregate-gate.md ]; then
  commands="$(python3 "$here/verify-web-policy.py" --plan "$@")" || exit 1
elif [ "$#" -gt 0 ]; then
  printf '[verify-receipt] --also requires the target individual-command verification contract.\n' >&2
  exit 1
fi
start_sha="$(git rev-parse HEAD)" || exit 1
start_branch="$(git symbolic-ref --quiet --short HEAD)" || exit 1
bash "$here/proof-worktree.sh" || exit 1
if ! bash "$here/verify.sh" "$@"; then
  printf '[verify-receipt] verify.sh FAILED — no receipt written. Fix and re-run until green.\n' >&2
  exit 1
fi

if [ "$(git rev-parse HEAD)" != "$start_sha" ] || [ "$(git symbolic-ref --quiet --short HEAD)" != "$start_branch" ]; then
  printf '[verify-receipt] HEAD/worktree changed during verification; no receipt written.\n' >&2
  exit 1
fi

bash "$here/proof-worktree.sh" || exit 1

gd="$(git rev-parse --git-dir)"
branch="$(git symbolic-ref --quiet --short HEAD || echo detached)"
slug="$(printf '%s' "$branch" | tr '/' '_')"
sha="$(git rev-parse HEAD)"
dir="$gd/keiko-verify"
mkdir -p "$dir"

printf '{"branch":"%s","issue":"%s","verified_sha":"%s","mode":"full","commands":%s,"ts":"%s"}\n' \
  "$branch" "$issue" "$sha" "$commands" "$(date -u +%FT%TZ)" > "$dir/$slug.json"

printf 'verify receipt written: %s @ %s (verify.sh green)\n' "$branch" "${sha:0:8}"
