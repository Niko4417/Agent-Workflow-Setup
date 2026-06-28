#!/usr/bin/env bash
#
# epic-merge-gate.sh — gate the agent/CLI `gh pr merge` path:
#   * into dev / main / release  -> ALWAYS blocked (a human merges via the UI).
#   * into an epic / integration -> allowed only when verify.sh passed green at the
#     branch (any other base)        audited commit (verify receipt) AND the
#                                     keiko-issue-audit receipt is clean (findings=0)
#                                     AND either:
#                                      - the issue is non-user-facing, OR
#                                      - it is user-facing AND ui_verified=true
#                                        (its Playwright test plan passed) AND a
#                                        marked manual-test-plan comment is on the PR.
#
# Rationale: GitHub CI does not run on epic integration-branch PRs, so the
# child->epic gate is the audit. A clean non-user-facing child auto-merges. A
# user-facing child auto-merges only when its Playwright-reviewable test plan ran
# green (ui_verified) and the documentation comment exists; otherwise a human
# merges via the GitHub UI (which does not run this hook). Subjective visual /
# screen-reader review happens at the epic->dev human gate.
#
# Wired to a PreToolUse hook on `gh pr merge`. Also runnable by hand.
#   exit 0 = allowed / not applicable      exit 1 = blocked
#
# Floor-raising, not adversarially airtight: findings/user_facing/ui_verified are
# self-reported by the audit skill (the comment presence is checked for real via
# gh). Authoritative enforcement is server-side (protected dev + the epic->dev PR).

set -uo pipefail

cmd="${1:-}"   # full `gh pr merge ...` command, used to extract a PR number
marker="keiko:manual-test-plan"

prnum="$(printf '%s' "$cmd" | grep -oE 'merge[[:space:]]+[0-9]+' | grep -oE '[0-9]+' || true)"
ghpr() { if [ -n "$prnum" ]; then gh pr view "$prnum" "$@"; else gh pr view "$@"; fi; }

info="$(ghpr --json baseRefName,headRefName 2>/dev/null || true)"
# Can't determine the PR (offline / no PR yet) -> fail open: audit-gate already
# proved an audit ran, and the epic->dev PR is the hard backstop.
[ -n "$info" ] || exit 0

base="$(printf '%s' "$info" | sed -n 's/.*"baseRefName":"\([^"]*\)".*/\1/p')"
head="$(printf '%s' "$info" | sed -n 's/.*"headRefName":"\([^"]*\)".*/\1/p')"

# Branch naming is not standardized (epics are feat/<name>-<n>, children vary), so
# detect by elimination. dev / main / release are sacred: never auto-merge there
# from the agent/CLI path. Any OTHER base is an epic / integration branch.
case "$base" in
  dev|main|master|release/*)
    printf '[epic-merge-gate] BLOCKED: never auto-merge into %s. A human must review and merge via the GitHub UI.\n' "$base" >&2
    exit 1 ;;
  *) ;;
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
ui_verified="$(sed -n 's/.*"ui_verified":"\([^"]*\)".*/\1/p' "$receipt")"

if [ "$findings" != "0" ]; then
  printf '[epic-merge-gate] BLOCKED: audit findings=%s for %s (need 0 to auto-merge into %s). Resolve findings, re-audit, or have a human merge.\n' "${findings:-unknown}" "$head" "$base" >&2
  exit 1
fi

# verify.sh must have passed green at the SAME commit the audit covered (audit
# fixes change HEAD, so re-verification is required before auto-merge).
audited="$(sed -n 's/.*"audited_sha":"\([^"]*\)".*/\1/p' "$receipt")"
vreceipt="$gd/keiko-verify/$slug.json"
verified="$(sed -n 's/.*"verified_sha":"\([^"]*\)".*/\1/p' "$vreceipt" 2>/dev/null || true)"
if [ ! -f "$vreceipt" ] || [ -z "$verified" ] || [ "$verified" != "$audited" ]; then
  printf '[epic-merge-gate] BLOCKED: no green verify receipt at the audited commit for %s (verified=%s, audited=%s). Run verify-receipt.sh, then re-audit.\n' "$head" "${verified:-none}" "${audited:-none}" >&2
  exit 1
fi

case "$user_facing" in
  false)
    printf '[epic-merge-gate] OK: clean, non-user-facing audit for %s -> %s; auto-merge allowed.\n' "$head" "$base"
    exit 0 ;;
  true)
    if [ "$ui_verified" != "true" ]; then
      printf '[epic-merge-gate] BLOCKED: %s is user-facing but ui_verified=%s — its Playwright test plan did not pass green. A human must review and merge.\n' "$head" "${ui_verified:-unknown}" >&2
      exit 1
    fi
    comments="$(ghpr --json comments -q '.comments[].body' 2>/dev/null || true)"
    if ! printf '%s' "$comments" | grep -q "$marker"; then
      printf '[epic-merge-gate] BLOCKED: %s is user-facing but has no manual-test-plan comment (<!-- %s -->) on the PR. Post the test plan before auto-merge.\n' "$head" "$marker" >&2
      exit 1
    fi
    printf '[epic-merge-gate] OK: user-facing audit clean, Playwright-verified, test-plan comment present for %s -> %s; auto-merge allowed.\n' "$head" "$base"
    exit 0 ;;
  *)
    printf '[epic-merge-gate] BLOCKED: user_facing=%s (unknown) for %s — fail-closed. A human must review and merge.\n' "${user_facing:-unknown}" "$head" >&2
    exit 1 ;;
esac
