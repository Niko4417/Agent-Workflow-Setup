# Editing this repo without disturbing live sessions

Installed target repos (Keiko, Keiko Native) reach this repo through **live symlinks**
(`.claude`, `.codex`, `.agents`, and `.keiko-scripts`). Target-owned `AGENTS.md` and
`CLAUDE.md` are preserved. The harness symlinks resolve to whatever the **primary checkout** currently has
on disk. So if you check out a feature branch in the primary checkout, every live
session immediately reads your **work-in-progress** skills and gates.

The two rules below apply to a live web integration. Native uses a separate
immutable checkout; see [pinning](#pinning-an-optional-native-integration).

Two rules keep live sessions on merged `main`:

## 1. Never edit in the primary checkout — use a worktree

Keep the primary checkout permanently on a clean `main`. Do all editing in an isolated
git worktree:

```bash
cd "$(scripts/edit-worktree.sh feat/my-change)"   # worktree off origin/main
# ...edit, commit, push, open the PR from here...
```

Worktrees live under `${AWS_WORKTREES:-<repo-parent>/.aws-worktrees}`. The primary
checkout never leaves `main`, so live sessions never see unmerged work. Remove a
worktree when done: `git worktree remove <path>`.

## 2. The primary checkout self-updates

[`scripts/self-update.sh`](../scripts/self-update.sh) is wired into **SessionStart**
(Claude and Codex). On each session start it fast-forwards the primary checkout's
`main` — but **only when it is a clean `main`**, so a worktree edit is never disturbed
and a dirty tree is never clobbered; any failure (offline, no remote) is swallowed.

So after a PR merges, the next session in any target picks up the change automatically.
To force it now: `git -C <primary-checkout> pull --ff-only origin main`.

## Why

The symlink model gives instant propagation (edit here, live everywhere) — the trade-off
is that "here" must always be merged `main`, never a WIP branch. The worktree flow plus
session-start self-update makes "live = merged `main`" hold automatically.

## Pinning an optional Native integration

Native requires an immutable workflow reference. Install from a separate clean
checkout at the reviewed commit (`git checkout --detach <reviewed-commit>`), record
that SHA in the integration reference, and leave it detached. `self-update.sh`
updates only clean `main`, so this checkout does not auto-update. Review and move
the pin explicitly when adopting a newer release. The installer does not enforce
this pin and should not be pointed at a mutable development checkout for Native.
