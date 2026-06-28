#!/usr/bin/env bash
#
# epic-pr-gate.sh — before the epic->dev PR is opened, require the INTEGRATED epic
# surface to be fully clean at HEAD:
#   - a fresh audit receipt at HEAD with findings=0, AND
#   - when the epic is user-facing, a green ui-verify (Playwright) receipt at HEAD.
#
# The green verify receipt is enforced separately by verify-gate; together with
# this gate, an epic->dev PR cannot be opened unless local verify + audit + (UI)
# Playwright are all clean against the dev-integrated HEAD. Rebase dev into the
# epic FIRST, then run the loops, so these receipts cover the integrated state.
#
# Fires (via the PR PreToolUse hook on gh pr create/ready) only on epic/* branches.
# Runnable by hand from the target repo root.
#   exit 0 = ok / not applicable      exit 1 = blocked

set -uo pipefail

branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo)"
case "$branch" in
  epic/*) ;;
  *) exit 0 ;;
esac

gd="$(git rev-parse --git-dir 2>/dev/null)"
slug="$(printf '%s' "$branch" | tr '/' '_')"
head="$(git rev-parse HEAD 2>/dev/null)"
receipt="$gd/keiko-audit/$slug.json"

if [ ! -f "$receipt" ]; then
  printf '[epic-pr-gate] BLOCKED: no audit receipt for %s. Run keiko-issue-audit on the integrated epic.\n' "$branch" >&2
  exit 1
fi

audited="$(sed -n 's/.*"audited_sha":"\([^"]*\)".*/\1/p' "$receipt")"
if [ "$audited" != "$head" ]; then
  printf '[epic-pr-gate] BLOCKED: audit receipt is stale (audited %s, HEAD %s). Re-audit after the dev rebase / fixes.\n' "${audited:0:8}" "${head:0:8}" >&2
  exit 1
fi

findings="$(sed -n 's/.*"findings":"\([^"]*\)".*/\1/p' "$receipt")"
if [ "$findings" != "0" ]; then
  printf '[epic-pr-gate] BLOCKED: audit findings=%s on the integrated epic (need 0 before the epic->dev PR).\n' "${findings:-unknown}" >&2
  exit 1
fi

user_facing="$(sed -n 's/.*"user_facing":"\([^"]*\)".*/\1/p' "$receipt")"
case "$user_facing" in
  false) ;;                                  # non-user-facing epic — no ui-verify needed
  true)
    uvr="$gd/keiko-ui-verify/$slug.json"
    uv="$(sed -n 's/.*"ui_verified_sha":"\([^"]*\)".*/\1/p' "$uvr" 2>/dev/null || true)"
    if [ ! -f "$uvr" ] || [ "$uv" != "$head" ]; then
      printf '[epic-pr-gate] BLOCKED: user-facing epic needs a green ui-verify receipt at HEAD (Playwright plan). Run ui-verify-receipt.sh after the integrated audit.\n' >&2
      exit 1
    fi ;;
  *)
    printf '[epic-pr-gate] BLOCKED: user_facing=%s (unknown) on the epic audit — re-run the integrated audit with --user-facing true|false.\n' "${user_facing:-unknown}" >&2
    exit 1 ;;
esac

printf '[epic-pr-gate] OK: integrated epic clean (findings=0%s) at %s.\n' \
  "$([ "$user_facing" = true ] && printf ', ui-verified')" "${head:0:8}"
exit 0
