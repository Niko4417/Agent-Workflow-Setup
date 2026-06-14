# Agent Team Task Prompt

Use this template for implementation work that should be handled by the
project-scoped Codex agent team.

Replace `<ISSUE_NUMBER>` before use. Do not paste the issue body into this
prompt. The GitHub issue is the source of truth for scope, acceptance criteria,
dependencies, and definition of done.

## Task

Resolve GitHub Issue `<ISSUE_NUMBER>` end-to-end from the current state of
`origin/dev`.

Default delivery mode:
- Every issue ships as a PR.
- Any PR targeting `dev` requires a human reviewer.
- Before an issue is considered PR-ready, run `keiko-issue-audit`.

You are the coordinator for the project-scoped Codex team defined in
`.codex/agents/`, `.agents/memory/`, and `.codex/config.toml`.

## Source of Truth

1. Fetch GitHub Issue `<ISSUE_NUMBER>` before planning.
2. Treat the issue title, body, labels, linked PRs, linked child issues, and
   comments as the authoritative task definition.
3. If the issue has explicit acceptance criteria, implement exactly those.
4. If the issue is an epic, do not implement the whole epic unless the prompt or
   issue explicitly says to do so; identify the child issue that should be
   executed.
5. If the issue is ambiguous, blocked, missing critical acceptance criteria, or
   conflicts with repository governance, stop and report the blocker. Do not
   invent product scope.

## Operating Model

1. Load coordinator memory from `.agents/memory/coordinator/MEMORY.md`.
2. Inspect current repository state, existing PRs for the issue, and current
   quality-gate status.
3. Claim the issue in the public `Keiko Product Delivery` project before
   implementation starts:
   - add the issue to the project if it is missing;
   - replace any stale `status:*` label with `status: in progress`;
   - set project `Workflow State` to `In Progress`;
   - set `Status` to `In Progress`;
   - set `Owner / Agent` to the active agent or coordinator name;
   - set `Human Review Required` to `Yes` for any PR that will target `dev`.
4. Build the smallest effective agent team:
   - `explorer` for code-path and test-surface discovery.
   - `architect` for durable design or cross-service tradeoffs.
   - `implementor` or `developer` for disjoint write scopes.
   - `test-engineer` for regression coverage and meaningful test design.
   - `docs` when docs are required by the issue.
   - `security-auditor`, `performance-engineer`, or `a11y-auditor` when the
     changed surface creates that risk.
   - `verifier` or `pr-reviewer` before delivery.
5. Assign explicit file ownership before any write agents start.
6. Keep write scopes disjoint. Do not let parallel agents edit the same files.
7. Integrate subagent work in the coordinator thread and resolve conflicts
   deliberately.
8. Update role memory only with durable project lessons. Never store secrets,
   customer data, private source dumps, or token-bearing logs.

## Quality Bar

- Preserve Keiko's deterministic-first architecture.
- Keep productive model calls behind the Model Gateway.
- Keep the Orchestrator as the workflow authority.
- Keep changes scoped to GitHub Issue `<ISSUE_NUMBER>`.
- No TODOs, placeholders, commented-out fallback code, or partial implementations.
- No unrelated refactors.
- No quality-gate weakening.
- Required GitHub check `ci` must pass before merge.
- Additional Studio/browser/security/release gates must pass when relevant to
  the changed surface.

## Tools and Grounding

1. Prefer the GitHub plugin/app for issue, PR, review, and merge workflows.
2. Use `gh` where CI logs, branch state, or review-thread details require it.
3. Use Context7 for current framework/library/API documentation.
4. Use OpenAI Developer Docs MCP for OpenAI product/API questions.
5. Use Playwright/browser tooling for UI reproduction or browser evidence.
6. Use Figma MCP only when the issue provides a Figma/design source or asks for
   design implementation.
7. Use web search only for unstable external facts and prefer primary sources.

## Delivery Workflow

1. Make only issue-scoped changes.
2. Commit with a Conventional Commit message that references
   `#<ISSUE_NUMBER>`.
3. Branch from `origin/dev` using
   `codex/issue-<ISSUE_NUMBER>-<short-description>`, push the branch, and open
   or update a PR targeting `dev`.
4. Fill the project `Branch` field when a branch is used.
5. Fill the project `Pull Request` field and set `Workflow State` to `PR Open`
   when a PR is used.
6. Run `keiko-issue-audit` before the issue is considered PR-ready /
   `Ready for Human Review`. The audit may confirm zero findings, but the pass
   is mandatory.
7. Include `Resolves #<ISSUE_NUMBER>` in the PR body when the issue should close
   on merge.
8. Diagnose and repair CI failures with bounded attempts. Stop after three
   failed CI repair attempts and report the blocker.
9. When implementation, `keiko-issue-audit`, and required checks are ready for
   maintainer review, set
   `Workflow State` to `Ready for Human Review` and replace the issue status
   label with `status: ready for human review`.
10. Do not merge a PR into `dev`, enable auto-merge, close the issue, or
    mark the item `Done` unless the human maintainer explicitly authorizes that
    action in the active task.

## Safety

- Never print, persist, or restate secrets.
- Never commit tokens, `.env` contents, customer data, or local runtime logs.
- Do not revert unrelated user or agent changes.
- Do not use destructive git commands.
- Do not amend or rewrite history unless explicitly requested.

## Final Delivery Contract

Return:

- Issue resolved
- Team used and why
- Files changed
- Tests/checks run
- `keiko-issue-audit` status
- GitHub PR and `ci` status
- Delivery board status, owner, branch, and PR fields when applicable
- Any additional relevant gate status
- Residual risks or follow-ups
