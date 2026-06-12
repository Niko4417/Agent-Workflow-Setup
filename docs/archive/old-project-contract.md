# Keiko Agent Workflow

This file is the canonical project-specific workflow contract for agent-driven work in Keiko.

It defines local policy. Reusable execution mechanics belong in a generic skill. Environment-specific entry files such as `AGENTS.md` and `CLAUDE.md` should point here rather than duplicating this file.

## Scope

This workflow is designed for Keiko first, even though the reusable orchestration skill should stay generic.

The intended outcome is:

- the human operator gives one epic or one user finding to an orchestrator
- the orchestrator plans and coordinates the work
- worktree agents execute issue-scoped implementation work
- each selected issue normally ends in its own branch and pull request
- the human operator interacts only with the orchestrator
- the human operator is interrupted only for true blockers after orchestrator-led recovery attempts

## Roles

### Human Operator

- selects one epic or one user finding
- gives that work to the orchestrator
- does not coordinate directly with worktree agents
- is contacted only for true blockers after repeated failed recovery attempts

### Orchestrator

- is the only user-facing agent
- is the planning and coordination authority
- decomposes an epic into issues when needed
- determines dependency order between issues
- decides whether work requires an `epic/...` integration branch or a direct `issue/...` branch from `dev`
- treats branch creation and PR delivery as the default completion path, not an optional follow-up
- provisions worktree execution only after dependencies are understood well enough
- activates issue work only when dependencies are satisfied
- manages chat pinning and unpinning
- informs the human operator of progress and completions
- escalates to the human operator only after repeated materially distinct failed recovery attempts

### Worktree Agent

- exists only to execute one issue
- writes code, tests, and issue-scoped documentation as needed
- does not make cross-issue planning decisions
- does not contact the human operator directly
- reports status, completion, and blockers to the orchestrator
- may open or update the issue PR into the epic branch when instructed

## Model Allocation

- Orchestrator: `Codex 5.5 medium`
- Worktree agents: `Codex 4.5 medium`

## Branching Rules

### Git Transport

For repository operations that talk to GitHub remotes:

- prefer SSH remotes and SSH authentication by default
- treat HTTPS as a fallback path only when SSH is unavailable and cannot be restored quickly
- if SSH fails, first check whether the failure is local and repairable, for example missing agent identities, missing SSH config, or an unregistered public key
- only switch an active workflow to HTTPS after confirming that SSH is not currently usable and that continuing over SSH would block progress

Do not silently normalize the repository workflow onto HTTPS when SSH can be made to work with a small local repair.

### Epic Work

Use this path when work spans multiple related issues:

- base branch: `dev`
- integration branch: `epic/<epic-name>`
- issue branches: `issue/<issue-id>-<short-name>` from the current epic branch

Issue work should start in issue-scoped worktrees/branches up front whenever the expected outcome is separate issue PRs.

Issue PRs target the epic branch. The final PR targets `dev`.

### User Findings And Single-Scope Work

Do not force an epic branch for user findings or other single-scope work.

For these cases:

- base branch: `dev`
- working branch: `issue/<issue-id>-<short-name>` or `issue/<finding-slug>`

The normal pipeline continues directly from that issue branch.

For Keiko, this is the default orchestrator mode for user findings:

- create the issue branch/worktree before substantial implementation starts
- do the implementation and verification in that issue-scoped branch context
- open a PR for that branch as the normal definition of completion

Do not prefer "implement multiple findings in one shared workspace and split them later" unless the human operator explicitly asks for that tradeoff.

### User Findings Completion Standard

User findings are often less structured than normal implementation issues, so missing checklists or vague wording do not relax the completion bar.

For user findings:

- required verification and relevant quality gates still define completion
- the absence of issue-level acceptance criteria or expected-verification checklists does not waive those gates
- agents should continue in a fix-verify-repeat loop until the relevant local checks and required CI gates are green, or until the blocker escalation threshold is reached
- "implemented" or "appears fixed" is not sufficient on its own; the normal completion condition is a PR backed by passing relevant verification evidence

When a user finding cannot reach green gates after `3 materially distinct repair attempts`, escalate it as a blocker using the repository's standard escalation policy rather than silently stopping at a partial fix.

## Dependency And Activation Rules

- The orchestrator is solely responsible for dependency tracking.
- Worktree agents should not reason about the issue graph beyond their assigned prerequisites.
- The orchestrator may provision multiple issue worktrees for visibility and preparation.
- If the intended deliverable is one PR per issue, the orchestrator should provision the issue worktree/branch before implementation rather than after local batching.
- Provisioned worktrees must not start execution while blocked by dependencies.
- Only `ready` issues may become `active`.
- When an issue becomes unblocked, the orchestrator should activate it automatically by default and then notify the human operator through the orchestrator chat.

Use these states:

- `provisioned`
- `blocked`
- `ready`
- `active`
- `done`

## Communication Contract

- The human operator talks only to the orchestrator.
- All worktree updates flow through the orchestrator.
- The orchestrator should provide regular current-work updates, similar to lightweight scrum-daily status.
- The orchestrator should notify the human operator when an issue finishes and its PR is open, unless the human operator explicitly asked for local-only completion.
- When an active worktree finishes, its chat should be unpinned and the orchestrator should report that completion.
- Blocked or provisioned worktrees should not be pinned.
- Only the orchestrator chat and the currently active worktree chat should be pinned.

## Escalation Rules

The human operator should only be interrupted for a true blocker after orchestrator-led recovery attempts have failed.

Recovery policy:

- A worktree blocker must escalate first to the orchestrator.
- The orchestrator must try to resolve the issue internally before contacting the human operator.
- The orchestrator may instruct the worktree to retry, self-correct, gather more evidence, take a narrower path, or re-scope once.
- A blocker becomes user-visible only after `3 materially distinct recovery attempts` on the same issue have failed.
- If the orchestrator re-scopes or splits the issue and the issue is still blocked, that still counts toward the recovery threshold rather than resetting it.

When escalating, the orchestrator should summarize:

- what was attempted
- why each attempt failed
- why further autonomous recovery is unlikely to succeed

## Workflow Status

Durable workflow status should live in GitHub issues, pull requests, and their linked review artifacts.

Use chat only for transient reasoning and short-lived coordination.

When status matters, the orchestrator should keep these current in GitHub:

- selected issue or epic
- dependency notes when relevant
- active branch and pull request
- blocker status
- completion or handoff state

## Notification Expectations

The orchestrator should notify the human operator when:

- work begins
- an issue becomes active
- meaningful current-work progress should be surfaced
- an issue completes, its worktree chat is unpinned, and its PR is ready
- the epic or user-finding workflow completes
- a true blocker has survived `3 materially distinct recovery attempts`

## PR-First Delivery

For this repository, orchestrator execution is PR-first by default.

That means:

- one selected issue should map to one issue-scoped branch/worktree
- one issue-scoped branch/worktree should normally map to one pull request
- opening the PR is the normal completion condition for an issue

Sub-agents remain useful, but only as execution accelerators inside that delivery structure.

Use sub-agents for:

- repo analysis before issue execution starts
- bounded implementation, diagnosis, or test-writing work inside one issue's branch/worktree
- parallel help that does not replace the branch-per-issue delivery model

Do not use sub-agents as the sole isolation mechanism when the expected outcome is a separate PR per issue.

The orchestrator should not notify the human operator for routine implementation friction that can be resolved below the orchestration layer.

## Orchestrator Intake

When the human operator explicitly asks an agent to act as the orchestrator for this repository, the orchestrator should immediately enter intake mode.

Default intake behavior:

- inspect the remote GitHub repository issue tracker first
- identify candidate epics, user findings, or issue groups when discoverable
- present the candidate work clearly
- allow the human operator to choose one candidate
- also allow the human operator to bypass the list and provide one explicit epic or one explicit issue or user finding directly

Remote issue discovery is the default source of truth for candidate work in Keiko. Local repository files and docs are secondary signals and should only be used to supplement the remote issue tracker, not replace it, unless the human operator explicitly asks for local-only discovery.

If remote repository candidates cannot be discovered reliably, the orchestrator should ask for one explicit epic or one explicit issue or user finding rather than stalling.

The orchestrator should not wait for extra prompting to enter this intake flow once it has been explicitly asked to act as the orchestrator.

## Environment Adapters

- `AGENTS.md` should be the Codex-facing adapter
- `CLAUDE.md` should be the Claude-facing adapter

These files should remain thin and should point back to this file instead of re-stating the full workflow.
