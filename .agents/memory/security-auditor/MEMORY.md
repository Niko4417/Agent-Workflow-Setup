# security-auditor memory

_Append dated, high-signal bullets only (<25 KB)._

## Agent-Workflow-Setup shell harness (trust model)

- Dotfiles-style harness at `/Users/nikolaos.vasilopoulos/Documents/Projects/Agent-Workflow-Setup`, symlinked into Keiko via git-ignored ABSOLUTE symlinks recorded in target `.git/info/exclude` (not committed `.gitignore`).
- Harness scripts are user-owned, 0755, NOT world/group-writable, git-tracked → "git hook runs script from absolute path" is acceptable code-exec surface; compromise needs already owning user files.
- Installed git hooks live in target COMMON `.git/hooks` (shared across worktrees). `core.hooksPath`, if set, diverts hooks — install.sh detects + only warns.
- Audit tip: reproduce in /tmp `git init` repos; `git worktree add` fires post-checkout with `$3=1`. For heredoc hooks, read the GENERATED file at `<target>/.git/hooks/`, not just the heredoc source, to see write-time vs run-time expansion. `git config --get <unset>` exits 1; `git rev-parse --git-common-dir` is RELATIVE (".git") from a main clone.

## 2026-06-15 — Worktree harness propagation (commit f12de9c) — PASS WITH FINDINGS

- Audited `scripts/link-worktree.sh` (new), `scripts/install.sh` worktree block, generated post-checkout hook. No critical/high/medium.
- Verified safe end-to-end: heredoc expansion timing correct; no shell injection (tested `; touch PWNED` + spaces in path); real (non-symlink) files never clobbered; failure-isolated (no `set -e` in relinker, `|| true` + `exit 0` in hook, missing relinker path does not fail `git worktree add`); chaining to `post-checkout.pre-keiko` runs original hook w/ correct args + idempotent via marker; `grep -qxF` correctly whole-line-anchored (plain `-qF` would substring-false-dedup `/.codex` vs `/.codex.bak`); `set -euo pipefail` safe (grep non-zero only inside if/!/||).
- Residual: LOW TOCTOU in link() check→ln window (local-only); LOW `core.hooksPath` set → no hook installed, silent; INFO subdir-arg links at toplevel (rev-parse climbs up); INFO always-on checkout exec vector (safe per trust model above).
