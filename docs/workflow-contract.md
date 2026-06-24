# Agent Workflow Contract (tool-neutral)

The single, harness-neutral governance contract. The fat harness docs
(`claude/CLAUDE.md`, `codex/AGENTS.md`, `codex/RUNBOOK.md`) carry the
compaction-critical essentials inline; this file is the full reference both
point back to.

> Target repo: any repo that uses this setup (built for **Keiko** first).
> Integration branch: **`dev`**.

---

## Roles

- **Human operator** — selects one epic / issue / finding, talks **only** to the
  orchestrator, is interrupted only for true blockers after recovery attempts.
- **Orchestrator = the lead session** — the sole user-facing agent. Plans,
  decomposes, routes, delegates, integrates, relays status, files follow-up
  issues, gates PRs. **Never spawns a sub-coordinator.**
- **Worktree / role agents** — execute one issue each. Never expand scope, never
  contact the human, never file issues directly. Report status, completion, and
  blockers upward. (Canonical roles: see `.agents/roles.yaml`.)

## Delegation (task-shaped)

Default to the **smallest effective shape**. Single-agent for small/one-file
work; cluster (explorer -> writer -> verifier, or a team) for multi-module,
epic, security, or UI work. Route by issue `type`/`area` labels. Read-heavy
fan-out first; only disjoint write scopes in parallel.

## Branching & delivery

- Branch names are **tool-neutral**: `issue/<id>-<name>`, `epic/<name>`, base `dev`.
  (Both harnesses continue the _same_ branch for one issue; git author metadata
  gives provenance.)
- **Every issue gets a PR. Merge only on green CI.**
- `issue -> epic-branch`: **auto-merge** on green CI, no human.
- **`dev` is sacred**: every merge into `dev` (epic or standalone) requires a
  **human reviewer + green CI**. The only auto-merge in the system is
  `issue -> epic-branch`.
- Epic model: long-lived `epic/<name>` off `dev`; child `issue/...` off the epic
  branch; final epic PR -> `dev` is the human-gated handoff.

## Issue lifecycle

1. **Intake (Definition-of-Ready gate).** The issue must have acceptance criteria
   - a verification command. If missing -> triage first, do not start.
     **Collision check:** do not pick an issue that already has a GitHub assignee
     other than the operator — it is being worked. Skip it and report.
2. **Route.** Pick execution shape by labels.
3. **Branch + claim.** Claiming is mandatory before implementation:
   `gh issue edit <N> --add-assignee @me` (assign the operator), set the board
   `status: in progress`, owner, and branch. No assignee = not claimed.
4. **Implement.** Measurable bars: complexity <=10, function <=50 LOC,
   file <=400 LOC, no `any`, TDD. Mandatory 2-pass self-critique before "done".
   **User-facing components** additionally conform to the Keiko Design System
   (`docs/design-system/`): semantic/component tokens only (no raw Tier-1
   primitives or hex literals), full `state-matrix.md` coverage, `governance.md`
   change-rules.
5. **Verify (pre-PR-ready gate).** `npm run verify` (full CI mirror) must be green
   locally. Before an issue can be considered PR-ready / `Ready for Human Review`,
   run the `keiko-issue-audit` skill as a final issue-scoped audit pass. Verifier
   auto-fills the PR template with evidence. **A user-facing-component change is
   not verified until its design-system fidelity + a11y evidence is captured under
   `docs/design-system/evidence/<N>/` (ADR-0049/0050/0051).**
6. **PR.** `issue -> epic` auto-merges on green CI; any `-> dev` waits for a human.
7. **Completion judge.** Strong-model gate vs acceptance criteria; <=2 re-loops
   then escalate.
8. **Flush + report.** Orchestrator writes current state + next action to the
   issue/PR (continuous-flush) so any harness can resume.

## Out-of-scope blockers

- Worktree agent reports the blocker upward with a proposed title/scope —
  **never** expands scope or files directly.
- Orchestrator dedups against open issues -> files via the issue template ->
  labels `status: new` -> links to the current issue.
- Classify: **hard blocker** (mark current issue `status: blocked`, file the
  dependency, prioritize or escalate per the 3-attempt rule) vs **finding**
  (file, continue in-scope).

## Escalation

A blocker becomes human-visible only after **3 materially distinct recovery
attempts** on the same issue. Re-scoping/splitting counts toward the threshold;
it does not reset it. Escalation summarizes: what was attempted, why each
failed, why further autonomous recovery is unlikely.

## Quality gate stack

1. lint-staged pre-commit (changed files: prettier + eslint + tsc) — instant.
2. Mandatory 2-pass adversarial self-critique — per agent.
3. `verify.sh` (full CI mirror) — hard pre-PR gate.
4. **Proof-of-audit gate** — `keiko-issue-audit` writes a SHA-bound receipt
   (`.git/keiko-audit/<branch>.json`); a PreToolUse hook blocks `gh pr create` on
   an `issue/*` or `epic/*` branch unless a receipt exists for the current HEAD.
   An issue cannot become PR-ready without proof the audit ran against the exact
   code being shipped.
5. Strong-model completion judge (Stop-hook, loop-capped <=2).
6. CI on protected `dev` — unbypassable server-side backstop _(requires repo
   admin to configure; see README "Server-side prerequisites")_.

## Status & memory

- **GitHub delivery board** is the single durable status source of truth.
  No local state store. Activation discipline (don't start `blocked` work) is
  read off board states.
- **Shared memory** lives at `.agents/memory/<role>/MEMORY.md`, keyed by
  canonical role, read+written by both harnesses. Commit curated files (<25 KB).
  Audit trail = GitHub (PRs/comments/evidence); memory = learnings only.

## Observability

- A live activity feed renders the harness hook logs into a per-agent stream.
- The orchestrator posts a one-line heartbeat at each wave/milestone.
- Desktop notifications fire on attention / done.

## Git transport

SSH-first. On SSH failure, attempt local repair (agent identities, SSH config,
key registration) before falling back to HTTPS. Do not silently normalize to
HTTPS.

## Safety posture

Agents run with full local access for velocity; the dangerous outcome is made
impossible **server-side** (protected `dev`: PR-only, green CI, human review for
`-> dev`). Local guardrails: deny-list for irreversible ops (force-push, history
rewrite, `rm -rf` on shared paths) + secret-scan pre-commit.
