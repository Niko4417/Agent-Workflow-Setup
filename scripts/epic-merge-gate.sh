#!/usr/bin/env bash
#
# epic-merge-gate.sh — block an AGENT auto-merge of a child PR into an epic/*
# branch unless its keiko-issue-audit receipt is clean (findings=0) AND the
# issue is non-user-facing (user_facing=false).
#
# Rationale: GitHub CI does not run on epic/* PRs, so the child->epic gate is the
# audit. A non-user-facing child with a clean audit may auto-merge; a user-facing
# or unclean child must be merged by a HUMAN (e.g. via the GitHub UI, which does
# not run this hook). This is the only place auto-merge is permitted.
#
# Wired to a PreToolUse hook on `gh pr merge`. Also runnable by hand.
#   exit 0 = allowed / not applicable      exit 1 = blocked
#
# Floor-raising, not adversarially airtight: the findings/user_facing fields are
# self-reported by the audit skill. Authoritative enforcement is server-side
# (protected dev + the epic->dev PR's full CI + human review).

set -uo pipefail

cmd="${1:-}"   # full `gh pr merge ...` command, used to extract a PR number

prnum="$(printf '%s' "$cmd" | grep -oE 'merge[[:space:]]+[0-9]+' | grep -oE '[0-9]+' || true)"
if [ -n "$prnum" ]; then
  info="$(gh pr view "$prnum" --json baseRefName,headRefName 2>/dev/null || true)"
else
  info="$(gh pr view --json baseRefName,headRefName 2>/dev/null || true)"
fi
# Can't determine the PR (offline / no PR yet) -> fail open: audit-gate already
# proved an audit ran, and the epic->dev PR is the hard backstop.
[ -n "$info" ] || exit 0

base="$(printf '%s' "$info" | sed -n 's/.*"baseRefName":"\([^"]*\)".*/\1/p')"
head="$(printf '%s' "$info" | sed -n 's/.*"headRefName":"\([^"]*\)".*/\1/p')"

case "$base" in
  epic/*) ;;            # enforce only on merges INTO an epic branch
  *) exit 0 ;;
esac

gd="$(git rev-parse --git-dir 2>/dev/null)"
slug="$(printf '%s' "$head" | tr '/' '_')"
receipt="$gd/keiko-audit/$slug.json"

if [ ! -f "$receipt" ]; then
  printf '[epic-merge-gate] BLOCKED: no keiko-issue-audit receipt for %s. Run the audit before merging into %s.\n' "$head" "$base" >&2
  exit 1
fi

findings="$(sed -n 's/.*"findings":"\([^"]*\)".*/\1/p' "$receipt")"
user_facing="$(sed -n 's/.*"user_facing":"\([^"]*\)".*/\1/p' "$receipt")"

if [ "$findings" != "0" ]; then
  printf '[epic-merge-gate] BLOCKED: audit findings=%s for %s (need 0 to auto-merge into %s). Resolve findings, re-audit, or have a human merge.\n' "${findings:-unknown}" "$head" "$base" >&2
  exit 1
fi

if [ "$user_facing" != "false" ]; then
  printf '[epic-merge-gate] BLOCKED: %s is user-facing (user_facing=%s) — auto-merge not permitted. A human must review and merge (e.g. via the GitHub UI).\n' "$head" "${user_facing:-unknown}" >&2
  exit 1
fi

printf '[epic-merge-gate] OK: clean, non-user-facing audit for %s -> %s; auto-merge allowed.\n' "$head" "$base"
exit 0
