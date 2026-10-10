#!/usr/bin/env bash
#
# test-worktree-hook.sh — regression suite for link-worktree.sh and the M1 bug.
#
# Self-contained, dependency-free (plain bash). Creates temp dirs for both the
# fake harness repo and a fake target git repo, exercises the scripts, then
# cleans up. Exits non-zero if any case fails.
#
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
TMPDIR_ROOT="$(cd -P "$TMPDIR_ROOT" && pwd)"
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

# Run the production linker from the fake harness; do not copy its logic.
SHIM="$FAKE_HARNESS/scripts/link-worktree.sh"
cp "$HARNESS_DIR/scripts/link-worktree.sh" "$SHIM"
chmod +x "$SHIM"
TEST_HOME="$TMPDIR_ROOT/home"
mkdir -p "$TEST_HOME"

# --------------------------------------------------------------------------
# Case 1: git worktree add creates all 5 optional harness symlinks
# --------------------------------------------------------------------------

WORKTREE1="$TMPDIR_ROOT/wt1"
git -C "$FAKE_TARGET" worktree add -q "$WORKTREE1"

# Simulate what the post-checkout hook would do — call the shim directly.
"$SHIM" "$WORKTREE1" 2>"$TMPDIR_ROOT/absent-output"

if [[ ! -e "$WORKTREE1/AGENTS.md" && ! -L "$WORKTREE1/AGENTS.md" && ! -e "$WORKTREE1/CLAUDE.md" && ! -L "$WORKTREE1/CLAUDE.md" ]] &&
   grep -qF "WARNING: target authority document unavailable: AGENTS.md" "$TMPDIR_ROOT/absent-output" &&
   grep -qF "WARNING: target authority document unavailable: CLAUDE.md" "$TMPDIR_ROOT/absent-output"; then
  pass "Case 1: absent authority remains absent and is reported"
else
  fail "Case 1: absent authority replaced or not reported"
fi

EXPECTED=( .codex .claude .agents .mcp.json .keiko-scripts )
ALL_PRESENT=true
for name in "${EXPECTED[@]}"; do
  [[ -L "$WORKTREE1/$name" ]] || { echo "  missing symlink: $name"; ALL_PRESENT=false; }
done
$ALL_PRESENT && pass "Case 1: all 5 optional harness symlinks created in new worktree" \
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
env HOME="$TEST_HOME" "$HARNESS_DIR/scripts/install.sh" "$FAKE_TARGET5" >/dev/null 2>&1

CHAIN_AFTER_FIRST=false
grep -qF "post-checkout.pre-keiko" "$HOOK_DIR5/post-checkout" 2>/dev/null && CHAIN_AFTER_FIRST=true

# Second install (M1: the marker is now present, so the backup block is skipped).
env HOME="$TEST_HOME" "$HARNESS_DIR/scripts/install.sh" "$FAKE_TARGET5" >/dev/null 2>&1

CHAIN_AFTER_SECOND=false
grep -qF "post-checkout.pre-keiko" "$HOOK_DIR5/post-checkout" 2>/dev/null && CHAIN_AFTER_SECOND=true

if $CHAIN_AFTER_FIRST && $CHAIN_AFTER_SECOND; then
  pass "Case 5 (M1): chain call present after first AND second install"
elif ! $CHAIN_AFTER_FIRST; then
  fail "Case 5 (M1): chain call missing after first install"
else
  fail "Case 5 (M1): chain call was DROPPED after second install (M1 regression)"
fi

# The installed hook must surface missing authority instead of hiding warnings.
(cd "$FAKE_TARGET5" && env HOME="$TEST_HOME" bash "$HOOK_DIR5/post-checkout" 0 0 1) \
  >"$TMPDIR_ROOT/hook-output" 2>&1
if grep -qF "WARNING: target authority document unavailable: AGENTS.md" "$TMPDIR_ROOT/hook-output" &&
   grep -qF "WARNING: target authority document unavailable: CLAUDE.md" "$TMPDIR_ROOT/hook-output" &&
   [[ ! -e "$FAKE_TARGET5/AGENTS.md" && ! -L "$FAKE_TARGET5/AGENTS.md" ]]; then
  pass "Case 5: installed hook reports absent authority without replacing it"
else
  fail "Case 5: installed hook hides absence or creates authority"
fi

# Case 6: target-owned authority files and symlinks survive every linker run.
for kind in regular symlink dangling; do
  AUTHORITY_TARGET="$TMPDIR_ROOT/authority-$kind"
  mkdir -p "$AUTHORITY_TARGET"
  git -C "$AUTHORITY_TARGET" init -q
  for doc in AGENTS.md CLAUDE.md; do
    case "$kind" in
      regular) printf 'target-owned\n' > "$AUTHORITY_TARGET/$doc" ;;
      symlink)
        printf 'target-owned\n' > "$AUTHORITY_TARGET/owned-$doc"
        ln -s "owned-$doc" "$AUTHORITY_TARGET/$doc"
        ;;
      dangling) ln -s "missing-$doc" "$AUTHORITY_TARGET/$doc" ;;
    esac
  done
  "$SHIM" "$AUTHORITY_TARGET" 2>"$TMPDIR_ROOT/authority-output"
  "$SHIM" "$AUTHORITY_TARGET" 2>>"$TMPDIR_ROOT/authority-output"
  for doc in AGENTS.md CLAUDE.md; do
    case "$kind" in
      regular)
        if [[ ! -L "$AUTHORITY_TARGET/$doc" ]] && grep -qxF 'target-owned' "$AUTHORITY_TARGET/$doc"; then
          pass "Case 6: regular $doc preserved"
        else fail "Case 6: regular $doc replaced"; fi
        ;;
      symlink|dangling)
        expected="owned-$doc"
        [[ "$kind" == "dangling" ]] && expected="missing-$doc"
        if [[ -L "$AUTHORITY_TARGET/$doc" && "$(readlink "$AUTHORITY_TARGET/$doc")" == "$expected" ]]; then
          pass "Case 6: $kind $doc preserved"
        else fail "Case 6: $kind $doc replaced"; fi
        if [[ "$kind" == "dangling" ]]; then
          if grep -qF "WARNING: target authority document unavailable: $doc" "$TMPDIR_ROOT/authority-output"; then
            pass "Case 6: dangling $doc reported"
          else fail "Case 6: dangling $doc not reported"; fi
        fi
        ;;
    esac
  done
done

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
