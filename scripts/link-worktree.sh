#!/usr/bin/env bash
#
# link-worktree.sh — (re)create the workflow symlinks inside a git worktree.
#
# A linked worktree (`git worktree add`) is a fresh working directory and does
# NOT inherit the git-ignored workflow symlinks that live in the main clone. So
# an agent launched in a worktree would be missing CLAUDE.md/AGENTS.md, .claude
# (settings + skills + hooks), .agents (memory) and .keiko-scripts (verify.sh,
# audit-gate.sh) — i.e. the whole governance harness. This recreates them.
#
# Invoked automatically by the post-checkout hook (installed by install.sh), and
# safe to run by hand:  scripts/link-worktree.sh [worktree-dir]
#
# Contract: idempotent, non-destructive (never clobbers a real file already at
# the path), and never fails the caller — always exits 0. The symlink targets are
# absolute, so the same links work from any worktree location, and the worktree
# inherits the shared .git/info/exclude so they stay locally ignored.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-$PWD}"
TOP="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null || echo "$TARGET")"

[[ -d "$TOP" ]] || exit 0

link() {
  local src="$1" dst="$2"
  if [[ -L "$dst" ]]; then
    # Already a symlink: only replace if it points somewhere else.
    [[ "$(readlink "$dst" 2>/dev/null || true)" == "$src" ]] && return 0
    rm -f "$dst" 2>/dev/null || return 0
  elif [[ -e "$dst" ]]; then
    # A real file/dir lives here — never clobber inside a worktree.
    return 0
  fi
  ln -s "$src" "$dst" 2>/dev/null || true
}

link "$REPO_DIR/codex"           "$TOP/.codex"
link "$REPO_DIR/claude"          "$TOP/.claude"
link "$REPO_DIR/.agents"         "$TOP/.agents"
link "$REPO_DIR/AGENTS.md"       "$TOP/AGENTS.md"
link "$REPO_DIR/CLAUDE.md"       "$TOP/CLAUDE.md"
link "$REPO_DIR/claude/mcp.json" "$TOP/.mcp.json"
link "$REPO_DIR/scripts"         "$TOP/.keiko-scripts"

exit 0
