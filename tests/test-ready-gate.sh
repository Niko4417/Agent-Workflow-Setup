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
printf '/bin/\n' >> .git/info/exclude
git commit -q --allow-empty -m init

pass=0 fail=0
mkrcpt() { # user_facing
  local b slug; b="$(git symbolic-ref --short HEAD)"; slug="$(printf '%s' "$b" | tr '/' '_')"
  mkdir -p .git/keiko-audit
  printf '{"branch":"%s","user_facing":"%s","ts":"t"}\n' "$b" "$1" > ".git/keiko-audit/$slug.json"
}
stubgh() { # sha  (""=no plan comment); embeds a SHA-bound marker
  local body='(no plan)'
  [ -n "${1:-}" ] && body="<!-- keiko:manual-test-plan sha=$1 -->"
  cat > bin/gh <<'SH'
#!/usr/bin/env bash
[ "${GH_LOOKUP_FAIL:-false}" = false ] || exit 1
if [[ "$*" == *headRefName,headRefOid* ]]; then
  [ "${GH_MALFORMED:-false}" = false ] || { echo '{}'; exit 0; }
  printf '{"headRefName":"%s","headRefOid":"%s"}\n' "${GH_BRANCH:-$(git symbolic-ref --short HEAD)}" "${GH_HEAD:-$(git rev-parse HEAD)}"
  exit 0
fi
SH
  printf 'printf "%%s\\n" "%s"\n' "$body" >> bin/gh
  chmod +x bin/gh
}
expect() { # description expected-exit
  PATH="$T/bin:$PATH" bash "$GATE" "${READY_COMMAND:-gh pr ready 99}" >/dev/null 2>&1
  local g=$?
  if [ "$g" -eq "$2" ]; then pass=$((pass+1)); echo "ok   - $1"
  else fail=$((fail+1)); echo "FAIL - $1 (expected $2, got $g)"; fi
}

git checkout -q -b feature-x
expect "non-work branch -> pass through" 0

git checkout -q -b issue/3-x
H="$(git rev-parse HEAD)"
rm -rf .git/keiko-audit
stubgh ""
expect "no audit receipt -> pass through" 0
mkrcpt false; stubgh "$H";  expect "non-user-facing -> pass through" 0
GH_BRANCH=issue/999-other expect "non-user-facing wrong PR branch -> block" 1
GH_HEAD=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa expect "non-user-facing stale remote head -> block" 1
GH_LOOKUP_FAIL=true expect "PR lookup failure -> block" 1
GH_MALFORMED=true expect "malformed PR lookup -> block" 1
READY_COMMAND='gh pr ready 99 --repo other/repo' expect "repository override -> block" 1
READY_COMMAND='gh pr ready' expect "missing selector -> block" 1
mkrcpt true;  stubgh "$H";  expect "user-facing + comment@HEAD -> allow" 0
mkrcpt true;  stubgh "";    expect "user-facing, no comment -> block" 1
mkrcpt true;  stubgh deadbeef; expect "user-facing, stale comment sha -> block" 1

echo "---"
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
