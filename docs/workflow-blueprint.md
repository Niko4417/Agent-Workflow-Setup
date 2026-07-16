# Keiko Agent Workflow — Optimal Setup Blueprint

> **Status:** Draft for review. This is a design spec, not yet implemented.
> It defines the target state for the Keiko agent workflow, built on the
> `Downloads/setUp` folder (the running `.claude` + `.codex` platform) as the
> base, with the strongest ideas from `project.md` folded in and every conflict
> resolved.
>
> Nothing in the live `.claude/` or `.codex/` setup changes until this document
> is approved.

---

## 0. How to read this document

- **Section 1** — the decisions, each with the tradeoff that was accepted.
- **Section 2** — the resolved conflicts (where the two source setups disagreed).
- **Section 3** — the target file/directory structure.
- **Section 4** — the operating contract (roles, lifecycle, gates) in prose.
- **Section 5** — the implementation plan as an epic + child issues.
- **Section 6** — open items still needing a human decision.

Every decision below traces back to a deliberate choice. Where a cheaper or
faster alternative was rejected, the tradeoff is stated so the reasoning
survives.

---

## 1. Decisions (with accepted tradeoffs)

| #   | Decision                                                                                                                                                                                                                                                                                                                                                                                                                | Accepted tradeoff                                                                                                              |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| 1   | **Codex-primary, Claude = second-opinion / token-overflow backup.** Invest depth in `.codex`; keep `.claude` lean but fully functional.                                                                                                                                                                                                                                                                                 | Maintain a second stack instead of consolidating to one.                                                                       |
| 2   | **Task-shaped graduated delegation.** Default to the smallest effective shape; cluster only when parallel review materially helps. Trigger = the RUNBOOK's issue `type`/`area` label routing.                                                                                                                                                                                                                           | Coordinator must judge per-issue; not "always delegate", not "always solo".                                                    |
| 3   | **`dev` is sacred.** Every issue gets a PR. The _only_ auto-merge is `issue → epic-branch`, after exact-head GitHub `ci` plus matching SHA-bound verify/audit evidence; a user-facing child additionally needs a green ui-verify Playwright run + test-plan comment. **Every merge into `dev` (epic or standalone) requires a human + green CI.**                                                                       | Slower throughput into `dev` in exchange for a human gate on every `dev` entry and a PR-backed evidence trail on every change. |
| 4   | **Canonical role vocabulary + alias map.** One source-of-truth role set; harness-specific names alias to it; harness-only specialists map to a canonical capability.                                                                                                                                                                                                                                                    | Upfront normalization; flattens a few harness-specific specialists into capabilities.                                          |
| 5   | **Shared, tool-neutral memory tree keyed by canonical role**, read+written by both harnesses. Commit curated `MEMORY.md` (<25 KB) per role; per-issue exploration dumps are ephemeral scratch.                                                                                                                                                                                                                          | Tiny concurrent-write risk (rare in practice); must agree one memory format.                                                   |
| 6   | **GitHub delivery board = single durable status source of truth.** No `.orchestrator/` state store. Activation discipline read off board states.                                                                                                                                                                                                                                                                        | More GitHub API chatter; no separate local state machine.                                                                      |
| 7   | **Fat harness-native docs** (`CLAUDE.md`, `AGENTS.md`, `RUNBOOK.md` stay self-contained for compaction resilience).                                                                                                                                                                                                                                                                                                     | Policy duplicated ~3×; mitigated by a shared "policy block" + sync checklist.                                                  |
| 8   | **Keep the automated completion judge (Stop-hook)** but run it on a strong model (Sonnet / gpt-5.4-class, **not** Haiku) with a **hard loop cap** (≤2 re-loops → escalate). Port the same gate to Codex.                                                                                                                                                                                                                | Small judge cost vs. catching weak/incomplete work; cap removes infinite-loop risk.                                            |
| 9   | **Full agent access + server-side guardrails.** Keep agents full-access for velocity; make the dangerous outcome impossible at GitHub: protected `dev` (PR-only, green-CI, human review), irreversible-op deny-list, secret-scan pre-commit.                                                                                                                                                                            | Velocity over per-action prompts; safety enforced where it matters (the `dev` boundary), not per-keystroke.                    |
| 10  | **The lead session is always the orchestrator.** Never spawn a sub-coordinator. Codex's `coordinator.toml` becomes the lead's operating instructions, not a spawnable agent.                                                                                                                                                                                                                                            | The user-facing layer cannot be parallelized.                                                                                  |
| 11  | **Continuous flush + on-demand deep handoff.** The orchestrator's regular status update writes "current state + next action" to the active issue/PR, so GitHub is always resume-ready; `/handoff` for deliberate switches.                                                                                                                                                                                              | Discipline of flushing state, vs. losing the last slice of in-flight reasoning on abrupt exits.                                |
| 12  | **Tiered pre-PR verification.** lint-staged pre-commit (changed files) + `verify.sh` (full CI mirror). This grew into the **gate chain**: `verify-receipt`/`audit-receipt`/`ui-verify-receipt` stamp SHA-bound proof, and PreToolUse gates (`verify-gate`, `audit-gate`, `ready-gate`, `push-gate`, `epic-merge-gate`) block the PR/merge unless verify is green and the audit is clean. See the contract's gate stack. | ~90% of CI caught locally; clean-install smoke, CodeQL, dependency-review, actionlint, pinned-SHA remain CI-only.              |
| 13  | **Out-of-scope blockers → orchestrator-filed issues.** Worktree agents never expand scope or file directly; they report up. Orchestrator dedups, files via template, marks `needs-triage`, links to the current issue, classifies blocker vs. finding.                                                                                                                                                                  | A hop through the orchestrator (slightly slower) vs. issue spam + broken chain of command.                                     |
| 14  | **Live observability layer.** Build `keiko-watch` over the JSONL hook logs (both harnesses) + enforced orchestrator heartbeat + desktop notifications.                                                                                                                                                                                                                                                                  | Modest build cost vs. "am I just sitting here" silence during long sub-agent runs.                                             |

### Value-adds in scope (neither source setup had these)

- **Definition-of-Ready intake gate** — the orchestrator refuses to start an
  issue lacking acceptance criteria + a verification command; it triages first.
- **Automated evidence capture** — the verifier auto-fills the PR template with
  commands run, test output, and CI links. Makes "evidence-backed" enforced,
  not promised.
- **Scheduled memory consolidation** — a periodic prune/merge keeps the shared
  memory tree curated and under 25 KB.

---

## 2. Resolved conflicts

These are the points where `project.md` and the `setUp` folder contradicted each
other. Each is now resolved.

| Conflict                  | `project.md` said                               | Folder said                                                       | Resolution                                                                                                                                                                                                     |
| ------------------------- | ----------------------------------------------- | ----------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Integration branch**    | `dev`                                           | `.codex/config.toml`: `origin/main`                               | **`dev`** everywhere. Fix the `config.toml` line — it's an outright bug (repo default is `dev`).                                                                                                               |
| **Branch naming**         | `issue/<id>-<name>`, `epic/<name>`              | `claude/issue-{id}-...`                                           | **Tool-neutral** `issue/<id>-<name>`, `epic/<name>`. Required so both harnesses continue the _same_ branch for one issue instead of forking `codex/123` vs `claude/123`. Git author metadata gives provenance. |
| **Completion**            | PR for every issue                              | RUNBOOK: ordinary issues land directly on `dev`                   | **PR for every issue; `dev` is human-gated on every merge.**                                                                                                                                                   |
| **Status store**          | `.orchestrator/*.json` (repo) / GitHub (pasted) | GitHub delivery board                                             | **GitHub board only.** Drop `.orchestrator/`.                                                                                                                                                                  |
| **Delegation default**    | Always delegate                                 | `.codex`: single-agent by default                                 | **Task-shaped graduated** (smallest effective shape).                                                                                                                                                          |
| **Memory commit policy**  | `.orchestrator/` not merge-worthy               | `AGENTS.md` says "don't commit tool-specific memory" yet ships it | **Commit curated role memory** (it's the learning asset); fix the contradictory `AGENTS.md` line; ephemeral dumps stay out.                                                                                    |
| **Orchestrator identity** | Single user-facing orchestrator                 | Spawnable `coordinator.toml` + lead both act as coordinator       | **Lead session is the sole orchestrator;** `coordinator.toml` → lead operating instructions.                                                                                                                   |

### Determined fixes (mechanical, no judgment)

- `.codex/config.toml`: `origin/main` → `dev`.
- `.codex/config.toml`, `.claude/launch.json`: hardcoded `/Users/oscharko-dev/...`
  paths → `$(git rev-parse --show-toplevel)`-relative (current user is
  `nikolaos.vasilopoulos`; the foreign paths will silently break).
- Lift **SSH-first git transport policy** from `project.md` (the folder has
  nothing; pure addition).
- **MCP parity for Claude** — the Claude stack only allows the Figma MCP; port
  Context7 / GitHub / Playwright so the backup harness isn't crippled.
- **Port measurable quality bars + 2-pass self-critique into the Codex (primary)
  agent defs** — this machinery currently lives mostly on the Claude side.
- `keiko.config.json` (model providers) is **product runtime config**, not
  workflow — out of scope, leave as-is.

---

## 3. Target structure

```
repo/
├─ CLAUDE.md                      # fat, self-contained (Claude coordinator rules)
├─ AGENTS.md                      # fat, self-contained (Codex product + delivery)
├─ docs/
│  ├─ workflow-blueprint.md       # this file
│  └─ workflow-contract.md        # tool-neutral governance contract (the good half of project.md)
├─ .github/
│  ├─ workflows/                  # CI (unchanged; the backstop)
│  └─ branch-protection notes     # dev = PR-only, green-CI, human review
├─ .agents/                       # NEW: tool-neutral shared layer
│  ├─ roles.yaml                  # canonical role set + capability specs
│  ├─ aliases.yaml                # harness-name → canonical-role map
│  └─ memory/<role>/MEMORY.md     # shared curated memory (committed, <25 KB)
├─ .codex/                        # PRIMARY harness
│  ├─ config.toml                 # dev integration target; repo-relative MCP paths
│  ├─ RUNBOOK.md                  # fat ops doc; ported quality bars + self-critique
│  ├─ agents/*.toml               # roles incl. ported measurable bars
│  ├─ playbooks/*.md
│  └─ hooks/                      # cluster_lifecycle_logger.py → feeds keiko-watch
├─ .claude/                       # BACKUP harness (lean but functional)
│  ├─ settings.json               # strong-model Stop-judge + loop cap; MCP parity
│  ├─ agents/*.md
│  └─ teams/*.md
├─ scripts/
│  ├─ verify.mjs (or npm script)  # CI mirror, exact job order
│  └─ keiko-watch                 # live per-agent activity feed (both harnesses)
├─ .husky/                        # NEW: lint-staged pre-commit (changed files)
└─ package.json                   # + "verify" script, + lint-staged config
```

**Notes**

- `.agents/memory/` replaces the split `.claude/agent-memory` + `.codex/agent-memory`
  trees. Existing `MEMORY.md` content is migrated by canonical role; the 80+
  per-issue explorer dumps are archived out of the repo, not committed.
- `docs/workflow-contract.md` is tool-neutral and additive — the fat harness
  docs still carry the compaction-critical rules inline; the contract is the
  single place the _full_ governance prose lives (referenced, not relied upon
  for compaction survival).

---

## 4. Operating contract (prose)

### Roles

- **Human operator** — selects one epic / issue / finding, talks **only** to the
  orchestrator, is interrupted only for true blockers after recovery attempts.
- **Orchestrator = the lead session** — the sole user-facing agent. Plans,
  decomposes, routes, delegates, integrates, relays status, files follow-up
  issues, gates PRs. Never spawns a sub-coordinator.
- **Worktree / role agents** — execute one issue each. Never expand scope, never
  contact the human, never file issues directly. Report status, completion, and
  blockers upward.

### Issue lifecycle

1. **Intake (Definition-of-Ready gate).** Orchestrator checks the issue has
   acceptance criteria + a verification command. If missing → triage first, do
   not start.
2. **Route.** Pick execution shape by `type`/`area` labels (single-agent vs.
   cluster). Read-heavy fan-out first; disjoint write scopes only.
3. **Branch.** `issue/<id>-<name>` off `dev` (standalone) or off `epic/<name>`
   (epic child). Claim on the GitHub board (`In Progress`, owner, branch).
4. **Implement.** Measurable bars enforced (complexity ≤10, file ≤400 LOC, no
   `any`, TDD). Mandatory 2-pass self-critique before "done".
5. **Verify + audit (pre-PR gates).** `verify-receipt` runs `verify.sh` (full CI
   mirror) and stamps a receipt only when green; `keiko-issue-audit` loops to
   `findings=0`; a user-facing change also runs a real Playwright plan (`ui-verify`).
   Two PreToolUse gates (`verify-gate` + `audit-gate`) **block `gh pr create`**
   unless verify is green and the audit is clean at HEAD. Verifier fills the PR
   template with evidence.
6. **PR.** Open the PR. `issue → epic-branch` auto-merges only after exact-head
   GitHub `ci` plus matching verify/audit evidence — enforced by
   `epic-merge-gate` and `gh pr merge --match-head-commit <audited-sha>`; a
   user-facing child additionally needs ui-verify + a test-plan comment. Any merge into `dev` waits for a
   human + green CI; `push-gate` re-runs the QA on any fix repushed to a `dev` PR.
7. **Completion judge.** Strong-model Stop-hook reviews against acceptance
   criteria; ≤2 re-loops then escalate.
8. **Flush + report.** Orchestrator writes current state + next action to the
   issue/PR (continuous-flush) and reports up.

### Out-of-scope blocker handling

- Worktree agent reports the blocker upward with a proposed title/scope.
- Orchestrator dedups against open issues → files via the GitHub template →
  board `needs-triage` → links to the current issue.
- Classify: **hard blocker** (mark current issue `blocked`, file the dependency,
  prioritize or escalate per the 3-attempt rule) vs. **finding** (file, continue
  in-scope).

### Escalation

- A blocker becomes human-visible only after **3 materially distinct recovery
  attempts** on the same issue. Re-scoping/splitting counts toward the threshold,
  it does not reset it. Escalation summarizes: what was attempted, why each
  failed, why further autonomous recovery is unlikely.

### Quality gates (the full stack)

1. lint-staged pre-commit (changed files: prettier + eslint + tsc) — instant.
2. Mandatory 2-pass self-critique — per agent.
3. `npm run verify` (full CI mirror) — hard pre-PR gate.
4. Strong-model completion judge (Stop-hook, loop-capped).
5. CI on protected `dev` — unbypassable server-side backstop.

### Observability

- `keiko-watch` renders the JSONL hook logs into a live per-agent stream.
- Orchestrator posts a one-line heartbeat at each wave/milestone.
- Desktop notifications on attention/done (both harnesses).

### Git transport

- SSH-first. On SSH failure, attempt local repair (agent identities, SSH config,
  key registration) before falling back to HTTPS. Do not silently normalize to
  HTTPS.

---

## 5. Implementation plan — `epic/workflow-setup`

Dogfoods the workflow it builds. Child issues, in dependency order:

1. **`issue/mechanical-fixes`** — `origin/main`→`dev`; repo-relative MCP/launch
   paths; SSH transport policy; fix the contradictory `AGENTS.md` memory line.
   _(No dependencies; ship first.)_
2. **`issue/canonical-roles`** — `.agents/roles.yaml` + `aliases.yaml`; map both
   rosters; reframe `coordinator.toml` as lead instructions. _(Blocks 3, 5.)_
3. **`issue/shared-memory`** — `.agents/memory/<role>/`; migrate existing
   `MEMORY.md` by role; archive per-issue dumps; gitignore ephemeral scratch.
   _(Depends on 2.)_
4. **`issue/verify-gate`** — `npm run verify` (exact CI order); lint-staged +
   husky pre-commit; wire as the pre-PR gate. _(No dependencies.)_
5. **`issue/quality-gates`** — strong-model Stop-judge + loop cap; port
   measurable bars + 2-pass self-critique to Codex; MCP parity for Claude.
   _(Depends on 2.)_
6. **`issue/observability`** — `keiko-watch` feed; heartbeat discipline;
   port notifications to Codex. _(No dependencies.)_
7. **`issue/blocker-flow`** — orchestrator-filed out-of-scope issue procedure +
   board `needs-triage` lane. _(Depends on GitHub board conventions.)_
8. **`issue/value-adds`** — Definition-of-Ready gate; automated evidence
   capture in the PR template; scheduled memory consolidation. _(Depends on 3, 4.)_
9. **`issue/contract-doc`** — `docs/workflow-contract.md` + the shared "policy
   block" + sync checklist embedded in the fat docs. _(Last; references all.)_

Server-side, out-of-band (human action, not an agent issue):

- Configure **branch protection on `dev`**: require PR, require green CI, require
  human review for epic merges.

---

## 6. Open items needing a human decision

- **Branch protection specifics** — exact required CI checks list and whether
  standalone-issue PRs into `dev` require 1 or 2 human approvals. (The contract
  says human-gated; the _count_ is yours.)
- **`keiko-watch` surface** — terminal TUI only, or also write a tail-able file
  the desktop app / a browser tab can render? (Default: terminal + tail-able
  file.)
- **Memory migration cutover** — migrate existing `.claude` memory content into
  `.agents/memory/` in one pass, or start `.agents/memory/` fresh and let it
  accrete? (Default: one-pass migration of curated content only.)

---

---

## Appendix A — Canonical role set (LOCKED)

15 canonical roles. `coordinator` is intentionally absent — it is the lead
session's operating instructions, not a spawnable role (Decision #10).

### Read / analyze

| Canonical role         | Responsibility                                                                                                                                               | Default posture |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------- |
| `explorer`             | Internal code mapping **and** external doc/API/version grounding (Context7/web).                                                                             | read-only       |
| `architect`            | ADRs, service boundaries, dependency direction, contract decisions.                                                                                          | docs/adr only   |
| `security-triage`      | Fast first-pass scan: OWASP grep, dangerous primitives, secret leaks, missing authz. Escalates to `security-auditor`.                                        | read-only       |
| `security-auditor`     | Deep audit: crypto/auth, data-flow tracing, trust boundaries, supply chain. Also covers diff/PR-scoped security review.                                      | read-only       |
| `performance-engineer` | LCP/INP/CLS, bundle, N+1, hot paths, large-data behavior.                                                                                                    | read-only       |
| `a11y-auditor`         | WCAG 2.2 AA review.                                                                                                                                          | read-only       |
| `verifier`             | Acceptance-criteria verification + automated evidence capture for the PR.                                                                                    | read-only       |
| `pr-reviewer`          | Multi-dimension PR review before merge.                                                                                                                      | read-only       |
| `browser-debugger`     | Real-browser reproduction + evidence capture. **Codex:** agent. **Claude:** capability — lead/agent driving Playwright or Chrome MCP, not a named sub-agent. | reproduction    |

### Write

| Canonical role        | Responsibility                                                                                                     |
| --------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `developer`           | Spec-first, TDD, planning, research, end-to-end implementation (heavy).                                            |
| `implementor`         | Scoped minimal-diff worker; precise definition of done; no planning, no delegation.                                |
| `test-engineer`       | Test coverage, regression harnesses, mutation-robust tests.                                                        |
| `ui-engineer`         | Figma→code, component build, design-system consistency. Also small/targeted UI fixes.                              |
| `refactor-specialist` | Behavior-preserving cleanup (complexity reduction).                                                                |
| `docs`                | Write **and** maintain docs: README, API, ADR, CHANGELOG, migration/troubleshooting notes, link-aware maintenance. |

### Drive

| Canonical role | Responsibility                                                     |
| -------------- | ------------------------------------------------------------------ |
| `pr-shepherd`  | Drive an open PR to merge-ready; delegates fixes to `implementor`. |

### Alias map (`aliases.yaml`)

Harness-specific names that resolve to a canonical role:

| Harness name                | Canonical role     | Notes                                                                 |
| --------------------------- | ------------------ | --------------------------------------------------------------------- |
| `security-reviewer` (Codex) | `security-auditor` | Diff/PR-scoped invocation of the auditor — same depth, change-scoped. |
| `docs-writer` (both)        | `docs`             | —                                                                     |
| `docs-editor` (Codex)       | `docs`             | —                                                                     |
| `docs-researcher` (Codex)   | `explorer`         | External grounding is a research capability of `explorer`.            |
| `ui-fixer` (Codex)          | `ui-engineer`      | Small-fix scope of the same UI write capability.                      |
| `coordinator` (Codex)       | _(none)_           | Becomes lead-session operating instructions; not spawnable.           |

### Roster delta (what changes per harness)

- **Codex (21 → 16 + lead):** retire `security-reviewer`, `docs-editor`,
  `docs-researcher`, `ui-fixer` as separate agents (alias to canonical);
  convert `coordinator` to lead instructions. Keep `browser-debugger`.
- **Claude (15 → 16):** `security-triage` + `security-auditor` already correct;
  rename/merge `docs-writer` → `docs`; add `browser-debugger` **as a capability
  pattern** (Playwright/Chrome MCP), not a new agent file; everything else maps
  1:1.
- **Memory keys** (`.agents/memory/<role>/`) use the 15 canonical names only.

---

_End of blueprint. Review, mark up, and approve before any change lands in
`.claude/` or `.codex/`._
