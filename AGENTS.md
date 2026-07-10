# Agent Operating Rules

## Keiko Product Context

Keiko is a standalone enterprise developer-assist coding agent for regulated banking and insurance engineering
workflows. It is not a demo, proof of concept, or internal prototype. The product helps developers work safely in
existing repositories by inspecting bounded context, generating reviewable unit tests, investigating bugs, proposing
small patches, running verification, and producing traceable evidence for human review.

The system is designed to start as a TypeScript/npm-delivered coding-agent foundation and remain model-agnostic so
customer-provided models can be upgraded without rebuilding the product architecture. All generated output must remain
explainable, evidence-backed, developer-controlled, and suitable for regulated delivery environments.

## Templates

- Use the current GitHub issue templates in `.github/ISSUE_TEMPLATE/` when creating or updating issues.
- Use the current pull request template in `.github/pull_request_template.md` when opening or updating pull requests.
- Do not create free-form issues or pull requests by copying older examples unless the result is checked against the
  current template.
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

Before and after substantial work, read and update role memory under `.agents/memory/<role>/MEMORY.md`. Never store
secrets, customer data, logs containing tokens, or raw private source in memory.

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
- **Spawning a custom agent**: pass `agent_type` (plus `model` / `reasoning_effort` only when overriding the agent's own
  definition) and do **not** use a full-history fork (`fork_turns = "all"`). A full-history fork forces the subagent to
  inherit the parent's agent type, model, and reasoning effort. If Codex rejects the call, drop `fork_turns` — never
  drop `agent_type`, or the subagent silently inherits the lead's model and sandbox, defeating the per-agent tiers and
  read-only postures.
