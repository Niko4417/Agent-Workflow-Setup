# Agent Workflow Setup

Reusable delivery workflows for Codex and Claude Code: plan accepted work, delegate
bounded tasks, verify exact-head evidence, and deliver a PR under target authority
and explicit run review choices.
Local hooks provide early checks; the target's protected branches and required
checks remain the authoritative merge controls.

After installation, select work with `Run epic #532` or `Resolve issue #178`.

### Why it exists

- **Trust, not vibes.** Agents are fast but forgetful. Instead of _hoping_ an agent ran
  the tests, the configured command hooks require SHA-bound verify/audit evidence
  before opening work-branch PRs.
- **One process, either assistant.** Works the same whether you drive it with **Codex**
  or **Claude Code** — same roles, same steps, same memory.
- **Stays out of your project's way.** All the machinery lives _here_ and is linked in;
  your actual product code stays clean.
- **Two products, one workflow.** It runs both
  [**Keiko**](https://github.com/oscharko-dev/Keiko) (the web app) and
  [**Keiko Native**](https://github.com/oscharko-dev/Keiko-Native) (the desktop app),
  adapting automatically to whichever you're working in.

> **The products this drives:**
> [oscharko-dev/Keiko](https://github.com/oscharko-dev/Keiko) (web) ·
> [oscharko-dev/Keiko-Native](https://github.com/oscharko-dev/Keiko-Native) (desktop).
> This repo is the _how-we-work_ layer, **not** the product — each product owns its own
> rules, architecture, and quality bar; this setup just orchestrates them. See
> [Target repository boundary](docs/target-repository-boundary.md).

---

## Two products, one workflow — profiles

The same skills, roles, and gates drive **two products**:

- [**Keiko**](https://github.com/oscharko-dev/Keiko) — the original **browser / web** app.
- [**Keiko Native**](https://github.com/oscharko-dev/Keiko-Native) — the greenfield, local-first **desktop** app.

They follow different rules: how an issue becomes "ready", how you verify it, what
counts as UI evidence, how branches merge. Rather than fork the whole workflow, each
product has a thin **profile** — a short file that _points_ the shared skills and
gates at that product's own rules. The actual policy lives in each product's repo;
the profile never copies it.

**The profile is auto-detected** from the checkout, with an explicit operator override,
and each skill prints which one it picked on its first line. A Keiko-Native session
never loads Keiko-Web's rules, and vice versa, so nothing bleeds across.

|                        | **keiko-web** (browser)                | **keiko-native** (desktop)                                                                |
| ---------------------- | -------------------------------------- | ----------------------------------------------------------------------------------------- |
| Detected by            | `docs/design-system/` present          | `CONTEXT.md` + `docs/planning/decision-addendum.md` + `quality/project.json`              |
| "Ready to build" (DoR) | acceptance criteria + a verify command | machine-validated contract — `status: ready` granted by the repo's own readiness workflow |
| Verify command         | `verify.sh` → target-owned gate           | `verify.sh` → target-owned gate / Native fallback                                            |
| UI evidence            | Design-System fidelity + a11y proofs   | **Acceptance Journey** (native desktop harness, not browser Playwright)                   |
| Platforms              | web                                    | Windows + macOS (Linux deferred)                                                          |
| Merge into `dev`       | target authority + explicit run holds                             | human-only                                                                                |
| Private source         | —                                      | **never touched** — planners restate from the repo-owned planning baseline                |

Scripts default to **keiko-web**; skills ask when product context is ambiguous.
Automatic **keiko-native** selection requires _all_ its markers, so Native behavior is never an accidental default. The installer, the
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
# Native: run this from a separate checkout detached at the reviewed commit
./scripts/install.sh /path/to/Keiko-Native   # detected augment mode; root product docs preserved
```

The installer links an optional local harness and keeps generated integration files
out of target commits. Web can follow a live merged checkout; Native must use a
separate immutable checkout (see [pinning](docs/local-editing.md#pinning-an-optional-native-integration)):

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

## Skill maintenance and setup checks

The five skills adapt selected principles from [Matt Pocock's skills](https://github.com/mattpocock/skills),
reviewed on 2026-10-09: executed bug reproduction, public test seams with explicit
catches/misses, separate requirements/standards review, small independent decision
rounds, and deterministic retro guardrail proposals. These fit the existing Keiko
profiles and delivery gates; the upstream bundle is not installed wholesale.
See [maintenance notes](docs/setup-maintenance.md) for provenance and verification.

Shared `AGENTS.md` stays focused on durable working rules; `CLAUDE.md` adds harness
mechanics. Product `CONTEXT.md`, ADRs, templates, and acceptance policy remain
owned by the target. Skills and conditional references carry detailed procedures;
web-only UI checklists load only for web work. Both harnesses use the same local
memory store; read-only agents return candidates to the lead.

```bash
python3 -m venv work/lint-env
work/lint-env/bin/python -m pip install -r requirements-dev.txt
work/lint-env/bin/python scripts/check-setup.py
python3 scripts/check-routing.py
work/lint-env/bin/python tests/test-setup.py
python3 tests/test-lifecycle-logger.py
python3 tests/test-routing.py
for test in tests/*.sh; do bash "$test" || exit 1; done
```

These checks validate structure, syntax, metadata, local links, routing, and the
covered gate behavior. They do not replace named-role runtime smoke tests,
representative model-quality evaluation, or target platform acceptance runs.

---

## The safety net — why you can trust what it ships

Five local command gates check evidence before recognized PR/push/merge operations.
They check receipts and GitHub state; workflow steps run the actual tests and audits.
Hooks are scoped guardrails, not a security boundary: they cannot cover arbitrary
shell/API calls or replace server-side required checks.

| Moment                     | Gate              | Blocks unless…                                                                                                           |
| -------------------------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------ |
| open / ready a PR          | `verify-gate`     | the target's canonical command selected by `verify.sh` passed **green** at HEAD                 |
| open / ready a PR          | `audit-gate`      | the audit **ran and is clean** — `findings=0`, plus a green **ui-verify** receipt (real UI-journey run) when user-facing |
| ready a user-facing PR     | `ready-gate`      | a **SHA-bound test-plan comment** for the current commit is posted                                                       |
| repush a fix to any open work PR | `push-gate`       | the fix re-passes verify + clean-audit (+ ui-verify + reposted plan)                                                     |
| authorized auto-merge | `epic-merge-gate` | full current-head target matrix + settled reviews + matching clean audit/verify + applicable UI journey/comment; target merge authority |

**Target-owned delivery:** target `AGENTS.md`, ADRs, and explicit user choices
override generic defaults. Keiko ADR-0135 permits accepted issue and epic delivery
through native auto-merge after the full current-head required-check matrix is
green and reviews are settled. Preserve a requested final epic review hold
without child approvals; default to final human review where neither target nor
user authorizes another path. Local gates provide earlier feedback.

---

## How it works

- **One orchestrator.** The lead session is the only agent the human talks to — it
  plans, delegates, integrates, reports. It never spawns a sub-coordinator.
- **16 canonical roles** (16 Codex agents; 15 Claude agents plus browser capability), with the lead as the non-spawnable coordinator. Work routes to roles in `.agents/roles.yaml` at the
  smallest effective shape: solo for a one-file fix, a cluster (explorer → writer →
  verifier) for epic / security / UI work. Both harnesses share one role vocabulary.
- **Resumable by design.** State lives on the GitHub delivery board, not in a chat —
  so a run that hits a token limit picks up exactly where it left off on the next
  invocation.
- **Status in GitHub, learnings in memory.** The board is the durable source of
  truth; `.agents/memory/<role>/` holds curated learnings, kept lean by
  `consolidate-memory` and the `keiko-retro` lint pass.

Rules: **[docs/workflow-contract.md](docs/workflow-contract.md)** ·
Historical design + tradeoffs: **[docs/workflow-blueprint.md](docs/workflow-blueprint.md)**

---

## Agent roster & routing

The standing model and effort settings are reviewed as of **2026-10-09**.
`.agents/roles.yaml` is the canonical routing policy; the Codex and Claude role
definitions implement it. Run `python scripts/check-routing.py` to detect drift.
The lead defaults to **GPT-6.1 Sol / high** or **Claude Opus 5.5 / high**.

Use GPT-6 Luna / Claude Haiku 5.5 for bounded lookup and straightforward docs;
GPT-6.1 Sol / Claude Opus 5.5 for scoped execution; and stronger settings for
complex features, architecture, or review. Codex escalation stays on **Sol 6.1**:
Luna → Sol 6.1 / medium → Sol 6.1 / high → Sol 6.1 / xhigh for a specific
unresolved problem. Start at the role's standing setting; these are not mandatory
retry steps. Correct missing context and task scope before raising effort.

**Astra is manual-only.** No standing role uses it, and failure, high risk, or
uncertainty does not authorize switching to it. Spawn Astra only when the operator
explicitly requests it. A measured benefit on representative tasks can justify a
recommendation, but requires that explicit request before use. Claude's exceptional
escalation remains Fable 5.1 / high. See [model routing](docs/model-routing.md)
for risk rules, research, capability checks, and local validation. The dated
[cost/effort assessment](docs/model-cost-effort.md) covers every active tier,
long-context pricing, older GPT alternatives, and the proposed Pareto candidates.

| Agent | Codex model | Effort | Claude model | Effort |
| --- | --- | --- | --- | --- |
| `explorer` | `gpt-6-luna` | low | `claude-haiku-5-5` | medium |
| `docs` | `gpt-6-luna` | medium | `claude-haiku-5-5` | medium |
| `implementor` | `gpt-6.1-sol` | medium | `claude-opus-5-5` | medium |
| `ui-engineer` | `gpt-6.1-sol` | medium | `claude-opus-5-5` | medium |
| `developer` | `gpt-6.1-sol` | high | `claude-opus-5-5` | high |
| `architect` | `gpt-6.1-sol` | high | `claude-opus-5-5` | high |
| `refactor-specialist` | `gpt-6.1-sol` | high | `claude-opus-5-5` | high |
| `test-engineer` | `gpt-6.1-sol` | high | `claude-opus-5-5` | high |
| `performance-engineer` | `gpt-6.1-sol` | high | `claude-opus-5-5` | high |
| `pr-reviewer` | `gpt-6.1-sol` | high | `claude-opus-5-5` | medium |
| `verifier` | `gpt-6.1-sol` | medium | `claude-opus-5-5` | medium |
| `a11y-auditor` | `gpt-6.1-sol` | medium | `claude-opus-5-5` | medium |
| `security-triage` | `gpt-6-luna` | medium | `claude-opus-5-5` | medium |
| `security-auditor` | `gpt-6.1-sol` | high | `claude-opus-5-5` | high |
| `browser-debugger` | `gpt-6.1-sol` | medium | `claude-opus-5-5` | medium |
| `pr-shepherd` | `gpt-6.1-sol` | medium | `claude-opus-5-5` | medium |

`browser-debugger` is a named Codex agent; on Claude the lead drives the browser
capability with Opus 5.5 at medium effort. Haiku 5.5 uses medium effort for
bounded lookup and straightforward docs; longer investigations escalate to Opus.
Claude model IDs are pinned so provider aliases cannot silently change this policy.
Runtime provider/availability overrides must be reported with the actual model.

### Why Sol 6.1 instead of Astra?

As of 2026-10-09, standard API rates per million tokens for inputs up to 272K are:

| Token category | GPT-6.1 Sol | GPT-6 Astra | Astra multiplier |
| --- | --- | --- | --- |
| Input | $2 | $10 | 5× |
| Cached input | $0.10 | $1 | 10× |
| Output | $10 | $50 | 5× |

Sources: [Sol 6.1](https://developers.openai.com/api/docs/models/gpt-6.1-sol) and
[Astra](https://developers.openai.com/api/docs/models/gpt-6-astra). These API rates
do not directly measure Codex subscription quota consumption or total task cost.

Official OpenAI documentation describes Sol 6.1 as delivering near-Astra
performance, not identical quality on every task. We have no representative
Keiko evaluation showing that Astra's benefit justifies its premium. The completed
Astra spawn probe established availability only; it was not a coding-quality
benchmark. Keep ordinary execution and escalation on Sol until evidence supports
recommending an explicitly requested Astra run.

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

The command hooks invoke gate scripts; the skills explicitly run receipt writers
(`verify-receipt`, `audit-receipt`, `ui-verify-receipt`) after checks. Hooks do not
automatically generate verification proof. Each gate/writer has a test in `tests/`.

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

## Target-owned server-side controls

Follow the target's existing branch controls and required checks/reviews; do not
introduce new administrative prerequisites or workflow status checks. Keiko's
current `AGENTS.md` and ADR-0135 own its app-bound required-check matrix and native
auto-merge authority. Stronger epic protection is optional unless the target
requires it, and its absence alone is not a workflow blocker. Full local access
still permits filesystem changes, regardless of branch protection.

## Sharing

Path-free and self-contained: a collaborator clones it and runs `install.sh` against
their own Keiko checkout. Per-machine bits stay local and git-ignored.
