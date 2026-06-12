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

echo "Installing Agent Workflow Setup"
echo "  source: $REPO_DIR"
echo "  target: $TARGET"
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

# Ensure the target locally ignores the symlinks WITHOUT touching its committed
# .gitignore (keeps the target repo pristine — nothing becomes committable).
if [[ -d "$TARGET/.git" ]]; then
  EXCLUDE="$TARGET/.git/info/exclude"
  mkdir -p "$(dirname "$EXCLUDE")"
  for entry in "/.codex/" "/.claude/" "/.agents/"; do
    if ! grep -qxF "$entry" "$EXCLUDE" 2>/dev/null; then
      echo "$entry" >> "$EXCLUDE"
    fi
  done
  echo "  > ensured /.codex/ /.claude/ /.agents/ are in .git/info/exclude (local only)"
fi

echo
echo "Done. Verify with:  ls -la \"$TARGET\"/.codex \"$TARGET\"/.claude \"$TARGET\"/.agents"
