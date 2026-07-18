#!/usr/bin/env bash
#
# test-lifecycle-guard.sh — the exactly-one-status-label fail-closed invariant
# (issue #9: consumers fail closed on zero/multiple/unknown lifecycle-label sets).
# Run: bash tests/test-lifecycle-guard.sh

set -uo pipefail

G="$(cd "$(dirname "$0")/.." && pwd)/scripts/lifecycle-guard.sh"
pass=0 fail=0

expect() { # description expected-exit label...
  "$G" "${@:3}" >/dev/null 2>&1
  local g=$?
  if [ "$g" -eq "$2" ]; then pass=$((pass + 1)); echo "ok   - $1"
  else fail=$((fail + 1)); echo "FAIL - $1 (expected $2, got $g)"; fi
}

expect "exactly one status label -> ok"            0 "type: task" "status: ready"
expect "zero status labels -> fail-closed"         2 "type: task" "area:verification"
expect "two status labels -> fail-closed"          2 "status: ready" "status: in progress"
expect "one status among many non-status -> ok"    0 "type: epic" "status: done" "area:test-intelligence"
expect "no args at all -> fail-closed"             2

# stdin mode
if printf 'status: triaged\ntype: task\n' | "$G" - >/dev/null 2>&1; then
  pass=$((pass + 1)); echo "ok   - stdin: one status label -> ok"
else
  fail=$((fail + 1)); echo "FAIL - stdin: one status label"
fi
if printf 'status: ready\nstatus: blocked\n' | "$G" - >/dev/null 2>&1; then
  fail=$((fail + 1)); echo "FAIL - stdin: two status labels should fail"
else
  pass=$((pass + 1)); echo "ok   - stdin: two status labels -> fail-closed"
fi

echo "---"
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
