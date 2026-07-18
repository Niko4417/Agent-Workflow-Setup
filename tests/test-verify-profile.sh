#!/usr/bin/env bash
#
# test-verify-profile.sh — profile-aware behavior of verify.sh and
# ui-verify-receipt.sh. Proves keiko-native routes verify to `npm run quality`
# (+ audit) while keiko-web keeps its legacy CI-mirror steps, and that the
# ui-verify Playwright guard applies to keiko-web but not to keiko-native's
# desktop journey. Uses a stub `npm` so no real project is needed.
# Run: bash tests/test-verify-profile.sh

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

# Stub npm: log every invocation, always succeed.
mkdir -p "$T/bin"
cat > "$T/bin/npm" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$NPM_LOG"
case "$*" in *"${NPM_FAIL:-__nomatch__}"*) exit 1 ;; esac
exit 0
STUB
chmod +x "$T/bin/npm"
export PATH="$T/bin:$PATH"

cd "$T"
git init -q
printf '{"scripts":{"typecheck":"true","lint":"true","quality":"true"}}\n' > package.json

pass=0 fail=0
check() { # description condition-cmd...
  if "${@:2}"; then pass=$((pass+1)); echo "ok   - $1"
  else fail=$((fail+1)); echo "FAIL - $1"; fi
}

# --- verify.sh routing ---
native_markers() { touch CONTEXT.md; mkdir -p docs/planning quality; touch docs/planning/decision-addendum.md quality/project.json; }

# keiko-native -> npm run quality (+ audit)
native_markers
export NPM_LOG="$T/native.log"; : > "$NPM_LOG"
bash "$ROOT/scripts/verify.sh" >/dev/null 2>&1
check "native: verify runs 'npm run quality'"   grep -q "run quality" "$NPM_LOG"
check "native: verify runs 'npm audit'"          grep -q "audit --audit-level=high" "$NPM_LOG"
check "native: verify does NOT run legacy typecheck" bash -c '! grep -q "run typecheck" "$1"' _ "$NPM_LOG"

# keiko-web (no native markers) -> legacy CI-mirror steps, never `run quality`
rm -rf CONTEXT.md docs quality
export NPM_LOG="$T/web.log"; : > "$NPM_LOG"
bash "$ROOT/scripts/verify.sh" >/dev/null 2>&1
check "web: verify runs legacy 'npm run typecheck'" grep -q "run typecheck" "$NPM_LOG"
check "web: verify does NOT run 'npm run quality'"  bash -c '! grep -q "run quality" "$1"' _ "$NPM_LOG"

# --- ui-verify-receipt.sh Playwright guard ---
git commit -q --allow-empty -m init
UIV="$ROOT/scripts/ui-verify-receipt.sh"

# keiko-web: a non-Playwright command is rejected (exit 2), Playwright accepted.
rm -rf CONTEXT.md docs quality
KEIKO_PROFILE=keiko-web bash "$UIV" 42 -- true >/dev/null 2>&1
check "web: non-Playwright journey command rejected" [ "$?" -eq 2 ]

# keiko-native: a non-Playwright desktop journey command is accepted and stamps a receipt.
native_markers
KEIKO_PROFILE=keiko-native bash "$UIV" 42 -- true >/dev/null 2>&1
g=$?
check "native: non-Playwright journey command accepted" [ "$g" -eq 0 ]
check "native: ui-verify receipt written" bash -c 'ls .git/keiko-ui-verify/*.json >/dev/null 2>&1'

# --- agent:pre-pr precedence (issue #12) ---
printf '{"scripts":{"typecheck":"true","quality":"true","codex:pre-pr":"true","agent:pre-pr":"true"}}\n' > package.json

# keiko-native + agent:pre-pr present -> runs it once, NOT quality/audit
native_markers
export NPM_LOG="$T/ap-native.log"; : > "$NPM_LOG"
bash "$ROOT/scripts/verify.sh" >/dev/null 2>&1
check "native: agent:pre-pr takes precedence"          grep -q "run agent:pre-pr" "$NPM_LOG"
check "native: agent:pre-pr present -> no 'run quality'" bash -c '! grep -q "run quality" "$1"' _ "$NPM_LOG"
check "native: agent:pre-pr present -> no audit"        bash -c '! grep -q "audit" "$1"' _ "$NPM_LOG"
check "native: agent:pre-pr invoked exactly once"       bash -c '[ "$(grep -c "run agent:pre-pr" "$1")" = "1" ]' _ "$NPM_LOG"

# keiko-web + agent:pre-pr present -> runs it once, NOT codex:pre-pr / legacy
rm -rf CONTEXT.md docs quality
export NPM_LOG="$T/ap-web.log"; : > "$NPM_LOG"
bash "$ROOT/scripts/verify.sh" >/dev/null 2>&1
check "web: agent:pre-pr takes precedence"             grep -q "run agent:pre-pr" "$NPM_LOG"
check "web: agent:pre-pr present -> no codex:pre-pr"    bash -c '! grep -q "codex:pre-pr" "$1"' _ "$NPM_LOG"
check "web: agent:pre-pr present -> no legacy typecheck" bash -c '! grep -q "run typecheck" "$1"' _ "$NPM_LOG"

# non-zero agent:pre-pr -> verification fails (no green receipt)
export NPM_LOG="$T/ap-fail.log"; : > "$NPM_LOG"
NPM_FAIL="agent:pre-pr" bash "$ROOT/scripts/verify.sh" >/dev/null 2>&1
check "agent:pre-pr non-zero -> verify.sh fails" [ "$?" -ne 0 ]

echo "---"
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
