# pr-reviewer memory

## 2026-06-15 — harness propagation / shell hook patterns

**Heredoc CHAIN re-run bug (install.sh pattern):** When a hook installer writes a shell
script via heredoc that conditionally includes a chain call (variable $CHAIN), re-running
the installer after the marker is present skips the CHAIN assignment but still rewrites the
hook — silently dropping the chain line. Pattern to check for: any `cat > "$HOOK" <<EOF`
block inside a marker guard that has conditional variables set before the guard.

**BASH_SOURCE[0] via symlink:** `cd "$(dirname "${BASH_SOURCE[0]}")/.."` resolves relative
to the invocation path, NOT the symlink target. If a script is invoked via a symlink
(e.g. `.keiko-scripts/link-worktree.sh`), REPO_DIR resolves to the symlink's parent dir,
not the actual script's home. The hook invokes the script by absolute path (correct); the
manual-use-via-symlink path silently fails to locate sources.

**post-checkout / worktree add semantics (confirmed on git 2.50.1):**

- `git worktree add` fires post-checkout with `$3=1`, PWD set to the NEW worktree dir.
- `git checkout <branch>` also fires with `$3=1`, PWD set to the main clone.
- `git worktree add --no-checkout` does NOT fire post-checkout at all.
- post-checkout exit status is ignored by git — `|| true` on chained hooks is harmless.
- `git rev-parse --git-common-dir` returns `.git` (relative) from main clone, absolute path
  from a worktree — the `[[ "$COMMON" = /* ]] || COMMON="$TARGET/$COMMON"` fix is correct.
- In a worktree, `.git` is a FILE not a dir; `-d "$TARGET/.git"` correctly skips worktree
  targets in install.sh (they should point at the main clone).
