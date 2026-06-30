#!/usr/bin/env bash
#
# test-dev-pr-gate.sh — verify dev-pr-gate.sh gates PRs into dev (issue->dev or
# epic->dev) on a clean audit (+ ui-verify when user-facing), and passes through
# non-dev bases. Run: bash tests/test-dev-pr-gate.sh

set -uo pipefail

GATE="$(cd "$(dirname "$0")/.." && pwd)/scripts/dev-pr-gate.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
cd "$T"
git init -q
git commit -q --allow-empty -m init

pass=0 fail=0
expect() { # description expected-exit cmd
  bash "$GATE" "$3" >/dev/null 2>&1
  local g=$?
  if [ "$g" -eq "$2" ]; then pass=$((pass+1)); echo "ok   - $1"
  else fail=$((fail+1)); echo "FAIL - $1 (expected $2, got $g)"; fi
}
mka() { # audited_sha findings user_facing
  local b slug; b="$(git symbolic-ref --short HEAD)"; slug="$(printf '%s' "$b" | tr '/' '_')"
  mkdir -p .git/keiko-audit
  printf '{"branch":"%s","audited_sha":"%s","findings":"%s","user_facing":"%s","ts":"t"}\n' "$b" "$1" "$2" "$3" > ".git/keiko-audit/$slug.json"
}
mku() { # ui_verified_sha  ("" => remove)
  local b slug; b="$(git symbolic-ref --short HEAD)"; slug="$(printf '%s' "$b" | tr '/' '_')"
  mkdir -p .git/keiko-ui-verify
  if [ -z "${1:-}" ]; then rm -f ".git/keiko-ui-verify/$slug.json"; return; fi
  printf '{"branch":"%s","ui_verified_sha":"%s","ts":"t"}\n' "$b" "$1" > ".git/keiko-ui-verify/$slug.json"
}

git checkout -q -b feature-x
expect "non-work branch -> pass through" 0 "gh pr create"

git checkout -q -b issue/7-x
H="$(git rev-parse HEAD)"
mka "$H" 0 false
expect "issue->epic (--base epic/foo) -> pass through" 0 "gh pr create --base epic/foo"
expect "issue->dev, clean non-UI -> allow" 0 "gh pr create --base dev"
expect "issue->dev, default base (no --base) -> allow" 0 "gh pr create"
rm -rf .git/keiko-audit
expect "issue->dev, no audit receipt -> block" 1 "gh pr create"
mka deadbeef 0 false; expect "issue->dev, stale audit -> block" 1 "gh pr create"
mka "$H" 2 false;     expect "issue->dev, findings>0 -> block" 1 "gh pr create"
mka "$H" 0 true; mku ""; expect "issue->dev, UI, no ui-verify -> block" 1 "gh pr create"
mka "$H" 0 true; mku "$H"; expect "issue->dev, UI, ui-verify @HEAD -> allow" 0 "gh pr create"
mka "$H" 0 unknown;   expect "issue->dev, user_facing unknown -> block" 1 "gh pr create"

git checkout -q -b epic/foo
H2="$(git rev-parse HEAD)"
mka "$H2" 0 false
expect "epic->dev, clean non-UI -> allow" 0 "gh pr create --base dev"

echo "---"
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
