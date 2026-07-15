#!/usr/bin/env bash
# test-epic-merge-gate.sh — regression coverage for the fail-closed epic gate.
set -uo pipefail

GATE="$(cd "$(dirname "$0")/.." && pwd)/scripts/epic-merge-gate.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin"
cd "$T"
git init -q
git commit -q --allow-empty -m init
git checkout -q -b issue/999-demo

SHA=0123456789abcdef0123456789abcdef01234567
OLD=abcdef0123456789abcdef0123456789abcdef0123
pass=0 fail=0

mkreceipt() {
  mkdir -p .git/keiko-audit
  printf '{"audited_sha":"%s","findings":"%s","user_facing":"%s"}\n' "$1" "$2" "$3" > .git/keiko-audit/issue_999-demo.json
}
mkverify() {
  mkdir -p .git/keiko-verify
  [ -n "${1:-}" ] && printf '{"verified_sha":"%s"}\n' "$1" > .git/keiko-verify/issue_999-demo.json || rm -f .git/keiko-verify/issue_999-demo.json
}
mkuiverify() {
  mkdir -p .git/keiko-ui-verify
  [ -n "${1:-}" ] && printf '{"ui_verified_sha":"%s"}\n' "$1" > .git/keiko-ui-verify/issue_999-demo.json || rm -f .git/keiko-ui-verify/issue_999-demo.json
}
stubgh() { # lookup-status base ci-state comment [head]
  local lookup="$1" base="$2" ci="$3" comment="$4" head="${5:-issue/999-demo}" body='' checks
  [ "$comment" = present ] && body="<!-- keiko:manual-test-plan sha=$SHA -->"
  [ "$comment" = stale ] && body="<!-- keiko:manual-test-plan sha=$OLD -->"
  case "$ci" in
    success) checks='[{"__typename":"CheckRun","name":"ci","workflowName":"CI","status":"COMPLETED","conclusion":"SUCCESS"}]' ;;
    missing) checks='[{"__typename":"CheckRun","name":"Gitar","workflowName":"","status":"COMPLETED","conclusion":"SUCCESS"}]' ;;
    pending) checks='[{"__typename":"CheckRun","name":"ci","workflowName":"CI","status":"IN_PROGRESS","conclusion":""}]' ;;
    failure) checks='[{"__typename":"CheckRun","name":"ci","workflowName":"CI","status":"COMPLETED","conclusion":"FAILURE"}]' ;;
    skipped) checks='[{"__typename":"CheckRun","name":"ci","workflowName":"CI","status":"COMPLETED","conclusion":"SKIPPED"}]' ;;
    cancelled) checks='[{"__typename":"CheckRun","name":"ci","workflowName":"CI","status":"COMPLETED","conclusion":"CANCELLED"}]' ;;
    duplicate) checks='[{"__typename":"CheckRun","name":"ci","workflowName":"CI","status":"COMPLETED","conclusion":"FAILURE"},{"__typename":"CheckRun","name":"ci","workflowName":"CI","status":"COMPLETED","conclusion":"SUCCESS"}]' ;;
    wrong-workflow) checks='[{"__typename":"CheckRun","name":"ci","workflowName":"Untrusted","status":"COMPLETED","conclusion":"SUCCESS"}]' ;;
    status-context) checks='[{"__typename":"StatusContext","context":"ci","state":"SUCCESS"}]' ;;
    *) checks='null' ;;
  esac
  cat > bin/gh <<EOF
#!/usr/bin/env bash
case " \$* " in
  *' comments '*) [ '$comment' = lookup-fail ] && exit 1; printf '%s\\n' '$body'; exit 0 ;;
esac
[ '$lookup' = fail ] && exit 1
[ '$lookup' = malformed ] && { printf '%s\\n' '{not-json'; exit 0; }
printf '%s\\n' '{"baseRefName":"$base","headRefName":"$head","headRefOid":"$SHA","statusCheckRollup":$checks}'
EOF
  chmod +x bin/gh
}
expect() {
  local command="gh pr merge 999 --auto --squash --match-head-commit $SHA"
  case "${3:-match}" in
    missing-match) command='gh pr merge 999 --auto --squash' ;;
    stale-match) command="gh pr merge 999 --auto --squash --match-head-commit $OLD" ;;
    admin) command="gh pr merge 999 --auto --squash --admin=true --match-head-commit $SHA" ;;
    fake-body) command="gh pr merge 999 --auto --squash --body '--match-head-commit $SHA'" ;;
    fake-body-equals) command="gh pr merge 999 --auto --squash --body '--match-head-commit=$SHA'" ;;
    equals-match) command="gh pr merge 999 --auto --squash --match-head-commit=$SHA" ;;
    repo-override) command="gh pr merge 999 --auto --squash -R other/repo --match-head-commit $SHA" ;;
    url-selector) command="gh pr merge https://github.com/owner/repo/pull/999 --auto --squash --match-head-commit $SHA" ;;
    branch-selector) command="gh pr merge issue/999-demo --auto --squash --match-head-commit $SHA" ;;
    flags-first) command="gh pr merge --auto 999 --squash --match-head-commit $SHA" ;;
    chained) command="gh pr merge 999 --auto --squash --match-head-commit $SHA; gh pr merge 1000 --admin" ;;
    alternate-executable) command="./gh pr merge 999 --auto --squash --match-head-commit $SHA" ;;
  esac
  PATH="$T/bin:$PATH" bash "$GATE" "$command" >/dev/null 2>&1
  local got=$?
  if [ "$got" -eq "$2" ]; then pass=$((pass + 1)); echo "ok   - $1"; else fail=$((fail + 1)); echo "FAIL - $1 (expected $2, got $got)"; fi
}
ready_non_ui() { mkreceipt "$SHA" 0 false; mkverify "$SHA"; mkuiverify "$SHA"; }
ready_ui() { mkreceipt "$SHA" 0 true; mkverify "$SHA"; mkuiverify "$SHA"; }

stubgh fail epic/demo success absent; ready_non_ui; expect 'PR lookup failure blocks' 1
stubgh malformed epic/demo success absent; ready_non_ui; expect 'malformed PR JSON blocks' 1
for base in dev main master release/1.2 feature/arbitrary; do
  stubgh ok "$base" success absent; ready_non_ui; expect "forbidden or arbitrary base $base blocks" 1
done
stubgh ok epic/demo success absent feature/arbitrary; ready_non_ui; expect 'non-issue head blocks' 1
stubgh ok epic/demo missing absent; ready_non_ui; expect 'missing ci blocks' 1
stubgh ok epic/demo pending absent; ready_non_ui; expect 'pending ci blocks' 1
stubgh ok epic/demo failure absent; ready_non_ui; expect 'failing ci blocks' 1
stubgh ok epic/demo skipped absent; ready_non_ui; expect 'skipped ci blocks' 1
stubgh ok epic/demo cancelled absent; ready_non_ui; expect 'cancelled ci blocks' 1
stubgh ok epic/demo wrong-workflow absent; ready_non_ui; expect 'same-name check from another workflow blocks' 1
stubgh ok epic/demo status-context absent; ready_non_ui; expect 'legacy status context named ci blocks' 1
stubgh ok epic/demo success absent; ready_non_ui; expect 'missing merge-time head guard blocks' 1 missing-match
stubgh ok epic/demo success absent; ready_non_ui; expect 'stale merge-time head guard blocks' 1 stale-match
stubgh ok epic/demo success absent; ready_non_ui; expect 'admin bypass flag blocks' 1 admin
stubgh ok epic/demo success absent; ready_non_ui; expect 'fake head guard inside body blocks' 1 fake-body
stubgh ok epic/demo success absent; ready_non_ui; expect 'fake equals-form head guard inside body blocks' 1 fake-body-equals
stubgh ok epic/demo success absent; ready_non_ui; expect 'repository override blocks' 1 repo-override
stubgh ok epic/demo success absent; ready_non_ui; expect 'URL selector blocks' 1 url-selector
stubgh ok epic/demo success absent; ready_non_ui; expect 'branch selector blocks' 1 branch-selector
stubgh ok epic/demo success absent; ready_non_ui; expect 'flags before numeric selector block' 1 flags-first
stubgh ok epic/demo success absent; ready_non_ui; expect 'shell chaining blocks' 1 chained
stubgh ok epic/demo success absent; ready_non_ui; expect 'alternate gh executable blocks' 1 alternate-executable
stubgh ok epic/demo success absent; mkreceipt "$OLD" 0 false; mkverify "$SHA"; mkuiverify "$SHA"; expect 'stale audit head blocks' 1
stubgh ok epic/demo success absent; mkreceipt "$SHA" 0 false; mkverify "$OLD"; mkuiverify "$SHA"; expect 'stale verify head blocks' 1
stubgh ok epic/demo success absent; rm -f .git/keiko-audit/*.json; mkverify "$SHA"; mkuiverify "$SHA"; expect 'missing audit receipt blocks' 1
stubgh ok epic/demo success absent; mkreceipt "$SHA" 0 false; mkverify ''; mkuiverify "$SHA"; expect 'missing verify receipt blocks' 1
stubgh ok epic/demo success absent; mkreceipt "$SHA" 2 false; mkverify "$SHA"; mkuiverify "$SHA"; expect 'audit findings block' 1
stubgh ok epic/demo success absent; mkreceipt "$SHA" 0 unknown; mkverify "$SHA"; mkuiverify "$SHA"; expect 'invalid user-facing classification blocks' 1
stubgh ok epic/demo success absent; ready_non_ui; expect 'happy non-user-facing child allows' 0
stubgh ok epic/demo duplicate absent; ready_non_ui; expect 'successful ci rerun among rollup entries allows' 0
stubgh ok epic/demo success absent; ready_non_ui; expect 'equals-form merge-time head guard allows' 0 equals-match
stubgh ok epic/demo success present; ready_ui; expect 'user-facing receipt and comment allow' 0
stubgh ok epic/demo success absent; ready_ui; expect 'user-facing missing comment blocks' 1
stubgh ok epic/demo success lookup-fail; ready_ui; expect 'user-facing comment lookup failure blocks' 1
stubgh ok epic/demo success stale; ready_ui; expect 'user-facing stale comment blocks' 1
stubgh ok epic/demo success present; mkreceipt "$SHA" 0 true; mkverify "$SHA"; mkuiverify ''; expect 'user-facing missing UI receipt blocks' 1
stubgh ok epic/demo success present; mkreceipt "$SHA" 0 true; mkverify "$SHA"; mkuiverify "$OLD"; expect 'user-facing stale UI receipt blocks' 1

echo '---'
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
