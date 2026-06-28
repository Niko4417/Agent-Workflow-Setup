#!/usr/bin/env bash
#
# test-epic-merge-gate.sh — verify epic-merge-gate.sh block/allow/pass-through.
#
# Stubs `gh` on PATH to control the PR's base/head, writes a receipt, and asserts
# the gate's exit code. Run: bash tests/test-epic-merge-gate.sh

set -uo pipefail

GATE="$(cd "$(dirname "$0")/.." && pwd)/scripts/epic-merge-gate.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin"
cd "$T"
git init -q
git commit -q --allow-empty -m init
git checkout -q -b issue/999-demo

pass=0 fail=0

mkreceipt() { # findings user_facing
  mkdir -p .git/keiko-audit
  printf '{"branch":"issue/999-demo","issue":"999","audited_sha":"x","findings":"%s","user_facing":"%s","ts":"t"}\n' \
    "$1" "$2" > .git/keiko-audit/issue_999-demo.json
}
stubgh() { # baseRefName ("" => gh emits nothing, simulating an unresolvable PR)
  if [ -z "$1" ]; then printf '#!/usr/bin/env bash\n' > bin/gh
  else printf '#!/usr/bin/env bash\necho '"'"'{"baseRefName":"%s","headRefName":"issue/999-demo"}'"'"'\n' "$1" > bin/gh
  fi
  chmod +x bin/gh
}
expect() { # description expected-exit
  PATH="$T/bin:$PATH" bash "$GATE" "gh pr merge 999" >/dev/null 2>&1
  local got=$?
  if [ "$got" -eq "$2" ]; then pass=$((pass+1)); echo "ok   - $1"
  else fail=$((fail+1)); echo "FAIL - $1 (expected $2, got $got)"; fi
}

stubgh dev;           mkreceipt 2 true;   expect "dev base passes through"            0
stubgh release/1.2;   mkreceipt 2 true;   expect "release base passes through"        0
stubgh feat/x-123;    mkreceipt 0 false;  expect "clean non-user-facing -> allow"     0
stubgh feat/x-123;    mkreceipt 2 false;  expect "findings>0 -> block"                1
stubgh feat/x-123;    mkreceipt 0 true;   expect "user-facing -> block"               1
stubgh feat/x-123;    mkreceipt unknown unknown; expect "unknown receipt -> block"    1
stubgh feat/x-123;    rm -f .git/keiko-audit/*.json; expect "no receipt -> block"     1
stubgh "";            mkreceipt 0 false;  expect "unresolvable PR -> fail open"       0

echo "---"
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
