#!/usr/bin/env bash
#
# test-epic-pr-gate.sh — verify epic-pr-gate.sh gates the epic->dev PR on a clean
# integrated audit (+ ui-verify when user-facing). Run: bash tests/test-epic-pr-gate.sh

set -uo pipefail

GATE="$(cd "$(dirname "$0")/.." && pwd)/scripts/epic-pr-gate.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
cd "$T"
git init -q
git commit -q --allow-empty -m init

pass=0 fail=0
expect() { # description expected-exit
  bash "$GATE" >/dev/null 2>&1
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

git checkout -q -b issue/1-x
expect "non-epic branch -> pass through" 0

git checkout -q -b epic/foo
H="$(git rev-parse HEAD)"
rm -rf .git/keiko-audit .git/keiko-ui-verify
expect "epic, no audit receipt -> block" 1
mka deadbeef 0 false;  expect "epic, stale audit receipt -> block" 1
mka "$H" 2 false;      expect "epic, findings>0 -> block" 1
mka "$H" 0 false;      expect "epic, clean non-UI -> allow" 0
mka "$H" 0 true; mku ""; expect "epic, UI, no ui-verify -> block" 1
mka "$H" 0 true; mku "$H"; expect "epic, UI, ui-verify @HEAD -> allow" 0
mka "$H" 0 true; mku deadbeef; expect "epic, UI, ui-verify stale -> block" 1
mka "$H" 0 unknown;    expect "epic, user_facing unknown -> block" 1

echo "---"
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
