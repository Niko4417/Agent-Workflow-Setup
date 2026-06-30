#!/usr/bin/env bash
#
# dev-pr-gate.sh — before any PR into `dev` is opened (a standalone issue->dev or
# the epic->dev handoff), require the surface to be fully clean AT HEAD:
#   - a fresh audit receipt at HEAD with findings=0, AND
#   - when user-facing, a green ui-verify (Playwright) receipt at HEAD.
#
# The green verify receipt is enforced separately by verify-gate; together, a PR
# into dev cannot be opened unless local verify + audit + (UI) Playwright are all
# clean. (Child issue->epic PRs target a non-dev base, so they pass through here —
# their findings=0 + ui-verify are enforced at the child->epic merge instead.)
#
# Fires via the PR PreToolUse hook on gh pr create/ready; receives the command so
# it can read the --base. Runnable by hand. exit 0 = ok / n/a, exit 1 = blocked.

set -uo pipefail

cmd="${1:-}"

branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo)"
case "$branch" in
  issue/*|epic/*) ;;     # only work branches
  *) exit 0 ;;
esac

# Determine the PR base: explicit --base/-B in the command, else the default (dev).
base="$(printf '%s\n' "$cmd" | sed -n 's/.*--base[ =]\([^ ]*\).*/\1/p')"
[ -z "$base" ] && base="$(printf '%s\n' "$cmd" | sed -n 's/.*-B[ =]\([^ ]*\).*/\1/p')"
[ -z "$base" ] && base="dev"
# Only gate PRs targeting dev; everything else (epic/feature bases) is the
# merge gate's job.
[ "$base" = "dev" ] || exit 0

gd="$(git rev-parse --git-dir 2>/dev/null)"
slug="$(printf '%s' "$branch" | tr '/' '_')"
head="$(git rev-parse HEAD 2>/dev/null)"
receipt="$gd/keiko-audit/$slug.json"

if [ ! -f "$receipt" ]; then
  printf '[dev-pr-gate] BLOCKED: no audit receipt for %s. Run keiko-issue-audit before the ->dev PR.\n' "$branch" >&2
  exit 1
fi

audited="$(sed -n 's/.*"audited_sha":"\([^"]*\)".*/\1/p' "$receipt")"
if [ "$audited" != "$head" ]; then
  printf '[dev-pr-gate] BLOCKED: audit receipt is stale (audited %s, HEAD %s). Re-audit after the latest commits / dev rebase.\n' "${audited:0:8}" "${head:0:8}" >&2
  exit 1
fi

findings="$(sed -n 's/.*"findings":"\([^"]*\)".*/\1/p' "$receipt")"
if [ "$findings" != "0" ]; then
  printf '[dev-pr-gate] BLOCKED: audit findings=%s (need 0 before the ->dev PR).\n' "${findings:-unknown}" >&2
  exit 1
fi

user_facing="$(sed -n 's/.*"user_facing":"\([^"]*\)".*/\1/p' "$receipt")"
case "$user_facing" in
  false) ;;
  true)
    uvr="$gd/keiko-ui-verify/$slug.json"
    uv="$(sed -n 's/.*"ui_verified_sha":"\([^"]*\)".*/\1/p' "$uvr" 2>/dev/null || true)"
    if [ ! -f "$uvr" ] || [ "$uv" != "$head" ]; then
      printf '[dev-pr-gate] BLOCKED: user-facing change needs a green ui-verify receipt at HEAD (Playwright plan). Run ui-verify-receipt.sh.\n' >&2
      exit 1
    fi ;;
  *)
    printf '[dev-pr-gate] BLOCKED: user_facing=%s (unknown) — re-run the audit with --user-facing true|false.\n' "${user_facing:-unknown}" >&2
    exit 1 ;;
esac

printf '[dev-pr-gate] OK: clean (findings=0%s) at %s -> dev.\n' \
  "$([ "$user_facing" = true ] && printf ', ui-verified')" "${head:0:8}"
exit 0
