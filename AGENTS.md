# Agent Operating Rules

## Product context (profile-selected)

This repository is development infrastructure, not a product. Product context —
what the product is, its domain language, and its boundaries — belongs to the
**target repository** and is read from its own `AGENTS.md` and `CONTEXT.md` under
the active **product profile** ([`profiles/`](profiles/README.md)); it is not
restated here. Select the profile first (skill Step 0) and load only that one.
See [`docs/target-repository-boundary.md`](docs/target-repository-boundary.md) for
the ownership split.

## Templates

- Issue and pull-request templates are **owned by the target repository**, not this workflow repo. Use the target's
  current templates under the active profile ([`profiles/`](profiles/README.md)): its
  `.github/ISSUE_TEMPLATE/*` and `.github/pull_request_template.md` (keiko-web: `epic` / `feature_task`;
  keiko-native: the typed `epic` / `feature_task` / `decision_evaluation` / `defect_finding`).
- Do not create free-form issues or pull requests by copying older examples unless the result is checked against the
  target's current template.
- Keep acceptance criteria, expected verification, review settlement, and closure evidence formally updated in GitHub.

## Delivery standard

- Keep implementations simple, maintainable, and focused on the issue scope.
- Be creative and innovative where it improves product quality, but avoid unnecessary special cases, speculative
  abstractions, and process overhead.
- Preserve existing architecture boundaries, quality gates, security posture, evidence semantics, and deterministic
  verification.

## Language and artifacts

- Write code comments, configuration, documentation, issues, pull requests, and GitHub comments in professional English.
- Do not commit local runtime state, secrets, customer data, private logs, generated caches, or tool-specific memory.

## Delivery gates

- **Definition-of-Ready**: do not start an issue without acceptance criteria and a verification command. Triage first if
  either is missing.
- **Target-owned delivery authority**: every issue ships as a pull request. Follow the target's current
  `AGENTS.md`, ADRs, and explicit user choices for merge authority. Default to final human review only when
  neither authorizes another path; preserve an explicit run-specific final epic review hold.
- Treat `dev` as the integration target for the web profile and require the target's complete current-head
  required-check matrix and settled review findings before merge.
- Never mark work complete without evidence (`file:line`, command output).

## Quality and completion

Use the active profile and target's accepted Quality Plan as the authority. For
TypeScript code, use strict types and `unknown` with narrowing, never `any`.
Numerical limits, coverage floors and styling rules come from the target's current
contract and configured gates; do not add workflow-only thresholds. Keiko allows
complexity 10 and functions of 50 counted lines. Handle relevant boundary, error
and concurrency cases.
Keep error handling at system boundaries and comments focused on non-obvious reasons.
Use failing behavioral tests for new behavior and bug regressions; assert public
contracts with independent expectations rather than copying implementation logic.
Apply React/Next.js guidance only where that stack exists; UI evidence comes from
the selected profile, not an assumed browser harness or design system.

Before reporting done, every agent performs two passes: challenge its result for
defects, omissions, and false positives; then fix confirmed gaps or report explicit
limitations. Role definitions add domain-specific checks. Evidence must describe
the inspected commit and actual commands/results, including unavailable checks.

## Orchestration

- The lead session is the **sole orchestrator**. Never spawn a sub-coordinator.
- Use the smallest effective execution shape. Stay single-agent for tiny questions, narrow one-file edits, or when the
  user explicitly asks to avoid delegation. Use a team when independent execution or review materially improves
  quality, with the profile's required audit and evidence steps preserved.
- Start a delegated run with a short coordination plan assigning ownership, file scopes, dependencies, and stop
  conditions.
- Prefer read-heavy fan-out first (`explorer`, `architect`, `security-auditor`, `performance-engineer`). Use write
  agents only on disjoint file scopes (`implementor`, `developer`). Use `test-engineer` for coverage and regression
  harnesses, `pr-shepherd` for CI/review follow-up once a PR exists. Finish write waves with `verifier`, `pr-reviewer`,
  or `security-auditor` depending on risk.
- Keep delegation shallow and predictable. Do not recurse unless explicitly asked.
- Return distilled outcomes from subagents, not raw transcripts.
- **Heartbeat**: post a one-line status at each wave or milestone, and flush "current state + next action" to the
  issue/PR so either harness can resume.

## Escalate — stop rather than improvise

Stop and surface to the human when the issue is ambiguous, acceptance criteria are missing, scope expands beyond the
issue, file ownership overlaps, secrets would be required, or CI has failed after three distinct repair attempts.

## Memory

Before substantial work, read the relevant role memory under `.agents/memory/<role>/MEMORY.md`. After it, capture only
durable, generalizable lessons (recurring pitfalls, architecture invariants, reliable verification commands, confirmed
false positives) — never task status, one-off findings, secrets, customer data, token-bearing logs, or raw private
source. Write nothing when no reusable lesson was learned; keep each file under 25 KB.

**Read-only roles do not write memory.** A read-only agent (its sandbox forbids writes) returns a concise **memory
candidate** to the lead instead of appending; the lead decides whether it is durable and records it from a write-enabled
context. Only write-enabled roles (or the lead) touch `MEMORY.md`.

## Research and tooling

- Use live web search or MCP for unstable facts: external APIs, model details, framework changes, pricing, policies, and
  recommendations that age. Prefer official documentation and primary sources, and include concrete dates or versions
  when freshness matters.
- Use the repository tool surface deliberately: the GitHub plugin or `gh` for GitHub state, Context7 for library docs,
  OpenAI Developer Docs for OpenAI/Codex product and API questions, Playwright/browser tooling for UI verification, and
  Figma MCP only when a design URL or design task exists.

## Codex-specific

- Operating manual: `.codex/RUNBOOK.md`. Use `.codex/playbooks/feature.md`, `audit.md`, `refactor.md`, and
  `ci-repair.md` when the task matches those workflows.
- Agent model tiers live in `.codex/agents/*.toml`; the canonical role map is `.agents/roles.yaml`. Right-size the model
  per role — do not promote an agent to the frontier tier without reason.
- **Cost-aware Codex escalation**: use Luna for bounded work, then Sol 6.1 at medium/high as the task requires.
  For a specific unresolved problem, raise Sol 6.1 to `xhigh` after correcting context and task scope. Never select
  Astra automatically, including after a failed attempt or for a high-risk role. Use it only when the operator
  explicitly requests it. A measured task-specific benefit may justify recommending Astra; it does not authorize
  spawning it. No standing role uses Astra.
- **Spawn contract** — for every custom child:
  1. Pass the exact `agent_type` from `.codex/agents/*.toml`. **Never** omit it to make a rejected spawn call pass —
     that silently inherits the lead's model and sandbox, defeating the per-agent tiers and read-only postures.
  2. Omit `model` / `reasoning_effort` / `service_tier` so the role definition wins; set them only for a justified
     one-off escalation.
  3. Do **not** use a full-history fork with a named role (`fork_turns = "all"`) — it forces the child to inherit the
     parent's agent type, model, reasoning effort, and growing context. Use `fork_turns = "none"` for independent work;
     if Codex rejects the call, drop `fork_turns`, never `agent_type`.
  4. Give the child a bounded goal, owned files or read surface, expected evidence, a stop condition, and the required
     return format.
  5. Verify the child's actual model, effort, role, and sandbox before relying on its posture. Some runtimes apply role
     model/effort but inherit the parent's sandbox. If a read-only role records broader access, run it from a read-only
     parent or stop that delegation; a role instruction alone does not enforce filesystem permissions. See
     [`docs/model-routing.md`](docs/model-routing.md) for tested scope and limitations.
