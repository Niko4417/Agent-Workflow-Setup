#!/usr/bin/env bash
#
# test-ui-verify-receipt.sh — verify ui-verify-receipt.sh runs the plan and only
# stamps a receipt on a real green exit. Run: bash tests/test-ui-verify-receipt.sh

set -uo pipefail

SCR="$(cd "$(dirname "$0")/.." && pwd)/scripts/ui-verify-receipt.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
cd "$T"
git init -q
git commit -q --allow-empty -m init
git checkout -q -b issue/5-x

pass=0 fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
bad()  { fail=$((fail+1)); echo "FAIL - $1"; }
receipt=".git/keiko-ui-verify/issue_5-x.json"

run() { bash "$SCR" "$@" >/dev/null 2>&1; echo $?; }

[ "$(run 5)" = "2" ] && ok "no command -> usage error" || bad "no command"
[ "$(run 5 -- echo hello)" = "2" ] && ok "non-playwright command -> guard" || bad "guard"

rm -rf .git/keiko-ui-verify
[ "$(run 5 -- sh -c 'echo playwright; exit 1')" = "1" ] && ok "playwright fails -> exit 1" || bad "fail exit"
[ -f "$receipt" ] && bad "receipt written on failure" || ok "no receipt on failure"

[ "$(run 5 -- sh -c 'echo playwright; exit 0')" = "0" ] && ok "playwright green -> exit 0" || bad "green exit"
[ -f "$receipt" ] && ok "receipt written on green" || bad "receipt missing on green"

sha="$(git rev-parse HEAD)"
rsha="$(sed -n 's/.*"ui_verified_sha":"\([^"]*\)".*/\1/p' "$receipt" 2>/dev/null)"
[ "$sha" = "$rsha" ] && ok "receipt sha == HEAD" || bad "receipt sha mismatch"

echo "---"
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
