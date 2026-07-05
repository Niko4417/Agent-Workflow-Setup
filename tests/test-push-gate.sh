#!/usr/bin/env bash
#
# test-push-gate.sh — verify push-gate.sh re-requires verify + clean audit when
# pushing to an OPEN PR targeting dev, and passes through otherwise.
# Run: bash tests/test-push-gate.sh

set -uo pipefail

GATE="$(cd "$(dirname "$0")/.." && pwd)/scripts/push-gate.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin"
cd "$T"
git init -q
git commit -q --allow-empty -m init

pass=0 fail=0
mkverify() { # verified_sha  ("" => remove)
  local b slug; b="$(git symbolic-ref --short HEAD)"; slug="$(printf '%s' "$b" | tr '/' '_')"
  mkdir -p .git/keiko-verify
  if [ -z "${1:-}" ]; then rm -f ".git/keiko-verify/$slug.json"; return; fi
  printf '{"branch":"%s","verified_sha":"%s","ts":"t"}\n' "$b" "$1" > ".git/keiko-verify/$slug.json"
}
mkaudit() { # audited_sha findings user_facing
  local b slug; b="$(git symbolic-ref --short HEAD)"; slug="$(printf '%s' "$b" | tr '/' '_')"
  mkdir -p .git/keiko-audit
  printf '{"branch":"%s","audited_sha":"%s","findings":"%s","user_facing":"%s","ts":"t"}\n' "$b" "$1" "$2" "$3" > ".git/keiko-audit/$slug.json"
}
stubgh() { # state base   (state="" => no PR)
  if [ -z "$1" ]; then printf '#!/usr/bin/env bash\n' > bin/gh; chmod +x bin/gh; return; fi
  cat > bin/gh <<EOF
#!/usr/bin/env bash
echo '{"state":"$1","baseRefName":"$2"}'
EOF
  chmod +x bin/gh
}
expect() { # description expected-exit
  PATH="$T/bin:$PATH" bash "$GATE" >/dev/null 2>&1
  local g=$?
  if [ "$g" -eq "$2" ]; then pass=$((pass+1)); echo "ok   - $1"
  else fail=$((fail+1)); echo "FAIL - $1 (expected $2, got $g)"; fi
}

git checkout -q -b feature-x
stubgh OPEN dev
expect "non-work branch -> pass through" 0

git checkout -q -b issue/2-x
H="$(git rev-parse HEAD)"
stubgh "";            expect "no PR -> pass through" 0
stubgh MERGED dev;    expect "merged PR -> pass through" 0
stubgh OPEN epic/foo; expect "open PR to epic (non-dev) -> pass through" 0

mkverify "$H"; mkaudit "$H" 0 false; stubgh OPEN dev
expect "open ->dev PR, verify+clean audit -> allow" 0
mkverify ""; expect "open ->dev PR, no verify receipt -> block" 1
mkverify "$H"; mkaudit "$H" 2 false; expect "open ->dev PR, findings>0 -> block" 1

echo "---"
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
