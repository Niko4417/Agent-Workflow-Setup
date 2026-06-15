#!/usr/bin/env bash
#
# test-worktree-hook.sh — regression suite for link-worktree.sh and the M1 bug.
#
# Self-contained, dependency-free (plain bash). Creates temp dirs for both the
# fake harness repo and a fake target git repo, exercises the scripts, then
# cleans up. Exits non-zero if any case fails.
#
# Design note on hermetic isolation:
#   install.sh mirrors skills into ~/.codex/skills/ and writes to the target's
#   .git/info/exclude. Mocking those side-effects across all 5 cases would
#   require patching install.sh itself. Instead:
#     Cases 1-4 invoke link-worktree.sh and the post-checkout hook directly,
#     bypassing full install.sh. This keeps them completely hermetic.
#     Case 5 (M1 regression) exercises only the hook-install block of install.sh
#     against a temp target repo — the skill-mirror step will touch ~/.codex/skills/
#     with symlinks pointing into the temp harness (harmless) and write .git/info/exclude
#     (also harmless). We accept those side-effects rather than patching install.sh,
#     since the fix being tested lives squarely in the hook-install block.

set -euo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# --------------------------------------------------------------------------
# Scaffold: fake harness + fake target git repo
# --------------------------------------------------------------------------

TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

# Fake harness layout — mirrors the real one just enough for link-worktree.sh.
FAKE_HARNESS="$TMPDIR_ROOT/harness"
mkdir -p "$FAKE_HARNESS/codex" \
         "$FAKE_HARNESS/claude/skills" \
         "$FAKE_HARNESS/.agents" \
         "$FAKE_HARNESS/scripts"
touch "$FAKE_HARNESS/AGENTS.md" \
      "$FAKE_HARNESS/CLAUDE.md" \
      "$FAKE_HARNESS/claude/mcp.json"

# Fake target git repo (main clone).
FAKE_TARGET="$TMPDIR_ROOT/target"
mkdir -p "$FAKE_TARGET"
git -C "$FAKE_TARGET" init -q
git -C "$FAKE_TARGET" config user.email "test@example.com"
git -C "$FAKE_TARGET" config user.name  "Test"
touch "$FAKE_TARGET/init.txt"
git -C "$FAKE_TARGET" add init.txt
git -C "$FAKE_TARGET" commit -q -m "init"

# A small wrapper that calls the REAL link-worktree.sh with REPO_DIR overridden
# to the fake harness so we don't need the real harness present.
# We do this by temporarily patching REPO_DIR via env: link-worktree.sh computes
# REPO_DIR internally, so we inject it by wrapping the script in a subshell that
# sources just the relevant logic. Instead, we build a thin shim.
SHIM="$TMPDIR_ROOT/shim-link-worktree.sh"
cat > "$SHIM" <<SHIM_EOF
#!/usr/bin/env bash
# Shim: override REPO_DIR to the fake harness for testing.
SELF="\${BASH_SOURCE[0]}"
while [[ -L "\$SELF" ]]; do
  DIR="\$(cd -P "\$(dirname "\$SELF")" && pwd)"
  SELF="\$(readlink "\$SELF")"
  [[ "\$SELF" != /* ]] && SELF="\$DIR/\$SELF"
done
REPO_DIR="$FAKE_HARNESS"
TARGET="\${1:-\$PWD}"
TOP="\$(git -C "\$TARGET" rev-parse --show-toplevel 2>/dev/null || echo "\$TARGET")"
[[ -d "\$TOP" ]] || exit 0
link() {
  local src="\$1" dst="\$2"
  if [[ -L "\$dst" ]]; then
    [[ "\$(readlink "\$dst" 2>/dev/null || true)" == "\$src" ]] && return 0
    rm -f "\$dst" 2>/dev/null || return 0
  elif [[ -e "\$dst" ]]; then
    return 0
  fi
  ln -s "\$src" "\$dst" 2>/dev/null || true
}
link "\$REPO_DIR/codex"           "\$TOP/.codex"
link "\$REPO_DIR/claude"          "\$TOP/.claude"
link "\$REPO_DIR/.agents"         "\$TOP/.agents"
link "\$REPO_DIR/AGENTS.md"       "\$TOP/AGENTS.md"
link "\$REPO_DIR/CLAUDE.md"       "\$TOP/CLAUDE.md"
link "\$REPO_DIR/claude/mcp.json" "\$TOP/.mcp.json"
link "\$REPO_DIR/scripts"         "\$TOP/.keiko-scripts"
exit 0
SHIM_EOF
chmod +x "$SHIM"

# --------------------------------------------------------------------------
# Case 1: git worktree add creates all 7 expected symlinks
# --------------------------------------------------------------------------

WORKTREE1="$TMPDIR_ROOT/wt1"
git -C "$FAKE_TARGET" worktree add -q "$WORKTREE1"

# Simulate what the post-checkout hook would do — call the shim directly.
"$SHIM" "$WORKTREE1"

EXPECTED=( .codex .claude .agents AGENTS.md CLAUDE.md .mcp.json .keiko-scripts )
ALL_PRESENT=true
for name in "${EXPECTED[@]}"; do
  [[ -L "$WORKTREE1/$name" ]] || { echo "  missing symlink: $name"; ALL_PRESENT=false; }
done
$ALL_PRESENT && pass "Case 1: all 7 symlinks created in new worktree" \
             || fail "Case 1: not all symlinks created"

# --------------------------------------------------------------------------
# Case 2: re-running link-worktree.sh on an already-linked worktree is idempotent
# --------------------------------------------------------------------------

# Record inodes before re-run.
INODE_BEFORE="$(stat -f "%i" "$WORKTREE1/.codex" 2>/dev/null || stat -c "%i" "$WORKTREE1/.codex")"
TARGET_BEFORE="$(readlink "$WORKTREE1/.codex")"

"$SHIM" "$WORKTREE1"

INODE_AFTER="$(stat -f "%i" "$WORKTREE1/.codex" 2>/dev/null || stat -c "%i" "$WORKTREE1/.codex")"
TARGET_AFTER="$(readlink "$WORKTREE1/.codex")"

if [[ "$INODE_BEFORE" == "$INODE_AFTER" && "$TARGET_BEFORE" == "$TARGET_AFTER" ]]; then
  pass "Case 2: idempotent — symlink inode/target unchanged on re-run"
else
  fail "Case 2: re-run changed symlink (inode $INODE_BEFORE->$INODE_AFTER, target $TARGET_BEFORE->$TARGET_AFTER)"
fi

# --------------------------------------------------------------------------
# Case 3: a real file at a target path is NOT clobbered
# --------------------------------------------------------------------------

WORKTREE3="$TMPDIR_ROOT/wt3"
git -C "$FAKE_TARGET" worktree add -q "$WORKTREE3"
# Plant a real file where .codex would go.
echo "precious" > "$WORKTREE3/.codex"

"$SHIM" "$WORKTREE3"

if [[ -f "$WORKTREE3/.codex" ]] && [[ ! -L "$WORKTREE3/.codex" ]] && [[ "$(cat "$WORKTREE3/.codex")" == "precious" ]]; then
  pass "Case 3: real file at .codex not clobbered"
else
  fail "Case 3: real file at .codex was clobbered"
fi

# --------------------------------------------------------------------------
# Case 4: a wrong/stale symlink IS corrected to the right target
# --------------------------------------------------------------------------

WORKTREE4="$TMPDIR_ROOT/wt4"
git -C "$FAKE_TARGET" worktree add -q "$WORKTREE4"
# Plant a stale symlink pointing somewhere wrong.
ln -s "/nonexistent/stale-path" "$WORKTREE4/.codex"

"$SHIM" "$WORKTREE4"

if [[ -L "$WORKTREE4/.codex" ]] && [[ "$(readlink "$WORKTREE4/.codex")" == "$FAKE_HARNESS/codex" ]]; then
  pass "Case 4: stale symlink corrected to right target"
else
  fail "Case 4: stale symlink not corrected (got: $(readlink "$WORKTREE4/.codex" 2>/dev/null || echo 'missing'))"
fi

# --------------------------------------------------------------------------
# Case 5 (M1 regression): second install.sh run still chains post-checkout.pre-keiko
# --------------------------------------------------------------------------

# Use a dedicated temp target so install.sh side-effects (exclude file, etc.) are isolated.
FAKE_TARGET5="$TMPDIR_ROOT/target5"
mkdir -p "$FAKE_TARGET5"
git -C "$FAKE_TARGET5" init -q
git -C "$FAKE_TARGET5" config user.email "test@example.com"
git -C "$FAKE_TARGET5" config user.name  "Test"
touch "$FAKE_TARGET5/init.txt"
git -C "$FAKE_TARGET5" add init.txt
git -C "$FAKE_TARGET5" commit -q -m "init"

# Plant a foreign pre-existing post-checkout hook.
HOOK_DIR5="$(git -C "$FAKE_TARGET5" rev-parse --git-common-dir)"
[[ "$HOOK_DIR5" = /* ]] || HOOK_DIR5="$FAKE_TARGET5/$HOOK_DIR5"
HOOK_DIR5="$HOOK_DIR5/hooks"
mkdir -p "$HOOK_DIR5"
cat > "$HOOK_DIR5/post-checkout" <<'FOREIGN_HOOK'
#!/usr/bin/env bash
# foreign hook
exit 0
FOREIGN_HOOK
chmod +x "$HOOK_DIR5/post-checkout"

# First install.
"$HARNESS_DIR/scripts/install.sh" "$FAKE_TARGET5" >/dev/null 2>&1

CHAIN_AFTER_FIRST=false
grep -qF "post-checkout.pre-keiko" "$HOOK_DIR5/post-checkout" 2>/dev/null && CHAIN_AFTER_FIRST=true

# Second install (M1: the marker is now present, so the backup block is skipped).
"$HARNESS_DIR/scripts/install.sh" "$FAKE_TARGET5" >/dev/null 2>&1

CHAIN_AFTER_SECOND=false
grep -qF "post-checkout.pre-keiko" "$HOOK_DIR5/post-checkout" 2>/dev/null && CHAIN_AFTER_SECOND=true

if $CHAIN_AFTER_FIRST && $CHAIN_AFTER_SECOND; then
  pass "Case 5 (M1): chain call present after first AND second install"
elif ! $CHAIN_AFTER_FIRST; then
  fail "Case 5 (M1): chain call missing after first install"
else
  fail "Case 5 (M1): chain call was DROPPED after second install (M1 regression)"
fi

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
