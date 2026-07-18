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
  commit; user-facing changes can't ship without a real UI-journey run (Playwright on
  web, a native desktop harness on Native); nothing reaches `dev` without a human.

This repository governs the development workflow; it is not the Keiko product or
the product's Agentic Coding runtime. The target repository owns its product
context, architecture decisions, contribution contract, templates, quality gates,
and runtime domain model. It supports **two products** through lightweight
**profiles** (see below) — the original **Keiko** (web) and the greenfield
**Keiko Native** (desktop) — without copying either one's rules into this repo.
See [Target repository boundary](docs/target-repository-boundary.md).

---

## Two products, one workflow — profiles

The same skills, roles, and gates drive **two products**:

- **Keiko** — the original **browser / web** app.
- **Keiko Native** — the greenfield, local-first **desktop** app.

They follow different rules: how an issue becomes "ready", how you verify it, what
counts as UI evidence, how branches merge. Rather than fork the whole workflow, each
product has a thin **profile** — a short file that _points_ the shared skills and
gates at that product's own rules. The actual policy lives in each product's repo;
the profile never copies it.

**You don't choose the profile — it's auto-detected** from the checkout you're in,
and each skill prints which one it picked on its first line. A Keiko-Native session
never loads Keiko-Web's rules, and vice versa, so nothing bleeds across.

|                        | **keiko-web** (browser)                | **keiko-native** (desktop)                                                                |
| ---------------------- | -------------------------------------- | ----------------------------------------------------------------------------------------- |
| Detected by            | `docs/design-system/` present          | `CONTEXT.md` + `docs/planning/decision-addendum.md` + `quality/project.json`              |
| "Ready to build" (DoR) | acceptance criteria + a verify command | machine-validated contract — `status: ready` granted by the repo's own readiness workflow |
| Verify command         | `npm run verify` (CI mirror)           | `npm run quality` + `npm audit` (Node 24.18.x)                                            |
| UI evidence            | Design-System fidelity + a11y proofs   | **Acceptance Journey** (native desktop harness, not browser Playwright)                   |
| Platforms              | web                                    | Windows + macOS (Linux deferred)                                                          |
| Merge into `dev`       | human-only                             | human-only                                                                                |
| Private source         | —                                      | **never touched** — planners restate from the repo-owned planning baseline                |

Default is **keiko-web**; **keiko-native** is chosen only when _all_ its markers are
present, so Native behavior is never an accidental default. The installer, the
verify command, the skills' first step, and the gates all read the active profile.
Full detail: **[`profiles/README.md`](profiles/README.md)** ·
per-product pointers: [`profiles/keiko-web.md`](profiles/keiko-web.md) ·
[`profiles/keiko-native.md`](profiles/keiko-native.md).

---

## Install

```bash
git clone git@github.com:Niko4417/Agent-Workflow-Setup.git
cd Agent-Workflow-Setup
./scripts/install.sh /path/to/Keiko          # web app
./scripts/install.sh /path/to/Keiko-Native   # desktop app — auto-detected, installs in augment mode
```

The installer symlinks the harness into the target (**live** — edit here, active
immediately) and keeps the target git-clean:

- `<target>/.codex`, `.claude`, `.agents`, `.mcp.json`, `.keiko-scripts` → this repo
- **keiko-web:** `AGENTS.md` and `CLAUDE.md` are also symlinked in (overlay).
  **keiko-native:** they are **left alone** — Native owns its machine-checked
  `AGENTS.md`/`CLAUDE.md`, so the installer **augments** and never overlays them.
- skills mirrored into `~/.codex/skills/` so Codex and Claude invoke them by the same name
- `.claude/settings.local.json` (per-machine) is preserved
- a `post-checkout` hook re-links the harness on every `git worktree add` (a fresh
  worktree doesn't inherit the symlinks — without this an agent in a worktree loses
  the skills, memory, and the gates; see `scripts/link-worktree.sh`)

The installer prints the detected `profile:` line and adapts automatically — no
flags to set. (Override with `KEIKO_PROFILE=keiko-native ./scripts/install.sh …`
if you ever need to force it.)

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

| Stage       | Skill                   | What it does                                                                                                                                                                 |
| ----------- | ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Plan**    | `keiko-grill-epic`      | Turn a rough idea into an implementation-ready epic + scoped child issues via one evidence-first grilling (on Native, contract/schema-driven against the machine validator). |
| **Deliver** | `keiko-epic <N>`        | Drive a multi-issue epic: plan children, run each on the epic branch, hand off one green epic PR to `dev`.                                                                   |
|             | `keiko-issue <N>`       | Drive one issue / task / bug / finding end-to-end to a PR.                                                                                                                   |
| **Verify**  | `keiko-issue-audit <N>` | Read-first audit wave that fixes confirmed gaps and writes a SHA-bound audit receipt. Mandatory pre-PR.                                                                      |
| **Learn**   | `keiko-retro <epic>`    | Post-merge retrospective: mine the full PR trail + the human-fix delta, distill process lessons, tidy memory.                                                                |

`keiko-epic` composes `keiko-issue` per child; every issue ends with `keiko-issue-audit`.

---

## The gate chain — why you can trust the output

Six **PreToolUse gates** fire on the agent's own `gh` / `git` commands. They don't
run the tests themselves — they **block the action until proof exists** (SHA-bound
receipts, a real UI-journey run, a `gh`-checked comment). An agent literally cannot
open, ready, merge, or repush around them. Each gate reads the **active profile**, so
"verify" and "UI-journey" mean the right thing per product (see the profile table above).

| Moment                     | Gate              | Blocks unless…                                                                                                           |
| -------------------------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------ |
| open / ready a PR          | `verify-gate`     | the profile's verify command (`verify.sh` on web · `npm run quality` on Native) passed **green** at HEAD                 |
| open / ready a PR          | `audit-gate`      | the audit **ran and is clean** — `findings=0`, plus a green **ui-verify** receipt (real UI-journey run) when user-facing |
| ready a user-facing PR     | `ready-gate`      | a **SHA-bound test-plan comment** for the current commit is posted                                                       |
| repush a fix to a `dev` PR | `push-gate`       | the fix re-passes verify + clean-audit (+ ui-verify + reposted plan)                                                     |
| auto-merge into an epic    | `epic-merge-gate` | exact-head GitHub `ci` + matching clean audit/verify + (UI) journey/comment; **never** into `dev`/`main`/`release`       |

**`dev` is sacred:** the only agent auto-merge is a child into its canonical
`epic/*` branch after every applicable gate passes. Everything into `dev` —
standalone issue or accumulated epic — needs a
**human reviewer + green GitHub CI**. Local gates are fast feedback; the target's
protected `dev` is the authoritative backstop.

---

## How it works

- **One orchestrator.** The lead session is the only agent the human talks to — it
  plans, delegates, integrates, reports. It never spawns a sub-coordinator.
- **15 canonical roles** (plus the non-spawnable coordinator). Work routes to roles in `.agents/roles.yaml` at the
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

| Agent                  | Routed for (task signal)                                   | Codex model     | Reasoning | Claude        | Access       |
| ---------------------- | ---------------------------------------------------------- | --------------- | --------- | ------------- | ------------ |
| `architect`            | ADR / module boundary / dependency-direction decision      | `gpt-5.6-sol`   | high      | opus          | docs/adr     |
| `developer`            | spec-first feature: research → plan → TDD build (heavy)    | `gpt-5.6-sol`   | high      | opus          | full write   |
| `security-auditor`     | deep audit — crypto/auth, data-flow, PR-scoped review      | `gpt-5.6-sol`   | xhigh     | opus          | read-only    |
| `implementor`          | scoped minimal-diff task with a clear definition of done   | `gpt-5.6-terra` | medium    | sonnet        | full write   |
| `test-engineer`        | test coverage, regression harnesses, mutation-robust tests | `gpt-5.6-terra` | high      | sonnet        | test files   |
| `ui-engineer`          | Figma → component, design-system conformance, UI fixes     | `gpt-5.6-terra` | high      | sonnet        | full write   |
| `refactor-specialist`  | behavior-preserving cleanup, complexity > 10               | `gpt-5.6-terra` | high      | sonnet        | full write   |
| `pr-reviewer`          | multi-dimension PR review before merge                     | `gpt-5.6-terra` | high      | sonnet        | read-only    |
| `verifier`             | acceptance-criteria verification + PR evidence capture     | `gpt-5.6-terra` | high      | sonnet        | read-only    |
| `performance-engineer` | LCP / INP / CLS, bundle, N+1, hot paths                    | `gpt-5.6-terra` | high      | sonnet        | read-only    |
| `a11y-auditor`         | WCAG 2.2 AA review                                         | `gpt-5.6-terra` | high      | haiku         | read-only    |
| `explorer`             | code mapping + external doc/API grounding (Context7/web)   | `gpt-5.6-luna`  | medium    | haiku         | read-only    |
| `docs`                 | README / API / ADR / CHANGELOG / migration notes           | `gpt-5.6-luna`  | medium    | haiku         | docs         |
| `security-triage`      | fast first-pass scan (OWASP grep, secrets, authz)          | `gpt-5.6-luna`  | medium    | sonnet        | read-only    |
| `browser-debugger`     | real-browser reproduction + evidence capture               | `gpt-5.6-luna`  | medium    | _capability_¹ | reproduction |
| `pr-shepherd`          | drive an open PR to merge-ready (delegates fixes)          | `gpt-5.6-luna`  | medium    | sonnet        | drive        |

The **orchestrator** (the lead chat you invoke a skill from) is not a spawnable role —
run it on **Sol**, `high` for executing an epic, `xhigh` when authoring one.

¹ `browser-debugger` is a **Codex** agent (`codex/agents/browser-debugger.toml`). On
Claude there is no separate agent — real-browser reproduction is a **capability** the
lead drives directly (Playwright / Chrome MCP), per the `CLAUDE.md` routing table.

---

## Tooling

```bash
bash /path/to/Agent-Workflow-Setup/scripts/verify.sh                          # local CI mirror, from Keiko root
KEIKO_ROOT=/path/to/Keiko /path/to/Agent-Workflow-Setup/scripts/keiko-watch   # live per-agent activity feed
/path/to/Agent-Workflow-Setup/scripts/consolidate-memory                      # memory budget check (<25 KB/role)
cd "$(scripts/edit-worktree.sh feat/my-change)"                               # edit this repo in an isolated worktree
```

**Editing this repo:** targets read it through live symlinks, so the primary checkout
must stay on merged `main`. Edit in a worktree (`edit-worktree.sh`); the primary
self-updates on SessionStart (`self-update.sh`). See
[docs/local-editing.md](docs/local-editing.md).

The gate scripts (`verify-gate`, `audit-gate`, `ready-gate`, `push-gate`,
`epic-merge-gate`) and receipt writers (`verify-receipt`, `audit-receipt`,
`ui-verify-receipt`) run automatically via the harness hooks — you rarely call them
by hand. Each has a test in `tests/`.

---

## What's inside

```
profiles/    README.md (selection) · keiko-web.md · keiko-native.md   (per-product pointers)
docs/        workflow-contract.md (rules) · workflow-blueprint.md (design) · example-workflow.md · target-repository-boundary.md
.agents/     roles.yaml · aliases.yaml · memory/<role>/            (tool-neutral shared layer)
codex/       config.toml · RUNBOOK.md · agents/*.toml · hooks.json · playbooks/    (primary)
claude/      settings.json · agents/*.md · skills/<name>/SKILL.md                  (backup)
scripts/     install.sh · profile-detect.sh · verify.sh · *-gate.sh · *-receipt.sh · keiko-watch · consolidate-memory
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
