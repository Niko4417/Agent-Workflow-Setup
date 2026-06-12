# Agent Workflow Setup

A portable, shareable agent-driven development workflow for the **Keiko**
codebase — primary harness **Codex**, backup harness **Claude Code**.

Clone this repo and symlink it into any Keiko checkout. Nothing is committed into
the Keiko repo itself (its `.claude/` / `.codex/` are git-ignored by design); the
setup travels here, learnings travel here, the target stays clean.

---

## What's inside

```
.
├─ docs/
│  ├─ workflow-contract.md     # tool-neutral governance contract (the rules)
│  └─ workflow-blueprint.md    # full design spec: every decision + tradeoff
├─ .agents/                    # tool-neutral shared layer (symlinked to <target>/.agents)
│  ├─ roles.yaml               # 16 canonical roles (source of truth)
│  ├─ aliases.yaml             # harness name -> canonical role
│  └─ memory/<role>/MEMORY.md  # shared curated memory, keyed by canonical role
├─ codex/                      # PRIMARY harness (symlinked to <target>/.codex)
│  ├─ config.toml · RUNBOOK.md · agents/*.toml · playbooks/ · hooks/
├─ claude/                     # BACKUP harness (symlinked to <target>/.claude)
│  ├─ settings.json · agents/*.md · teams/ · CLAUDE.md/AGENTS.md pointers
├─ scripts/install.sh          # symlink installer
└─ templates/                  # verify / husky / PR-template snippets (target-side)
```

## Install

```bash
git clone git@github.com:<you>/Agent-Workflow-Setup.git
cd Agent-Workflow-Setup
./scripts/install.sh /path/to/Keiko       # or: KEIKO_ROOT=/path/to/Keiko ./scripts/install.sh
```

This symlinks `<target>/.codex`, `<target>/.claude`, `<target>/.agents` to this
repo (live iteration — edit here, active immediately). An existing
`.claude/settings.local.json` is preserved as a per-machine, git-ignored file.

Confirm the target's `.gitignore` lists `/.codex/`, `/.claude/`, `/.agents/`.

## The model in one paragraph

The lead session is the sole **orchestrator** the human talks to. It routes work
to **16 canonical roles** (`.agents/roles.yaml`) at the smallest effective shape
— solo for small work, a cluster for multi-module/epic work. Every issue gets a
PR; **`dev` is sacred** (human + green CI on every merge into it; the only
auto-merge is `issue -> epic-branch`). A tiered quality gate (lint-staged →
self-critique → `npm run verify` → completion judge → CI) keeps CI green before
the PR exists. Status lives on the GitHub delivery board; learnings live in
`.agents/memory/`. Full detail: [`docs/workflow-contract.md`](docs/workflow-contract.md).

## Status — what's done vs. next

**Done:**

- Codex + Claude harness ported, **path-portable** (no machine-specific paths;
  `origin/main` → `dev` fixed).
- 16-role canonical vocabulary + alias map + shared memory tree.
- Governance contract + full design blueprint.
- Symlink installer (also links root entry docs + retires old `project.md`).
- **Agents consolidated** onto the 16 canonical roles; all routing + memory
  references repointed to the shared `.agents/memory/` tree.
- **Completion judge** upgraded to Sonnet + loop cap; **measurable quality bars +
  2-pass self-critique** ported to Codex (`RUNBOOK.md`).
- **MCP parity for Claude** (Context7 + Playwright via `.mcp.json`).
- **`scripts/verify.sh`** — local CI mirror (no `package.json` change needed).
- **`scripts/keiko-watch`** — live per-agent activity feed for both harnesses.
- **Definition-of-Ready gate + status heartbeat** in both harness docs.
- **Sacred-`dev` policy** corrected in the RUNBOOK (was: ordinary issues land
  directly on `dev`).
- **Automated PR evidence capture** wired into both verifier agents.
- **`coordinator.toml` removed** (lead is the sole orchestrator); lead memory dir
  added.
- **`scripts/consolidate-memory`** — memory budget checker.
- Codex desktop notifications already covered by the global `~/.codex` `notify`.

**Next (all require the Keiko maintainer / admin):**

- Apply target-side gates (husky/lint-staged + PR-template evidence) — see
  [`templates/`](templates/).
- Branch protection on `dev` (admin-only).

**Optional polish:**

- Explicit counter-based loop cap for the judge (current cap uses
  `stop_hook_active`).

## Tooling

```bash
# before opening a PR (run from the Keiko root):
bash /path/to/Agent-Workflow-Setup/scripts/verify.sh

# watch agents work in real time (side terminal):
KEIKO_ROOT=/path/to/Keiko /path/to/Agent-Workflow-Setup/scripts/keiko-watch
```

## Server-side prerequisites (repo admin only)

The "full local agent access" posture is safe **because `dev` is protected**.
That requires **admin** on the target repo — configure on `oscharko-dev/Keiko`:

- `dev`: require PR, require green `ci` check, require human review for epic
  merges.

Until that exists, the server-side backstop is absent; treat agent merges into
`dev` with extra care.

## Sharing

This repo is self-contained and path-free, so a collaborator can clone it and run
`install.sh` against their own Keiko checkout. Per-machine bits
(`settings.local.json`) stay local and git-ignored.
