# Agent Workflow Setup

A portable, multi-agent development workflow for the **Keiko** codebase — primary
harness **Codex**, backup harness **Claude Code**. Clone it, symlink it into a
Keiko checkout, and drive epics and issues through one consistent, gated process.

Nothing is committed into the Keiko repo — its `.claude/`/`.codex/` are
git-ignored by design. The setup, the agent roster, and accumulated learnings all
live here; the target stays clean.

## Install

```bash
git clone git@github.com:Niko4417/Agent-Workflow-Setup.git
cd Agent-Workflow-Setup
./scripts/install.sh /path/to/Keiko        # or: KEIKO_ROOT=/path/to/Keiko ./scripts/install.sh
```

The installer symlinks the harness into the target (live — edit here, active
immediately) and keeps the target git-clean:

- `<target>/.codex`, `.claude`, `.agents` → this repo
- `<target>/.mcp.json`, `AGENTS.md`, `CLAUDE.md` → this repo; old `project.md` retired
- project skills mirrored into `~/.codex/skills/` so Codex and Claude share them
- an existing `.claude/settings.local.json` is preserved (per-machine, git-ignored)

## Quick start

Tell the orchestrator what to work on; it invokes the matching skill.

```text
Act as the orchestrator for Keiko and run epic #532.
Act as the orchestrator for Keiko and resolve issue #178.
```

See **[docs/example-workflow.md](docs/example-workflow.md)** for full example
prompts and a step-by-step walkthrough of what happens.

## Skills & tooling

| Command                      | What it does                                                                                              |
| ---------------------------- | --------------------------------------------------------------------------------------------------------- |
| `keiko-epic <N>`             | Drive a multi-issue epic: plan children, run each on an epic branch, hand off one green epic PR to `dev`. |
| `keiko-issue <N>`            | Drive one issue/task/bug/finding end-to-end to a PR.                                                      |
| `keiko-issue-audit <N>`      | Mandatory pre-PR-ready audit wave (also on-demand). Writes a SHA-bound audit receipt.                     |
| `scripts/verify.sh`          | Local CI mirror — run from the Keiko root before a PR.                                                    |
| `scripts/audit-gate.sh`      | Proof-of-audit check — blocks `gh pr create` unless `keiko-issue-audit` ran against the current HEAD.     |
| `scripts/keiko-watch`        | Live per-agent activity feed (side terminal).                                                             |
| `scripts/consolidate-memory` | Memory budget checker (<25 KB/role).                                                                      |

```bash
bash /path/to/Agent-Workflow-Setup/scripts/verify.sh                 # from Keiko root, pre-PR
KEIKO_ROOT=/path/to/Keiko /path/to/Agent-Workflow-Setup/scripts/keiko-watch
```

## How it works

- **One orchestrator.** The lead session is the only agent the human talks to; it
  plans, delegates, and reports. It never spawns a sub-coordinator.
- **16 canonical roles.** Work routes to roles in `.agents/roles.yaml` at the
  smallest effective shape — solo for small work, a cluster for multi-module/epic
  work. Both harnesses share one role vocabulary and one memory tree.
- **`dev` is sacred.** Every issue ships as a PR. The only auto-merge is
  `issue → epic-branch` on green CI; every merge into `dev` needs a human + green CI.
- **Layered quality gates.** lint-staged → 2-pass self-critique → `verify.sh` →
  `keiko-issue-audit` → completion judge → CI on protected `dev`.
- **Status in GitHub, learnings in memory.** The delivery board is the durable
  source of truth; `.agents/memory/<role>/` holds curated, committed learnings.

Rules: [docs/workflow-contract.md](docs/workflow-contract.md) ·
Design + tradeoffs: [docs/workflow-blueprint.md](docs/workflow-blueprint.md)

## What's inside

```
docs/        workflow-contract.md (rules) · workflow-blueprint.md (design) · example-workflow.md
.agents/     roles.yaml · aliases.yaml · memory/<role>/   (tool-neutral shared layer)
codex/       config.toml · RUNBOOK.md · agents/*.toml · playbooks/ · hooks/   (primary)
claude/      settings.json · agents/*.md · teams/ · skills/<name>/SKILL.md     (backup)
scripts/     install.sh · verify.sh · keiko-watch · consolidate-memory
templates/   target-side gate snippets (husky / lint-staged / PR evidence)
```

## Server-side prerequisite (repo admin)

The full-local-access posture is safe **because `dev` is protected** — and that
requires `admin` on the target repo. On `oscharko-dev/Keiko`, protect `dev`:
require a PR, the green `ci` check, and human review. Until then the server-side
backstop is absent; treat agent merges toward `dev` with extra care.

## Sharing

The repo is path-free and self-contained: a collaborator clones it and runs
`install.sh` against their own Keiko checkout. Per-machine bits stay local and
git-ignored.
