#!/usr/bin/env bash
#
# test-epic-merge-gate.sh — verify epic-merge-gate.sh block/allow/pass-through.
#
# Stubs `gh` on PATH to answer both the PR base/head query and the PR comments
# query, writes a receipt, and asserts the gate's exit code.
# Run: bash tests/test-epic-merge-gate.sh

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

mkreceipt() { # findings user_facing ui_verified
  mkdir -p .git/keiko-audit
  printf '{"branch":"issue/999-demo","issue":"999","audited_sha":"x","findings":"%s","user_facing":"%s","ui_verified":"%s","ts":"t"}\n' \
    "$1" "$2" "$3" > .git/keiko-audit/issue_999-demo.json
}
# stubgh BASE COMMENT  — BASE="" simulates an unresolvable PR; COMMENT=present|absent
stubgh() {
  local base="$1" comment="${2:-absent}" body="(no plan)"
  if [ -z "$base" ]; then printf '#!/usr/bin/env bash\n' > bin/gh; chmod +x bin/gh; return; fi
  [ "$comment" = "present" ] && body='<!-- keiko:manual-test-plan -->'
  cat > bin/gh <<EOF
#!/usr/bin/env bash
for a in "\$@"; do
  case "\$a" in
    *comments*)    printf '%s\n' '$body'; exit 0 ;;
    *baseRefName*) echo '{"baseRefName":"$base","headRefName":"issue/999-demo"}'; exit 0 ;;
  esac
done
EOF
  chmod +x bin/gh
}
expect() { # description expected-exit
  PATH="$T/bin:$PATH" bash "$GATE" "gh pr merge 999" >/dev/null 2>&1
  local got=$?
  if [ "$got" -eq "$2" ]; then pass=$((pass+1)); echo "ok   - $1"
  else fail=$((fail+1)); echo "FAIL - $1 (expected $2, got $got)"; fi
}

stubgh dev;            mkreceipt 0 false unknown; expect "dev base -> blocked"                 1
stubgh main;           mkreceipt 0 false unknown; expect "main base -> blocked"                1
stubgh release/1.2;    mkreceipt 0 false unknown; expect "release base -> blocked"             1
stubgh feat/x-123;     mkreceipt 0 false unknown; expect "clean non-user-facing -> allow"      0
stubgh feat/x-123;     mkreceipt 2 false unknown; expect "findings>0 -> block"                 1
stubgh feat/x-123 present; mkreceipt 0 true true;  expect "UI verified + comment -> allow"      0
stubgh feat/x-123 absent;  mkreceipt 0 true true;  expect "UI verified, no comment -> block"    1
stubgh feat/x-123 present; mkreceipt 0 true false; expect "UI not verified -> block"            1
stubgh feat/x-123 present; mkreceipt 0 true unknown; expect "UI ui_verified unknown -> block"   1
stubgh feat/x-123;     mkreceipt 0 unknown unknown; expect "user_facing unknown -> block"       1
stubgh feat/x-123;     rm -f .git/keiko-audit/*.json; expect "no receipt -> block"              1
stubgh "";             mkreceipt 0 false unknown; expect "unresolvable PR -> fail open"          0

echo "---"
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
