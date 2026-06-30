#!/usr/bin/env bash
#
# test-ready-gate.sh — verify ready-gate.sh requires the manual-test-plan comment
# for user-facing PRs and passes through otherwise. Run: bash tests/test-ready-gate.sh

set -uo pipefail

GATE="$(cd "$(dirname "$0")/.." && pwd)/scripts/ready-gate.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin"
cd "$T"
git init -q
git commit -q --allow-empty -m init

pass=0 fail=0
mkrcpt() { # user_facing
  local b slug; b="$(git symbolic-ref --short HEAD)"; slug="$(printf '%s' "$b" | tr '/' '_')"
  mkdir -p .git/keiko-audit
  printf '{"branch":"%s","user_facing":"%s","ts":"t"}\n' "$b" "$1" > ".git/keiko-audit/$slug.json"
}
stubgh() { # present|absent  (the comment body gh returns)
  local body='(no plan)'
  [ "$1" = present ] && body='<!-- keiko:manual-test-plan -->'
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s"\n' "$body" > bin/gh
  chmod +x bin/gh
}
expect() { # description expected-exit
  PATH="$T/bin:$PATH" bash "$GATE" "gh pr ready" >/dev/null 2>&1
  local g=$?
  if [ "$g" -eq "$2" ]; then pass=$((pass+1)); echo "ok   - $1"
  else fail=$((fail+1)); echo "FAIL - $1 (expected $2, got $g)"; fi
}

git checkout -q -b feature-x
expect "non-work branch -> pass through" 0

git checkout -q -b issue/3-x
rm -rf .git/keiko-audit
expect "no audit receipt -> pass through" 0
mkrcpt false; stubgh absent;  expect "non-user-facing -> pass through" 0
mkrcpt true;  stubgh present; expect "user-facing + comment -> allow" 0
mkrcpt true;  stubgh absent;  expect "user-facing, no comment -> block" 1

echo "---"
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
