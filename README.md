# Agent Workflow Setup

**Turn a Keiko checkout into a governed, multi-agent delivery line.** Clone this
repo, symlink it into Keiko, and drive epics and issues from a rough idea all the
way to a green, human-reviewed PR — through one consistent process that **enforces
quality with local gates instead of trusting an agent to remember.**

- **Two harnesses, one brain.** Primary **Codex**, backup **Claude Code** — same
  roles, same skills, same memory, same gates.
- **Nothing leaks into Keiko.** The target's `.claude/` / `.codex/` are git-ignored;
  the setup, the agent roster, and accumulated learnings all live _here_. The target
  stays clean.
- **Hard gates, not vibes.** A PR can't even open with a red build or an unaudited
  commit; user-facing changes can't ship without a real Playwright run; nothing
  reaches `dev` without a human.

---

## Install

```bash
git clone git@github.com:Niko4417/Agent-Workflow-Setup.git
cd Agent-Workflow-Setup
./scripts/install.sh /path/to/Keiko        # or: KEIKO_ROOT=/path/to/Keiko ./scripts/install.sh
```

The installer symlinks the harness into the target (**live** — edit here, active
immediately) and keeps the target git-clean:

- `<target>/.codex`, `.claude`, `.agents`, `.mcp.json`, `AGENTS.md`, `CLAUDE.md` → this repo
- skills mirrored into `~/.codex/skills/` so Codex and Claude invoke them by the same name
- `.claude/settings.local.json` (per-machine) is preserved
- a `post-checkout` hook re-links the harness on every `git worktree add` (a fresh
  worktree doesn't inherit the symlinks — without this an agent in a worktree loses
  CLAUDE.md, skills, memory, and the gates; see `scripts/link-worktree.sh`)

---

## Quick start

Tell the orchestrator what to work on — it picks the matching skill and drives it.

```text
Act as the orchestrator for Keiko and run epic #532.
Act as the orchestrator for Keiko and resolve issue #178.
```

Full walkthrough: **[docs/example-workflow.md](docs/example-workflow.md)**.

---

## The delivery lifecycle (5 skills)

Work flows through four stages — plan → deliver → verify → learn:

| Stage       | Skill                   | What it does                                                                                                  |
| ----------- | ----------------------- | ------------------------------------------------------------------------------------------------------------- |
| **Plan**    | `keiko-grill-epic`      | Turn a rough idea into an implementation-ready epic + scoped child issues via one evidence-first grilling.    |
| **Deliver** | `keiko-epic <N>`        | Drive a multi-issue epic: plan children, run each on the epic branch, hand off one green epic PR to `dev`.    |
|             | `keiko-issue <N>`       | Drive one issue / task / bug / finding end-to-end to a PR.                                                    |
| **Verify**  | `keiko-issue-audit <N>` | Read-first audit wave that fixes confirmed gaps and writes a SHA-bound audit receipt. Mandatory pre-PR.       |
| **Learn**   | `keiko-retro <epic>`    | Post-merge retrospective: mine the full PR trail + the human-fix delta, distill process lessons, tidy memory. |

`keiko-epic` composes `keiko-issue` per child; every issue ends with `keiko-issue-audit`.

---

## The gate chain — why you can trust the output

Six **PreToolUse gates** fire on the agent's own `gh` / `git` commands. They don't
run the tests themselves — they **block the action until proof exists** (SHA-bound
receipts, a real Playwright run, a `gh`-checked comment). An agent literally cannot
open, ready, merge, or repush around them.

| Moment                     | Gate              | Blocks unless…                                                                                                           |
| -------------------------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------ |
| open / ready a PR          | `verify-gate`     | `verify.sh` (CI mirror) passed **green** at HEAD                                                                         |
| open / ready a PR          | `audit-gate`      | the audit **ran and is clean** — `findings=0`, plus a green **ui-verify** receipt (real Playwright run) when user-facing |
| ready a user-facing PR     | `ready-gate`      | a **SHA-bound test-plan comment** for the current commit is posted                                                       |
| repush a fix to a `dev` PR | `push-gate`       | the fix re-passes verify + clean-audit (+ ui-verify + reposted plan)                                                     |
| auto-merge into an epic    | `epic-merge-gate` | exact-head GitHub `ci` + matching clean audit/verify + (UI) Playwright/comment; **never** into `dev`/`main`/`release`   |

**`dev` is sacred:** the only agent auto-merge is a child into its canonical
`epic/*` branch after every applicable gate passes. Everything into `dev` —
standalone issue or accumulated epic — needs a
**human reviewer + green GitHub CI**. Local gates are fast feedback; the target's
protected `dev` is the authoritative backstop.

---

## How it works

- **One orchestrator.** The lead session is the only agent the human talks to — it
  plans, delegates, integrates, reports. It never spawns a sub-coordinator.
- **16 canonical roles.** Work routes to roles in `.agents/roles.yaml` at the
  smallest effective shape: solo for a one-file fix, a cluster (explorer → writer →
  verifier) for epic / security / UI work. Both harnesses share one role vocabulary.
- **Resumable by design.** State lives on the GitHub delivery board, not in a chat —
  so a run that hits a token limit picks up exactly where it left off on the next
  invocation.
- **Status in GitHub, learnings in memory.** The board is the durable source of
  truth; `.agents/memory/<role>/` holds curated learnings, kept lean by
  `consolidate-memory` and the `keiko-retro` lint pass.

Rules: **[docs/workflow-contract.md](docs/workflow-contract.md)** ·
Design + tradeoffs: **[docs/workflow-blueprint.md](docs/workflow-blueprint.md)**

---

## Agent roster & routing

Each role is tiered onto the GPT-5.6 model family (Codex, primary harness) with a
mirror on Claude (backup). **Reasoning** is the _standing_ effort — the orchestrator
escalates a single task to `xhigh`/`max` when it's genuinely hard, then drops back.
Model + effort live in `.codex/agents/*.toml`; the canonical map is
[`.agents/roles.yaml`](.agents/roles.yaml).

Tiers: **Sol** = frontier (ambiguous planning, high-risk review) · **Terra** =
everyday build/test/review (the ex-`gpt-5.4` successor) · **Luna** = light recon,
mechanical, docs.

| Agent                  | Routed for (task signal)                                   | Codex model     | Reasoning | Claude | Access       |
| ---------------------- | ---------------------------------------------------------- | --------------- | --------- | ------ | ------------ |
| `architect`            | ADR / module boundary / dependency-direction decision      | `gpt-5.6-sol`   | high      | opus   | docs/adr     |
| `developer`            | spec-first feature: research → plan → TDD build (heavy)    | `gpt-5.6-sol`   | high      | opus   | full write   |
| `security-auditor`     | deep audit — crypto/auth, data-flow, PR-scoped review      | `gpt-5.6-sol`   | xhigh     | opus   | read-only    |
| `implementor`          | scoped minimal-diff task with a clear definition of done   | `gpt-5.6-terra` | medium    | sonnet | full write   |
| `test-engineer`        | test coverage, regression harnesses, mutation-robust tests | `gpt-5.6-terra` | high      | sonnet | test files   |
| `ui-engineer`          | Figma → component, design-system conformance, UI fixes     | `gpt-5.6-terra` | high      | sonnet | full write   |
| `refactor-specialist`  | behavior-preserving cleanup, complexity > 10               | `gpt-5.6-terra` | high      | sonnet | full write   |
| `pr-reviewer`          | multi-dimension PR review before merge                     | `gpt-5.6-terra` | high      | sonnet | read-only    |
| `verifier`             | acceptance-criteria verification + PR evidence capture     | `gpt-5.6-terra` | high      | sonnet | read-only    |
| `performance-engineer` | LCP / INP / CLS, bundle, N+1, hot paths                    | `gpt-5.6-terra` | high      | sonnet | read-only    |
| `a11y-auditor`         | WCAG 2.2 AA review                                         | `gpt-5.6-terra` | high      | haiku  | read-only    |
| `explorer`             | code mapping + external doc/API grounding (Context7/web)   | `gpt-5.6-luna`  | medium    | haiku  | read-only    |
| `docs`                 | README / API / ADR / CHANGELOG / migration notes           | `gpt-5.6-luna`  | medium    | haiku  | docs         |
| `security-triage`      | fast first-pass scan (OWASP grep, secrets, authz)          | `gpt-5.6-luna`  | medium    | sonnet | read-only    |
| `browser-debugger`     | real-browser reproduction + evidence capture               | `gpt-5.6-luna`  | medium    | sonnet | reproduction |
| `pr-shepherd`          | drive an open PR to merge-ready (delegates fixes)          | `gpt-5.6-luna`  | medium    | sonnet | drive        |

The **orchestrator** (the lead chat you invoke a skill from) is not a spawnable role —
run it on **Sol**, `high` for executing an epic, `xhigh` when authoring one.

---

## Tooling

```bash
bash /path/to/Agent-Workflow-Setup/scripts/verify.sh                          # local CI mirror, from Keiko root
KEIKO_ROOT=/path/to/Keiko /path/to/Agent-Workflow-Setup/scripts/keiko-watch   # live per-agent activity feed
/path/to/Agent-Workflow-Setup/scripts/consolidate-memory                      # memory budget check (<25 KB/role)
```

The gate scripts (`verify-gate`, `audit-gate`, `ready-gate`, `push-gate`,
`epic-merge-gate`) and receipt writers (`verify-receipt`, `audit-receipt`,
`ui-verify-receipt`) run automatically via the harness hooks — you rarely call them
by hand. Each has a test in `tests/`.

---

## What's inside

```
docs/        workflow-contract.md (rules) · workflow-blueprint.md (design) · example-workflow.md
.agents/     roles.yaml · aliases.yaml · memory/<role>/            (tool-neutral shared layer)
codex/       config.toml · RUNBOOK.md · agents/*.toml · hooks.json · playbooks/    (primary)
claude/      settings.json · agents/*.md · skills/<name>/SKILL.md                  (backup)
scripts/     install.sh · verify.sh · *-gate.sh · *-receipt.sh · keiko-watch · consolidate-memory
tests/       gate + hook test suites
templates/   target-side gate snippets (husky / lint-staged / PR evidence)
```

---

## Server-side prerequisite (repo admin)

The full-local-access posture is safe **because `dev` is protected** — which needs
`admin` on the target repo. On `oscharko-dev/Keiko`, protect `dev`: require a PR, the
green `ci` check, and human review. Until then the local gates are fast feedback but
the _authoritative_ backstop is absent — treat agent merges toward `dev` with care.
The airtight form of proof-of-audit lives here too: emit PR-visible evidence and make
it a **required status check** on `dev`.

## Sharing

Path-free and self-contained: a collaborator clones it and runs `install.sh` against
their own Keiko checkout. Per-machine bits stay local and git-ignored.
