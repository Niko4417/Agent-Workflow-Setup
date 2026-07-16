#!/usr/bin/env bash
#
# test-install-profile.sh — install.sh must AUGMENT keiko-native (never overlay its
# own AGENTS.md / CLAUDE.md) while still overlaying them for keiko-web. Proves the
# boundary-doc invariant (docs/target-repository-boundary.md) and issue #4's
# "Native behavior is not an accidental global default" / merge-authority-preserving
# intent for the setup script. HOME is redirected so the real ~/.codex is untouched.
# Run: bash tests/test-install-profile.sh

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$ROOT/scripts/install.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home"; mkdir -p "$HOME"

pass=0 fail=0
check() { # description condition-cmd...
  if "${@:2}"; then pass=$((pass+1)); echo "ok   - $1"
  else fail=$((fail+1)); echo "FAIL - $1"; fi
}

mk_target() { # dir
  local d="$1"; mkdir -p "$d"; git -C "$d" init -q
}

# --- keiko-web target: root docs ARE overlaid ---
WEB="$T/web"; mk_target "$WEB"; mkdir -p "$WEB/docs/design-system"
bash "$INSTALL" "$WEB" >/dev/null 2>&1
check "web: .codex symlinked"        [ -L "$WEB/.codex" ]
check "web: .keiko-scripts symlinked" [ -L "$WEB/.keiko-scripts" ]
check "web: AGENTS.md overlaid (symlink)" [ -L "$WEB/AGENTS.md" ]
check "web: CLAUDE.md overlaid (symlink)" [ -L "$WEB/CLAUDE.md" ]

# --- keiko-native target: root docs PRESERVED, harness still augmented ---
NAT="$T/native"; mk_target "$NAT"
touch "$NAT/CONTEXT.md"; mkdir -p "$NAT/docs/planning" "$NAT/quality"
touch "$NAT/docs/planning/decision-addendum.md" "$NAT/quality/project.json"
printf 'NATIVE-OWN-AGENTS\n' > "$NAT/AGENTS.md"
printf 'NATIVE-OWN-CLAUDE\n' > "$NAT/CLAUDE.md"
bash "$INSTALL" "$NAT" >/dev/null 2>&1
check "native: .codex symlinked (augment)"    [ -L "$NAT/.codex" ]
check "native: .claude symlinked (augment)"   [ -L "$NAT/.claude" ]
check "native: .agents symlinked (augment)"   [ -L "$NAT/.agents" ]
check "native: .keiko-scripts symlinked"      [ -L "$NAT/.keiko-scripts" ]
check "native: AGENTS.md NOT a symlink"        bash -c '[ ! -L "$1" ]' _ "$NAT/AGENTS.md"
check "native: CLAUDE.md NOT a symlink"        bash -c '[ ! -L "$1" ]' _ "$NAT/CLAUDE.md"
check "native: AGENTS.md content preserved"    grep -qx "NATIVE-OWN-AGENTS" "$NAT/AGENTS.md"
check "native: CLAUDE.md content preserved"    grep -qx "NATIVE-OWN-CLAUDE" "$NAT/CLAUDE.md"
check "native: AGENTS.md not in git exclude"   bash -c '! grep -qxF "/AGENTS.md" "$1/.git/info/exclude" 2>/dev/null' _ "$NAT"

echo "---"
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
