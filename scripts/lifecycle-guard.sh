#!/usr/bin/env bash
#
# lifecycle-guard.sh — consumer fail-closed check for the target-owned issue lifecycle.
#
# A governed OPEN issue must carry EXACTLY ONE `status:*` label (per the target's
# docs/qa/issue-lifecycle.md). This guard fails closed on a zero / multiple / malformed
# lifecycle-label set so a consumer never acts on ambiguous state. It deliberately does
# NOT decide transitions or know the state names — the transition graph and the
# canonical state set are the target repository's, never reimplemented here.
#
# Usage:
#   lifecycle-guard.sh <label> [<label> ...]                       # labels as args
#   gh issue view <N> --json labels -q '.labels[].name' | lifecycle-guard.sh -
#
#   exit 0 = exactly one status:* label   exit 2 = fail closed (zero / multiple)

set -uo pipefail

labels=()
if [ "${1:-}" = "-" ]; then
  while IFS= read -r line; do
    [ -n "$line" ] && labels+=("$line")
  done
else
  labels=("$@")
fi

count=0
for label in ${labels[@]+"${labels[@]}"}; do
  case "$label" in
    status:*) count=$((count + 1)) ;;
  esac
done

if [ "$count" -eq 1 ]; then
  exit 0
fi

printf '[lifecycle-guard] FAIL-CLOSED: expected exactly one status:* label, found %d — do not act on ambiguous lifecycle state.\n' "$count" >&2
exit 2
