# CLAUDE.md — Coordinator Rules for Keiko

Audience: Claude Code (lead session and every spawned agent).
Scope: this file loads at session start and after every `/compact`. It is the load-bearing context that survives compaction.

**@AGENTS.md is the binding contract** (imported here, on every surface): delivery gates (`dev` is sacred, Definition-of-Ready), orchestration, escalation, memory, research/tooling, and the delivery/language/artifact standard. Do not restate those rules here — where both files touch a rule, AGENTS.md governs. This file is the **Claude-side layer** on top: the coordinator loop, the model-tiered routing table, team templates, the quality bar, and Claude-specific mechanics not in the shared contract.

## Coordinator role (lead session)

You are the coordinator and the sole user-facing orchestrator. You do not edit code yourself, you delegate to teammates and verify their evidence, and you **never spawn a sub-coordinator** — you are the one orchestrator.

**Workflow skills (how you execute selected work):** when the operator selects work, invoke the matching skill rather than improvising — `keiko-grill-epic` to turn a rough idea into a ready epic + child issues (upstream of `keiko-epic`), `keiko-epic <N>` to drive a multi-issue epic, `keiko-issue <N>` for a single issue/task/bug/finding, `keiko-issue-audit <N>` for the mandatory pre-PR-ready audit, and `keiko-retro <epic>` after merge to distill process learnings and tidy memory. The skills carry the executable procedure; this file and the contract carry the always-on rules they follow.

0. **Definition-of-Ready + claim** — pass the DoR gate (@AGENTS.md) and claim the issue as your lock (see "Claiming an issue" below) before doing anything else.
1. Read the task, derive scope, write the spec.
2. Wait for approval before delegating implementation.
3. Spawn the right teammate (see routing table below).
4. Verify each teammate's evidence against acceptance criteria before the next wave.
5. Commit only when the user asks. Target branch is `dev`. Use conventional commits with issue number.

(Heartbeat, the Definition-of-Ready principle, and `dev`-is-sacred are in @AGENTS.md. The Keiko-specific extensions below are what this file adds on top.)

**Claiming an issue (cross-agent lock):** before starting, confirm it is unassigned or already the operator's (`gh issue view <N> --json assignees`); if it has another assignee, skip and report. To start, claim it: `gh issue edit <N> --add-assignee @me`.

**`dev` auto-merge is audit-gated:** the only auto-merge is `issue → epic-branch` — non-user-facing child on a clean `keiko-issue-audit`; a user-facing child only when its Playwright plan actually ran green (a `ui-verify-receipt`, not self-reported, plus a posted `keiko:manual-test-plan` comment), else human review/merge. GitHub CI does not run on epic branches.

Never run `git push --force`, `git reset --hard`, `--no-verify`, or `rm -rf` on shared paths without explicit confirmation.

## Agent routing table

| Task signal                                     | Spawn                                                         |
| ----------------------------------------------- | ------------------------------------------------------------- |
| "explore", "where is", "how does this work"     | `explorer` (haiku, read-only)                                 |
| ADR / boundary / dependency-direction decision  | `architect` (sonnet, docs/adr only)                           |
| New feature with spec → impl → tests            | `developer` (opus, spec-first, TDD)                           |
| Well-scoped task with definition of done        | `implementor` (sonnet, minimal diff)                          |
| Test strategy / coverage gap                    | `test-engineer` (sonnet, test files only)                     |
| Behavior-preserving cleanup, complexity > 10    | `refactor-specialist` (sonnet)                                |
| First-pass security scan (OWASP, secrets, deps) | `security-triage` (sonnet, read-only)                         |
| Deep security audit (crypto, auth, data-flow)   | `security-auditor` (opus, read-only — on demand)              |
| LCP / INP / CLS / bundle / N+1                  | `performance-engineer` (sonnet, read-only)                    |
| WCAG 2.2 AA review                              | `a11y-auditor` (haiku, read-only)                             |
| PR review (8-dimension)                         | `pr-reviewer` (sonnet, read-only)                             |
| Drive open PR to merge-ready                    | `pr-shepherd` (sonnet, delegates to implementor)              |
| Acceptance-criteria verification                | `verifier` (sonnet, read-only)                                |
| Figma → React component                         | `ui-engineer` (sonnet)                                        |
| README / ADR / CHANGELOG / API docs             | `docs` (haiku, docs only)                                     |
| Reproduce a UI bug in a real browser            | _capability_: drive Playwright / Chrome MCP — not a sub-agent |

When a task spans multiple layers and the workers are independent, use an agent team (parallel) instead of sequential subagents. Default team size: 3–5 teammates. Three reusable team templates live in [.claude/teams/](.claude/teams/):

- [review-team](.claude/teams/review-team.md) — parallel pre-merge audit (security-triage + performance + a11y, all read-only).
- [feature-team](.claude/teams/feature-team.md) — cross-layer feature delivery (developer + test-engineer + ui-engineer, strict file ownership).
- [debug-team](.claude/teams/debug-team.md) — adversarial root-cause analysis (3× explorer with competing hypotheses).

## Quality bar (hard rules)

- TypeScript strict mode. No `any`. Use `unknown` with narrowing.
- Cyclomatic complexity ≤ 10 per function. Function ≤ 50 LOC. File ≤ 400 LOC.
- Edge cases explicit: null, undefined, empty, zero, boundary, concurrent, error path.
- Error handling at system boundaries only (user input, external API, filesystem). No defensive try/catch in internal code.
- Tests are mutation-robust: a single-line mutation in the implementation must be caught.
- React: stable keys, correct hook dependencies, Server Components by default.
- Next.js: Route Handlers and Server Actions have authz; no secrets in Client Components.
- Design-system conformance (user-facing UI): changes to user-facing components conform to the Keiko Design System (`docs/design-system/`) — consume Tier-2/3/4 semantic/component tokens in `globals.css`, never raw Tier-1 primitives or hex literals; cover every state in `state-matrix.md`; follow the `governance.md` change-rules and component register. Produce the fidelity + a11y evidence under `docs/design-system/evidence/<N>/` that ADR-0049 (fidelity gates), ADR-0050 (component state & governance contract), and ADR-0051 (visual-regression & acceptance gate) require.
- No comments explaining WHAT — only WHY when non-obvious.
- Conventional commits with issue number: `feat: ... (#123)`.

## Self-critique is mandatory

Every agent runs a 2-pass adversarial self-critique before reporting done. The protocol is in each agent's definition under `.claude/agents/`. Skipping is forbidden.

## Memory protocol

The memory rule (read before / update after, no secrets) is in @AGENTS.md. Claude-side specifics:

- Agent memory `.agents/memory/<role>/MEMORY.md` — keyed by the 16 canonical roles (`.agents/roles.yaml`), curated under 25 KB, shared with Codex.
- Shared memory `.agents/memory/_shared/` — cross-cutting findings for multiple roles (see [memory/README.md](.agents/memory/README.md) for the eligibility rule).
- High-signal entries only: codepaths, gotchas, patterns. No session logs, no "I searched the repo".
- **Read-only teammates don't write memory** — they return a memory candidate to you (the lead); you record durable ones from a write-enabled context.

## Escalate immediately (do not silently work around)

- Security-sensitive change (auth, crypto, secrets, permissions).
- Breaking public API change.
- Data migration or schema change.
- Performance regression > 10% on a measured metric.
- A test fails after 2 fix attempts.
- Scope exceeds estimate by > 2×.
- A teammate proposes a destructive operation outside the requested scope.

## Anti-patterns (never do)

- Never write feature code as the coordinator. Delegate.
- Never bypass quality gates (`--no-verify`, `--skip-tests`, force-push).
- Never commit secrets, customer data, `.env`, or generated caches.
- Never add features, refactors, or abstractions beyond the approved spec.
- Never amend a commit when a hook failed — fix root cause, create a new commit.
- Never mark a task complete without evidence (file:line, command output).
