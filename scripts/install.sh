#!/usr/bin/env bash
#
# install.sh — symlink this Agent Workflow Setup into a target repo.
#
# Usage:
#   scripts/install.sh /path/to/target-repo
#   scripts/install.sh            # defaults to $KEIKO_ROOT or prompts
#
# Effect (target repo is git-ignored for these paths — nothing is committed there):
#   <target>/.codex   -> <this-repo>/codex
#   <target>/.claude  -> <this-repo>/claude
#   <target>/.agents  -> <this-repo>/.agents
#
# Existing real .claude / .codex dirs in the target are backed up to *.bak.
# An existing .claude/settings.local.json (per-machine) is preserved into
# claude/settings.local.json (git-ignored here).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-${KEIKO_ROOT:-}}"

if [[ -z "$TARGET" ]]; then
  echo "ERROR: no target repo given." >&2
  echo "Usage: scripts/install.sh /path/to/target-repo" >&2
  exit 1
fi

TARGET="$(cd "$TARGET" && pwd)"
if [[ ! -d "$TARGET/.git" ]]; then
  echo "WARNING: $TARGET does not look like a git repo (no .git)." >&2
fi

# Detect the target's product profile (honors a KEIKO_PROFILE override). keiko-native
# owns its own AGENTS.md / CLAUDE.md (machine-checked contract), so we AUGMENT — never
# overlay those — per docs/target-repository-boundary.md.
PROFILE="$(cd "$TARGET" && KEIKO_PROFILE="${KEIKO_PROFILE:-}" bash "$REPO_DIR/scripts/profile-detect.sh")"

echo "Installing Agent Workflow Setup"
echo "  source:  $REPO_DIR"
echo "  target:  $TARGET"
echo "  profile: $PROFILE"
echo

link_one() {
  local src="$1" dst="$2"
  if [[ -L "$dst" ]]; then
    echo "  ~ replacing existing symlink $dst"
    rm -f "$dst"
  elif [[ -e "$dst" ]]; then
    echo "  ! backing up existing $dst -> ${dst}.bak"
    rm -rf "${dst}.bak"
    mv "$dst" "${dst}.bak"
  fi
  ln -s "$src" "$dst"
  echo "  + $dst -> $src"
}

# Preserve a per-machine settings.local.json before we replace .claude.
if [[ -f "$TARGET/.claude/settings.local.json" && ! -L "$TARGET/.claude" ]]; then
  echo "  > preserving settings.local.json (per-machine, git-ignored here)"
  cp "$TARGET/.claude/settings.local.json" "$REPO_DIR/claude/settings.local.json"
fi

link_one "$REPO_DIR/codex"   "$TARGET/.codex"
link_one "$REPO_DIR/claude"  "$TARGET/.claude"
link_one "$REPO_DIR/.agents" "$TARGET/.agents"

# Root entry docs both harnesses read at the repo root.
# (Codex reads AGENTS.md as its project doc; Claude reads CLAUDE.md.)
# keiko-native owns these — do NOT overlay them; the target's own contract governs
# and our orchestration is delivered via the skills + .codex/.claude configs (augment).
if [[ "$PROFILE" == "keiko-native" ]]; then
  echo "  = keiko-native: preserving the repo's own AGENTS.md / CLAUDE.md (augment, not replace)"
else
  link_one "$REPO_DIR/AGENTS.md" "$TARGET/AGENTS.md"
  link_one "$REPO_DIR/CLAUDE.md" "$TARGET/CLAUDE.md"
fi

# Project MCP servers for Claude Code (read from the project root).
link_one "$REPO_DIR/claude/mcp.json" "$TARGET/.mcp.json"

# Scripts reachable from the target root (verify.sh, keiko-watch, audit-gate, ...).
# Hooks and skills call them as .keiko-scripts/<name>.
link_one "$REPO_DIR/scripts" "$TARGET/.keiko-scripts"

# Cross-harness skills. Claude finds them under .claude/skills/ (via the .claude
# symlink already created above). Codex skills are GLOBAL, so mirror each one
# into ~/.codex/skills/ so both harnesses invoke the same skill by name.
if [[ -d "$REPO_DIR/claude/skills" ]]; then
  mkdir -p "$HOME/.codex/skills"
  for skill in "$REPO_DIR"/claude/skills/*/; do
    [[ -d "$skill" ]] || continue
    link_one "${skill%/}" "$HOME/.codex/skills/$(basename "$skill")"
  done
fi

# Retire any stale old-workflow contract so there is no confusion.
if [[ -f "$TARGET/project.md" && ! -L "$TARGET/project.md" ]]; then
  echo "  ! retiring old-workflow project.md -> project.md.bak"
  rm -f "$TARGET/project.md.bak"
  mv "$TARGET/project.md" "$TARGET/project.md.bak"
fi

# Ensure the target locally ignores the symlinks WITHOUT touching its committed
# .gitignore (keeps the target repo pristine — nothing becomes committable).
if [[ -d "$TARGET/.git" ]]; then
  EXCLUDE="$TARGET/.git/info/exclude"
  mkdir -p "$(dirname "$EXCLUDE")"
  # No trailing slash: must match symlinks, not just real directories.
  exclude_entries=("/.codex" "/.claude" "/.agents" "/.mcp.json" "/.keiko-scripts" "/.claude.bak" "/.codex.bak")
  # Only exclude the root docs when we actually overlay them (keiko-web). On
  # keiko-native they are the repo's own tracked files — never exclude them.
  [[ "$PROFILE" != "keiko-native" ]] && exclude_entries+=("/AGENTS.md" "/CLAUDE.md")
  for entry in "${exclude_entries[@]}"; do
    if ! grep -qxF "$entry" "$EXCLUDE" 2>/dev/null; then
      echo "$entry" >> "$EXCLUDE"
    fi
  done
  echo "  > ensured /.codex/ /.claude/ /.agents/ are in .git/info/exclude (local only)"
fi

# Worktree harness propagation. A linked worktree is a fresh working directory
# that does NOT inherit the git-ignored symlinks above, so an agent launched in
# one would lose the entire harness. A post-checkout hook (shared via the common
# .git/hooks across every worktree) recreates the symlinks on `git worktree add`.
if [[ -d "$TARGET/.git" ]]; then
  HOOKS_PATH="$(git -C "$TARGET" config --get core.hooksPath || true)"
  if [[ -n "$HOOKS_PATH" ]]; then
    echo "  ! core.hooksPath is set to '$HOOKS_PATH' — the post-checkout hook was NOT installed."
    echo "    To propagate the harness into new worktrees automatically, add a post-checkout"
    echo "    hook in your custom hooks directory that contains:"
    echo "      \"$REPO_DIR/scripts/link-worktree.sh\" \"\$(git rev-parse --show-toplevel)\""
    echo "    Or run it by hand after each \`git worktree add\`:"
    echo "      $REPO_DIR/scripts/link-worktree.sh <worktree-path>"
  else
    COMMON="$(git -C "$TARGET" rev-parse --git-common-dir)"
    # --git-common-dir is relative to the target; make it absolute.
    [[ "$COMMON" = /* ]] || COMMON="$TARGET/$COMMON"
    HOOK_DIR="$COMMON/hooks"
    mkdir -p "$HOOK_DIR"
    HOOK="$HOOK_DIR/post-checkout"
    MARKER="# agent-workflow-setup:link-worktree"
    if [[ -e "$HOOK" ]] && ! grep -qF "$MARKER" "$HOOK" 2>/dev/null; then
      echo "  ! backing up existing post-checkout hook -> post-checkout.pre-keiko"
      rm -f "$HOOK.pre-keiko"
      mv "$HOOK" "$HOOK.pre-keiko"
    fi
    # Compute CHAIN from whether the backup exists, independent of whether this
    # is a first-install or re-run — so a second install.sh invocation doesn't
    # silently drop the call to the still-present pre-keiko hook (M1 fix).
    CHAIN=""
    if [[ -e "$HOOK.pre-keiko" ]]; then
      CHAIN="\"\$(dirname \"\$0\")/post-checkout.pre-keiko\" \"\$@\" || true"
    fi
    cat > "$HOOK" <<EOF
#!/usr/bin/env bash
$MARKER
# Recreate workflow symlinks in every git worktree (they are not inherited).
# Args: \$1 old-HEAD  \$2 new-HEAD  \$3 flag (1 = branch checkout incl. worktree add).
$CHAIN
[ "\$3" = "1" ] || exit 0
"$REPO_DIR/scripts/link-worktree.sh" "\$(git rev-parse --show-toplevel 2>/dev/null || pwd)" >/dev/null 2>&1 || true
exit 0
EOF
    chmod +x "$HOOK"
    echo "  + installed post-checkout hook -> $HOOK"
  fi
fi

echo
echo "Done. Verify with:  ls -la \"$TARGET\"/.codex \"$TARGET\"/.claude \"$TARGET\"/.agents"
