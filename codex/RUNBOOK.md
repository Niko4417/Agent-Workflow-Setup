# Codex Agent Team Runbook

This runbook defines how to use the project-scoped Codex agent team for Keiko.
The GitHub issue is always the source of truth for scope, acceptance criteria,
dependencies, and definition of done.

## Workflow Skills (how to execute selected work)

When the operator selects work, invoke the matching skill from `~/.codex/skills/`
rather than improvising the procedure:

- `keiko-grill-epic` — turn a rough idea into a ready epic + child issues (upstream of `keiko-epic`).
- `keiko-epic <N>` — drive a multi-issue epic end-to-end.
- `keiko-issue <N>` — drive a single issue / task / bug / finding.
- `keiko-issue-audit <N>` — mandatory pre-PR-ready audit (also on-demand).
- `keiko-retro <epic>` — post-merge: distill process learnings + lint/reconcile memory.

The skills carry the executable procedure; this runbook and the contract carry
the always-on rules they follow. The sections below are the rules.

## Intake, lifecycle, and delivery

Select [one product profile](../profiles/README.md) before product work and load
its target-owned authority docs. Web readiness is acceptance + verification;
Native readiness is current machine-validated contract and execution authority.
A board field or lingering ready label cannot grant Native readiness. Check the
assignee before claiming; do not take another operator's work.

Use `keiko-issue` / `keiko-epic` for claim, source branch, dependency ordering,
implementation, verification, audit evidence, UI journeys, and closure. Preserve
Native's frozen target and automation identity; web board/Playwright examples are
not Native policy. Every issue gets a PR. Child→epic execution stays AFK after
exact-head evidence; missing proof requires repair or escalation. Delivery follows
the target's authority, full current-head required-check matrix, settled reviews,
and explicit run review holds. Hand off at `Ready for Human Review` when a hold
applies; close only after merge and the target's completion predicates hold.
A request for autonomous execution until the final green epic PR already chooses
that final hold: children continue autonomously, while the final PR must not merge
or have auto-merge armed until the human explicitly authorizes it. Do not re-ask
that choice or insert routine per-child approval rounds. Record the choice in the
existing epic issue milestone comment and final PR, read it on resume, and retain
it after every final push. Keep auto-merge unarmed on the held final PR.

Post one-line heartbeats at wave/milestones and flush current state + next action
to the issue/PR. GitHub is the durable delivery record. Record only reusable memory
lessons; read-only workers return candidates. Read the [workflow contract](../docs/workflow-contract.md)
for detailed gate scope and recovery budgets, not a duplicated lifecycle here.

## Agent Routing by Issue Signal

Route on the repo's actual label taxonomy (`gh label list`). Type labels use a
space (`type: task`); area labels do not (`area:model-gateway`).

**Execution shape:** the lead may handle small, clearly scoped work directly.
Delegate for useful independent execution, specialist judgment or safe parallelism.
Every delivery still needs an independent issue audit; an implementation author
cannot supply that independence through self-review. One qualified reviewer may
cover a small change without a fixed explorer/implementor/test/verifier roster.
Target-required role separation and accepted Quality Plans still apply. An accepted
spec does not need another routine plan approval.

**By type:**

- `type: epic`: compose `keiko-issue` for each executable child; use `architect`
  when material architecture decisions need it. Do not implement unaccepted scope.
- `type: task` or `type: feature`: choose direct lead execution or bounded writers
  based on the change. Add exploration and specialist testing when needed.

**By area** (risk-based role suggestions, not an automatic roster):

Choose the relevant expertise below when material to the change or required by the
target. Apply the selected profile’s UI/verification contracts; a label does not
require all listed agents.

- `area:user-interface`: `ui-engineer` for substantial UI implementation;
  `a11y-auditor` for required independent accessibility/fidelity review;
  `performance-engineer` for material performance risk. Web uses its design system
  and target-required evidence; Native uses its design baseline and Acceptance Journey.
- `area:tooling-security`: consider `security-triage` first-pass, escalating to
  `security-auditor` for tool-execution / patch-safety / command-boundary changes.
- `area:model-gateway`: consider `architect` and `security-auditor` (provider
  abstraction, routing, capability metadata, model access boundaries).
- `area:agent-runtime`: consider `architect` and `security-auditor` (agent loop, task
  state, runtime limits, orchestration).
- `area:repository-context`: consider `explorer` and `security-auditor` (workspace
  discovery, safe file access, context selection).
- `area:platform-foundation`: consider `architect` and `refactor-specialist` (project
  foundation, package structure, repo hygiene).
- `area:bug-investigation`: reproduction and bounded investigation first; consider
  `explorer` or `browser-debugger` when needed, then a scoped repair and independent audit.
- `area:unit-tests`: consider `test-engineer` (generation workflow, regression coverage).
- `area:verification`: consider `verifier` and `test-engineer` (tests, type/build
  checks, verification evidence).
- `area:audit-evidence`: consider `security-auditor` and `verifier` (run ledger,
  evidence manifests, redaction, compliance traceability).
- `area:evaluation`: consider `performance-engineer` and `test-engineer` (eval
  harnesses, benchmark fixtures, model-performance measurement).
- `area:test-intelligence`: consider `architect`, `test-engineer`, and
  `security-auditor` (native quality intelligence, test gen/validation/review, TMS).
- `area:packaging-docs`: consider `docs` and `architect` (npm packaging, documentation,
  customer runbooks).

## Model and reasoning-effort routing

The standing model and effort are defined in `.agents/roles.yaml` and implemented
in `.codex/agents/*.toml`. The lead defaults to GPT-6.1 Sol / high; read the
[model-routing policy](../docs/model-routing.md) before escalating.

- Bounded lookup, mechanical scans, and straightforward docs may use Luna.
- Ambiguous exploration, auth/permissions, migrations, concurrency, and architectural
  judgment require Sol or the relevant specialist before implementation proceeds.
- Diagnose missing context or an oversized task before retrying. Raise effort or
  model only for a specific unresolved difficulty; do not repeat an unchanged prompt.
- For a specific unresolved problem, raise Sol 6.1 from high to xhigh after
  correcting context and task scope. Astra / high is manual-only: the operator
  must explicitly request it. Failure or consequential uncertainty does not
  authorize switching to Astra. Measured benefit may justify recommending it,
  but not spawning it without that request.
- Keep named-role spawns independent, with exact `agent_type` and no model/effort
  override for a baseline run. An explicit escalation is the exception.
- Check runtime records for actual model, effort, role, and sandbox. Record the
  escalation reason, elapsed time, retries, and verification outcome without secrets.
- If a tool schema omits `agent_type`, report that named-role inheritance cannot be
  verified through that interface. A model-only probe does not prove role inheritance.

Run `python scripts/check-routing.py` before changing or publishing routing.

## Job-timeout recovery (lead-driven)

`[agents] job_max_runtime_seconds` (1800s) kills an over-running agent job and
returns it **empty-handed — no partial results**. On a job timeout, do **not**
blindly re-dispatch the same task (it will just time out again). Instead
**narrow the scope** — split the work, cut the read/write surface, or hand off a
smaller slice — and re-dispatch that. This counts against the 3-distinct-repair
bound; after 3 attempts, stop and report rather than narrowing indefinitely.

## Verification Routing

- Always required before merge: the target's full current-head required-check
  matrix and settled review findings.
- Always required before `Ready for Human Review`: `keiko-issue-audit`.
- Studio UI or BFF browser behavior: Studio browser quality gate.
- Monaco/editor performance, rendering, large-file behavior: Studio perf/memory.
- Visible UI structure: Studio visual regression.
- User-facing component change: Keiko Design System fidelity gate — token
  conformance + `state-matrix.md` coverage verified against `docs/design-system/`,
  with evidence captured under `docs/design-system/evidence/<N>/` (ADR-0049/0051).
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
- Read-only roles do not write memory: they return a concise memory candidate to
  the lead, who records durable ones from a write-enabled context.

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

## Quality and self-review

Use the shared [AGENTS contract](../AGENTS.md#quality-and-completion) and the target's
accepted Quality Plan. Apply stack-specific checks only to that stack. UI evidence
comes from the selected profile (web design system or Native Acceptance Journey).
Every agent performs the two-pass self-review; role definitions add domain checks.

## Completion Gate

A task is done only when, for each acceptance criterion, there is concrete
evidence (file:line, test name, command output, or observed behavior). "Implemented"
or "appears fixed" is not sufficient. Run applicable target local checks and independent audit before opening the PR;
`verify.sh` is an optional convenient runner. Record actual command/audit/UI
results with the exact current PR head in the PR body or comment. Full target
required CI and settled reviews remain mandatory before authorized merge.
