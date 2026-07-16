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

- Build production-ready, state-of-the-art solutions.
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
- **`dev` is sacred**: every issue ships as a pull request. The only auto-merge is `issue -> epic-branch` on green CI.
  Every merge into `dev` — epic or standalone — needs a human reviewer and green CI.
- Treat `dev` as the integration target and require a green `ci` check before merge.
- Never mark work complete without evidence (`file:line`, command output).

## Orchestration

- The lead session is the **sole orchestrator**. Never spawn a sub-coordinator.
- Use the smallest effective execution shape. Stay single-agent for tiny questions, narrow one-file edits, or when the
  user explicitly asks to avoid delegation. Use the agent team for GitHub issues, PR-ready implementation, refactoring
  sprints, audits, CI repair, release gates, or any task where parallel review materially improves quality.
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
