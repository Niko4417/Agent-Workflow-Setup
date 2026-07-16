#!/usr/bin/env bash
#
# test-profile-detect.sh — profile selection matrix for scripts/profile-detect.sh.
# Proves keiko-web is the safe default and keiko-native is chosen ONLY when all its
# markers are present (never an accidental default) — issue #4 AC: profile selection.
# Run: bash tests/test-profile-detect.sh

set -uo pipefail

DETECT="$(cd "$(dirname "$0")/.." && pwd)/scripts/profile-detect.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
cd "$T"
git init -q

pass=0 fail=0
expect() { # description expected-profile [env-override]
  local got
  got="$(env ${3:+KEIKO_PROFILE="$3"} bash "$DETECT")"
  if [ "$got" = "$2" ]; then pass=$((pass+1)); echo "ok   - $1"
  else fail=$((fail+1)); echo "FAIL - $1 (expected $2, got $got)"; fi
}
reset() { rm -rf CONTEXT.md docs quality; }
native_markers() { touch CONTEXT.md; mkdir -p docs/planning quality; touch docs/planning/decision-addendum.md quality/project.json; }

reset
expect "bare repo -> safe web default" "keiko-web"

reset; mkdir -p docs/design-system
expect "design-system only -> web" "keiko-web"

reset; native_markers
expect "all native markers -> native" "keiko-native"

# Partial markers must NOT trip native (no accidental Native default).
reset; touch CONTEXT.md
expect "only CONTEXT.md -> web (not accidental native)" "keiko-web"
reset; touch CONTEXT.md; mkdir -p docs/planning; touch docs/planning/decision-addendum.md
expect "CONTEXT + addendum, no project.json -> web" "keiko-web"

# Explicit env override always wins.
reset; native_markers
expect "native markers + override=web -> web" "keiko-web" "keiko-web"
reset
expect "bare repo + override=native -> native" "keiko-native" "keiko-native"

echo "---"
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
