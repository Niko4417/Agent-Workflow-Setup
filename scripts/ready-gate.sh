#!/usr/bin/env bash
#
# ready-gate.sh — block marking a USER-FACING PR "ready for review" until its
# Playwright test-plan comment is posted on the PR.
#
# The ui-verify RUN (a real Playwright pass) is already enforced at PR-create by
# audit-gate; this enforces the DOCUMENTATION comment at the human handoff, which
# is the only point a ->dev PR is checked (a human, not an agent, merges it). For
# ->epic PRs the same comment is enforced at the child->epic auto-merge instead, so
# those never reach `gh pr ready`.
#
# Fires via a PreToolUse hook on `gh pr ready`; receives the command to resolve the
# PR number. exit 0 = ok / not applicable, exit 1 = blocked.

set -uo pipefail

cmd="${1:-}"
marker="keiko:manual-test-plan"

branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo)"
case "$branch" in
  issue/*|epic/*|codex/*) ;;
  *) exit 0 ;;
esac

here="$(cd "$(dirname "$0")" && pwd -P)"
bash "$here/proof-worktree.sh" || exit 1

gd="$(git rev-parse --git-dir 2>/dev/null)"
slug="$(printf '%s' "$branch" | tr '/' '_')"
receipt="$gd/keiko-audit/$slug.json"
head="$(git rev-parse HEAD 2>/dev/null)"

# Proof for this checkout cannot authorize a different PR or an older remote head.
if ! prnum="$(python3 - "$cmd" <<'PY'
import shlex, sys
try:
    args = shlex.split(sys.argv[1])
except ValueError:
    raise SystemExit(2)
if (len(args) != 4 or args[:3] != ['gh','pr','ready'] or
    not args[3].isascii() or not args[3].isdigit() or int(args[3]) <= 0):
    raise SystemExit(2)
print(args[3])
PY
)" || ! snapshot="$(gh pr view "$prnum" --json headRefName,headRefOid 2>/dev/null)" ||
   ! printf '%s' "$snapshot" | jq -e --arg branch "$branch" --arg sha "$head" \
      '.headRefName == $branch and .headRefOid == $sha' >/dev/null 2>&1; then
  printf '[ready-gate] BLOCKED: selected PR must match the verified local branch and exact HEAD.\n' >&2
  exit 1
fi

# No audit receipt yet -> audit-gate handles that at create; nothing to enforce here.
[ -f "$receipt" ] || exit 0

user_facing="$(sed -n 's/.*"user_facing":"\([^"]*\)".*/\1/p' "$receipt")"
# Only user-facing PRs need the documented test plan.
[ "$user_facing" = "true" ] || exit 0

comments="$(gh pr view "$prnum" --json comments -q '.comments[].body' 2>/dev/null || true)"

# The comment marker is SHA-bound: it must name the exact commit being handed off,
# so a fix that changed HEAD forces a repost.
if ! printf '%s' "$comments" | grep -q "$marker sha=$head"; then
  printf '[ready-gate] BLOCKED: no manual-test-plan comment for the current commit. Post/repost it as <!-- %s sha=%s --> before marking ready for review.\n' "$marker" "$head" >&2
  exit 1
fi

printf '[ready-gate] OK: sha-bound test-plan comment present for %s.\n' "${head:0:8}"
exit 0
