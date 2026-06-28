#!/usr/bin/env bash
#
# test-verify-gate.sh — verify verify-gate.sh block/allow/pass-through.
# Run: bash tests/test-verify-gate.sh

set -uo pipefail

GATE="$(cd "$(dirname "$0")/.." && pwd)/scripts/verify-gate.sh"
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
mkv() { # verified_sha
  local b slug; b="$(git symbolic-ref --short HEAD)"; slug="$(printf '%s' "$b" | tr '/' '_')"
  mkdir -p .git/keiko-verify
  printf '{"branch":"%s","verified_sha":"%s","ts":"t"}\n' "$b" "$1" > ".git/keiko-verify/$slug.json"
}

git checkout -q -b feature-x
expect "non-issue/epic branch -> pass through" 0

git checkout -q -b issue/999-x
rm -rf .git/keiko-verify
expect "issue branch, no receipt -> block" 1
mkv "$(git rev-parse HEAD)"
expect "issue branch, fresh receipt -> allow" 0
mkv "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
expect "issue branch, stale receipt -> block" 1

git checkout -q -b epic/foo
rm -rf .git/keiko-verify
expect "epic branch, no receipt -> block" 1
mkv "$(git rev-parse HEAD)"
expect "epic branch, fresh receipt -> allow" 0

echo "---"
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
