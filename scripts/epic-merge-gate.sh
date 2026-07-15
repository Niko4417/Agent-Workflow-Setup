#!/usr/bin/env bash
#
# epic-merge-gate.sh — allow agent/CLI merges only from an issue PR into a
# canonical epic/* base after GitHub CI and SHA-bound local audit evidence pass.
# A human merges every other target through the GitHub UI.

set -uo pipefail

cmd="${1:-}"
marker="keiko:manual-test-plan"

block() {
  printf '[epic-merge-gate] BLOCKED: %s\n' "$1" >&2
  exit 1
}

json_string() {
  jq -er "$2 | strings | select(length > 0)" "$1" 2>/dev/null
}

is_sha() { [[ "$1" =~ ^[0-9a-fA-F]{40}$ ]]; }

# Parse and whitelist one canonical command without evaluating it. Text matching
# is insufficient because a fake flag embedded in --body could otherwise satisfy
# the guard or a repository override could make the lookup and merge disagree.
if ! parsed_command="$(python3 - "$cmd" <<'PY'
import shlex
import sys

try:
    args = shlex.split(sys.argv[1], posix=True)
except ValueError:
    raise SystemExit(2)

if len(args) < 4 or args[0] != "gh" or args[1:3] != ["pr", "merge"]:
    raise SystemExit(2)
if not args[3].isascii() or not args[3].isdigit() or int(args[3]) <= 0:
    raise SystemExit(2)

matches = []
seen = set()
index = 4
while index < len(args):
    arg = args[index]
    if arg == "--match-head-commit":
        if index + 1 >= len(args):
            raise SystemExit(2)
        matches.append(args[index + 1])
        index += 2
        continue
    elif arg.startswith("--match-head-commit="):
        matches.append(arg.split("=", 1)[1])
    elif arg in {"--auto", "--squash", "-s", "--delete-branch", "-d"}:
        canonical = {"-s": "--squash", "-d": "--delete-branch"}.get(arg, arg)
        if canonical in seen:
            raise SystemExit(2)
        seen.add(canonical)
    else:
        raise SystemExit(2)
    index += 1

if len(matches) != 1 or "--auto" not in seen or "--squash" not in seen:
    raise SystemExit(2)
print(f"{args[3]}\t{matches[0]}")
PY
)"; then
  block 'use only: gh pr merge <number> --auto --squash [--delete-branch] --match-head-commit <sha>; overrides, admin, content flags, and shell chaining are denied.'
fi
IFS=$'\t' read -r prnum match_sha <<<"$parsed_command"
ghpr() { gh pr view "$prnum" "$@"; }

# Query all merge-critical GitHub facts in one snapshot. A lookup or parse error
# is not evidence that a merge is safe.
if ! info="$(ghpr --json baseRefName,headRefName,headRefOid,statusCheckRollup 2>/dev/null)"; then
  block 'could not look up the pull request; refusing to auto-merge.'
fi
if ! base="$(printf '%s' "$info" | jq -er '.baseRefName | strings | select(length > 0)' 2>/dev/null)" ||
   ! head="$(printf '%s' "$info" | jq -er '.headRefName | strings | select(length > 0)' 2>/dev/null)" ||
   ! head_sha="$(printf '%s' "$info" | jq -er '.headRefOid | strings | select(length > 0)' 2>/dev/null)"; then
  block 'pull-request lookup returned malformed JSON; refusing to auto-merge.'
fi
is_sha "$head_sha" || block 'pull-request head SHA is malformed; refusing to auto-merge.'

# Make the merge API itself reject a concurrent head update after this hook
# returns. A preflight-only SHA comparison would leave a check-to-merge race.
[ "$match_sha" = "$head_sha" ] ||
  block "--match-head-commit ($match_sha) must match PR head SHA ($head_sha)."

case "$base" in
  epic/*) [ -n "${base#epic/}" ] || block "base '$base' is not a canonical epic branch." ;;
  dev|main|master|release/*) block "never auto-merge into $base. A human must review and merge via the GitHub UI." ;;
  *) block "base '$base' is not a canonical epic branch." ;;
esac
case "$head" in
  issue/*) [ -n "${head#issue/}" ] || block "head '$head' is not a canonical issue branch." ;;
  *) block "head '$head' is not a canonical issue branch." ;;
esac

# GitHub is authoritative for CI. A local receipt is supplementary evidence,
# never a substitute for a completed successful direct ci check.
if ! printf '%s' "$info" | jq -e '
  (.statusCheckRollup | arrays) as $checks
  | any($checks[];
      .__typename == "CheckRun"
      and .name == "ci"
      and .workflowName == "CI"
      and .status == "COMPLETED"
      and .conclusion == "SUCCESS")
' >/dev/null 2>&1; then
  block "GitHub check 'ci' is not completed successfully for $head_sha."
fi

gd="$(git rev-parse --git-dir 2>/dev/null)" || block 'not inside a Git repository.'
slug="$(printf '%s' "$head" | tr '/' '_')"
receipt="$gd/keiko-audit/$slug.json"
vreceipt="$gd/keiko-verify/$slug.json"

[ -f "$receipt" ] || block "no keiko-issue-audit receipt for $head."
[ -f "$vreceipt" ] || block "no green verify receipt for $head."
if ! findings="$(json_string "$receipt" '.findings')" ||
   ! user_facing="$(json_string "$receipt" '.user_facing')" ||
   ! audited="$(json_string "$receipt" '.audited_sha')" ||
   ! verified="$(json_string "$vreceipt" '.verified_sha')"; then
  block 'audit or verify receipt is malformed; refusing to auto-merge.'
fi

[ "$findings" = '0' ] || block "audit findings=$findings for $head (need 0)."
is_sha "$audited" && is_sha "$verified" || block 'audit or verify receipt SHA is malformed.'
[ "$audited" = "$head_sha" ] && [ "$verified" = "$head_sha" ] ||
  block "audit SHA ($audited), verify SHA ($verified), and PR head SHA ($head_sha) must match."

case "$user_facing" in
  false)
    printf '[epic-merge-gate] OK: GitHub ci and SHA-bound clean non-user-facing audit allow %s -> %s.\n' "$head" "$base"
    exit 0 ;;
  true)
    uvreceipt="$gd/keiko-ui-verify/$slug.json"
    [ -f "$uvreceipt" ] || block "$head is user-facing but has no ui-verify receipt."
    if ! uv_sha="$(json_string "$uvreceipt" '.ui_verified_sha')"; then
      block 'ui-verify receipt is malformed; refusing to auto-merge.'
    fi
    is_sha "$uv_sha" && [ "$uv_sha" = "$head_sha" ] ||
      block "ui-verify SHA ($uv_sha) must match PR head SHA ($head_sha)."
    if ! comments="$(ghpr --json comments -q '.comments[].body' 2>/dev/null)"; then
      block 'could not read PR comments for the required manual test plan.'
    fi
    printf '%s\n' "$comments" | grep -Fq "<!-- $marker sha=$head_sha -->" ||
      block "$head has no manual-test-plan comment for PR head $head_sha."
    printf '[epic-merge-gate] OK: GitHub ci and SHA-bound user-facing audit evidence allow %s -> %s.\n' "$head" "$base"
    exit 0 ;;
  *) block "user_facing=$user_facing is invalid; refusing to auto-merge." ;;
esac
