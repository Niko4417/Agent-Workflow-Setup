# Codex Agent Team Runbook

This runbook defines how to use the project-scoped Codex agent team for Keiko.
The GitHub issue is always the source of truth for scope, acceptance criteria,
dependencies, and definition of done.

## Intake Gate (Definition of Ready)

Before any agent starts an issue, the lead confirms it is READY:

- it has explicit acceptance criteria, and
- it names (or the lead can derive) a concrete verification command.

If either is missing, do not start: triage first — comment the gap on the issue,
set `status: new`/`needs triage`, and either fill the criteria with maintainer
input or escalate. Starting an under-specified issue wastes autonomous work.

## Status Cadence (Heartbeat)

The lead posts a one-line heartbeat at every wave/milestone so the human is never
left guessing whether work is happening: which agent is doing what, and the next
action. Flush "current state + next action" to the active issue/PR so either
harness (Codex or Claude) can resume from GitHub alone.

## Default Lifecycle

1. Start from a GitHub issue ID.
2. Fetch the issue, linked PRs, comments, labels, and current CI state.
3. Add the issue to the public `Keiko Product Delivery` project if it is not
   already present.
4. Claim the issue before implementation: set the issue label to
   `status: in progress`, project `Status` to `In Progress`, project
   `Workflow State` to `In Progress`, `Owner / Agent` to the active agent. Set
   `Human Review Required` to `Yes` for any PR that will target `dev` (epic or
   standalone); only `issue -> epic-branch` PRs may auto-merge on green CI.
5. Choose the execution mode from the issue template.
6. Load coordinator memory and relevant role memory.
7. Create a short coordination plan with file ownership, agent roles, stop
   conditions, and verification gates.
8. Run read-only discovery before write work when the scope touches multiple
   modules, architecture, security, UI behavior, release gates, or CI.
9. Assign write agents only to disjoint scopes.
10. Integrate work in the coordinator thread.
11. Run the narrowest meaningful checks locally, then verify GitHub `ci`.
12. Before an issue can be considered PR-ready / `Ready for Human Review`, run
    the `keiko-issue-audit` skill as the final issue-scoped audit pass. It may
    confirm zero findings, but the pass is mandatory.
13. When implementation work uses a PR, fill project `Branch` and
    `Pull Request`, then set `Workflow State` to `PR Open`.
14. When a `-> dev` PR has passed `keiko-issue-audit`, has green required
    checks, and is ready for maintainer review, set `Workflow State` to
    `Ready for Human Review` and the issue label to
    `status: ready for human review`.
15. Update durable memory. Do not store secrets, customer data, raw source dumps,
    or token-bearing logs.

## Delivery Board Rules

- Project: `Keiko Product Delivery`.
- Board states: `New`, `Triaged`, `In Progress`, `PR Open`,
  `Ready for Human Review`, `Blocked`, `Waiting for User`, `Done`.
- Never start implementation on an issue without first setting it to
  `In Progress` and filling `Owner / Agent`.
- Keep `Branch` and `Pull Request` current so other agents can see ownership.
- `dev` is sacred: every PR that targets `dev` (epic OR standalone) sets
  `Human Review Required` to `Yes` and waits for a human reviewer + green CI.
- The only auto-merge in the system is `issue -> epic-branch` on green CI.
- Every issue ships as a PR; nothing lands on `dev` without a PR.
- No issue becomes `Ready for Human Review` until `keiko-issue-audit` has run.
- Any `-> dev` PR hands off at `Ready for Human Review` only after that audit
  pass and green required checks.
- Do not merge any PR into `dev`, enable auto-merge into `dev`, close the issue,
  or mark `Done` unless the human maintainer explicitly authorizes that action.

## Agent Routing by Issue Signal

- `type: epic`: the lead coordinates with `architect`; do not implement the whole
  epic unless a child issue is selected.
- `type: task` or `type: feature`: the lead drives `explorer`, then
  `implementor`/`developer`, `test-engineer`, `verifier`.
- `type: bug`: `explorer`, `browser-debugger` when UI-visible,
  `implementor`, `test-engineer`, `verifier`.
- `type: follow-up`: usually `developer` or small agent team.
- `area: frontend`: add `ui-engineer`, `a11y-auditor`, and
  `performance-engineer` when UI risk is material.
- `area: bff`: add `security-auditor` when request/session/rate-limit/CSP
  behavior changes.
- `area: architecture`: add `architect` and `docs`.
- `area: security`: add `security-auditor`.
- `area: release`: add `pr-shepherd` and `verifier`.
- `area: evidence`, `area: orchestration`, `area: harness`, or
  `area: model-gateway`: add `architect` and `security-auditor`.

## Verification Routing

- Always required before merge: GitHub check `ci`.
- Always required before `Ready for Human Review`: `keiko-issue-audit`.
- Studio UI or BFF browser behavior: Studio browser quality gate.
- Monaco/editor performance, rendering, large-file behavior: Studio perf/memory.
- Visible UI structure: Studio visual regression.
- Markdown docs: markdown link check.
- W0.2 workflow/evidence/model behavior: W0.2 release gate.
- W0.3 workflow/Studio hardening behavior: W0.3 release gate.
- Security-sensitive changes: security review plus Qodana/static-analysis review
  when practical.

## Stop Conditions

Stop and report instead of improvising when:

- The issue has no acceptance criteria and the intended behavior is not obvious.
- The issue is an epic and no executable child issue is selected.
- The requested change expands beyond the issue scope.
- Two agents need to write the same files in parallel.
- The work requires secrets, customer data, private runtime logs, or token dumps.
- A refactor target has no meaningful behavior coverage and the issue does not
  authorize adding coverage first.
- Required `ci` fails after three repair attempts with different root causes.
- The implementation would weaken deterministic-first, evidence, release-gate,
  model-gateway, CSP, or security-scan guarantees.

## Memory Rules

- Memory path: `.agents/memory/<agent-name>/MEMORY.md`.
- Store only durable project lessons, recurring pitfalls, false positives,
  verification commands, and architecture invariants.
- Keep entries short and dated.
- Keep each memory file below 25 KB.
- Never store secrets, customer data, raw private source dumps, full logs, or
  token-bearing command output.

## Tooling Rules

- GitHub plugin/app first for issue, PR, review, and merge workflows.
- `gh` for delivery board fields, CI logs, branch state, and cases where the
  plugin is weaker.
- Context7 for current framework/library/API documentation.
- OpenAI Developer Docs MCP for OpenAI product/API questions.
- Playwright/browser tooling for UI reproduction and browser evidence.
- Figma MCP only when the issue provides a design source or asks for design
  implementation.
- Web search only for unstable external facts; prefer primary sources.

## Quality Bar (hard rules)

Applies to every write agent. Mirrors the Claude side so both harnesses ship at
the same bar.

- TypeScript strict mode. No `any`; use `unknown` with narrowing.
- Cyclomatic complexity <= 10 per function. Function <= 50 LOC. File <= 400 LOC.
- Edge cases explicit: null, undefined, empty, zero, boundary, concurrent,
  error path.
- Error handling at system boundaries only (user input, external API,
  filesystem). No defensive try/catch in internal code.
- Tests are mutation-robust: a single-line mutation in the implementation must be
  caught by a test.
- React: stable keys, correct hook dependencies, Server Components by default.
- Next.js: Route Handlers and Server Actions have authz; no secrets in Client
  Components.
- No comments explaining WHAT — only WHY when non-obvious.
- New behavior is test-driven: write the failing test before the implementation.
- Conventional commits with issue number: `feat: ... (#123)`.

## Self-Critique (mandatory)

Every write agent runs a 2-pass adversarial self-critique before reporting done.
Skipping is forbidden.

- **Pass 1 — adversarial review.** Read your own diff as a hostile senior
  reviewer: which edge case did I skip (null, empty, boundary, concurrent,
  network fail)? Which error path is untested? Which assumption is unstated? Is
  there a simpler implementation? Did I introduce refactoring debt? Is every new
  branch covered by a test? Are types as strict as possible? Any security
  implication I did not flag? Does this break an existing public API?
- **Pass 2 — refinement.** For every weakness found, either fix it in the diff,
  add a test, or document it explicitly as a known limitation. Never silently
  leave a weakness.

## Completion Gate

A task is done only when, for each acceptance criterion, there is concrete
evidence (file:line, test name, command output, or observed behavior). "Implemented"
or "appears fixed" is not sufficient. Run `npm run verify` (the CI mirror) green
locally before opening the PR; CI is confirmation, not discovery.
