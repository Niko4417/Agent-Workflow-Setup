#!/usr/bin/env bash
#
# audit-gate.sh — deterministic proof-of-clean-audit check before ANY PR.
#
# Passes (exit 0) only when, for the current branch's HEAD, the keiko-issue-audit
# receipt shows the audit RAN and is CLEAN:
#   - receipt exists and audited_sha == HEAD, AND
#   - findings == 0, AND
#   - when user-facing, a green ui-verify (Playwright) receipt exists at HEAD.
# Enforced on issue/* and epic/* branches; other branches pass through.
#
# This is uniform for every PR an agent opens from a work branch — there is no
# per-target distinction; the child->epic auto-merge re-checks the same at merge.
#
# Exit 0 = ok / not applicable.  Exit 1 = blocked.
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

findings="$(sed -n 's/.*"findings":"\([^"]*\)".*/\1/p' "$receipt")"
if [ "$findings" != "0" ]; then
  printf '[audit-gate] BLOCKED: audit findings=%s on %s (need 0 before the PR).\n' "${findings:-unknown}" "$branch" >&2
  exit 1
fi

user_facing="$(sed -n 's/.*"user_facing":"\([^"]*\)".*/\1/p' "$receipt")"
case "$user_facing" in
  false) ;;
  true)
    uvr="$gd/keiko-ui-verify/$slug.json"
    uv="$(sed -n 's/.*"ui_verified_sha":"\([^"]*\)".*/\1/p' "$uvr" 2>/dev/null || true)"
    if [ ! -f "$uvr" ] || [ "$uv" != "$head" ]; then
      printf '[audit-gate] BLOCKED: user-facing change needs a green ui-verify receipt at HEAD (Playwright plan). Run ui-verify-receipt.sh.\n' >&2
      exit 1
    fi ;;
  *)
    printf '[audit-gate] BLOCKED: user_facing=%s (unknown) — re-run keiko-issue-audit with --user-facing true|false.\n' "${user_facing:-unknown}" >&2
    exit 1 ;;
esac

printf '[audit-gate] OK: clean audit (findings=0%s) at HEAD %s on %s.\n' \
  "$([ "$user_facing" = true ] && printf ', ui-verified')" "${head:0:8}" "$branch"
exit 0
