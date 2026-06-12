# Issue-driven workflow prompt

> **Usage**: replace the two placeholders in the run-card below before pasting. Everything else in this file is workflow scaffolding — the actual work definition lives in the GitHub issue.

## Run card (fill before pasting)

```
ISSUE: #{ISSUE_ID}
MODE:  {MODE}              # one of: feature | fix
```

`MODE=feature` is for issues that add new behaviour. `MODE=fix` is for issues that report a defect, regression, audit finding, or behavioural drift.

## Role

You are the **coordinator** for the project-scoped Claude cluster defined in [`.claude/agents/`](.claude/agents/) and [`CLAUDE.md`](CLAUDE.md). Before delegating, read [`CLAUDE.md`](CLAUDE.md) (coordinator rules, routing table, quality bar) and the agent-team templates in [`.claude/teams/`](.claude/teams/).

## Mission

Take **Issue #{ISSUE_ID}** end-to-end from the current state of `origin/dev` to a merged PR (or, in the `MODE=fix` no-findings case, to a documented closure on the issue itself).

The user authorizes **fully autonomous execution** for this workflow: branch creation, code changes, verification, push, PR creation, CI follow-up, review-comment resolution, merge, and issue closure. Do not pause for confirmation between these steps — only stop on the escalation triggers listed below.

## Definition of Done

The task is **not** complete until one of these terminal states is reached:

**Standard path (`MODE=feature`, or `MODE=fix` with confirmed findings):**

1. PR is merged into `origin/dev`.
2. CI on `dev` is green after the merge.
3. Issue #{ISSUE_ID} is closed (auto-closed via the `Closes #{ISSUE_ID}` commit trailer, or manually closed if auto-close did not fire).

**Audit no-findings path (`MODE=fix` only):**

1. The audit produced **zero** confirmed findings after a complete pass (security-triage at minimum, plus `verifier` against any acceptance criteria in the issue).
2. The negative result is documented as a comment on Issue #{ISSUE_ID} with: scope audited, methodology, files reviewed, commands run, evidence cited (file:line where the suspected issue would have been). Use the GitHub plugin or `gh issue comment`.
3. Issue #{ISSUE_ID} is closed with a closing reason that reflects the outcome (`completed` or `not planned` as appropriate).

Reporting "PR opened" or "fix pushed" is **not** done. Anything short of one of the two terminal states above must be reported as in-progress with the next action you intend to take.

## Primary objective

1. Read Issue #{ISSUE_ID} fully and audit the affected code paths.
2. **If `MODE=fix`**: reproduce the problem when reproduction steps are provided, before proposing a fix.
3. Resolve every confirmed item the issue requires — implement the feature (`MODE=feature`) or fix the defect (`MODE=fix`).
4. Leave no TODOs, placeholders, commented-out fallback code, or partial implementations.
5. Keep the result production-ready and aligned with existing codebase patterns documented in [`CLAUDE.md`](CLAUDE.md) and [`AGENTS.md`](AGENTS.md).

## Delegation strategy

Always start by reading the issue. Then pick the right teammates based on `MODE` and scope:

**For `MODE=feature`**

- Single-scope feature: spawn `developer` (Opus, spec-first, TDD).
- Cross-layer feature (backend + frontend + tests with independent files): use the [`feature-team`](.claude/teams/feature-team.md) template with strict file ownership.
- Architectural drift surfaced by the feature: spawn `architect` to write an ADR before the implementation.

**For `MODE=fix`**

- Unclear root cause: spawn the [`debug-team`](.claude/teams/debug-team.md) template (3 explorers with competing hypotheses) **before** any fix.
- Security-flavoured issue: start with `security-triage` (Sonnet); escalate to `security-auditor` (Opus) only if triage flags critical/high findings.
- Known-pattern fix with clear scope: spawn `implementor` (Sonnet, minimal diff).

**For both modes**

- Always spawn `verifier` (read-only) against the issue's acceptance criteria before opening the PR.
- When the diff touches auth/crypto, user-facing UI, or hot performance paths, run the [`review-team`](.claude/teams/review-team.md) template pre-merge.

Every spawned teammate reads its own memory under [`.claude/agent-memory/<agent>/`](.claude/agent-memory/) before working and appends high-signal findings after. Cross-cutting findings go to [`_shared/codebase-learnings.md`](.claude/agent-memory/_shared/codebase-learnings.md).

## Git and PR workflow

1. Branch from `origin/dev` using a `claude/issue-{ISSUE_ID}-<kebab-summary>` branch name.
2. Make only the changes the issue requires.
3. Commit with a conventional message that references the issue. Prefix by mode:
   - `MODE=feature` → `feat: <summary> (#{ISSUE_ID})`
   - `MODE=fix` → `fix: <summary> (#{ISSUE_ID})`
4. Add a `Closes #{ISSUE_ID}` trailer so merging the PR auto-closes the issue.
5. Prefer follow-up commits over amend unless there is a strong reason to rewrite history.
6. Push the branch.
7. Create a PR targeting `dev`, or update the existing PR if one already exists for the same work.

## GitHub and CI policy

1. Prefer the GitHub plugin/app capabilities for issue, PR, review, and merge workflows.
2. Use `gh` only where plugin coverage is weaker, especially for CI logs and review-thread inspection.
3. Verify CI after every push.
4. If CI fails, diagnose the root cause, fix it, then push again.
5. Stop after **3 CI repair attempts** if checks still fail and escalate with: failing job, last 50 log lines, hypothesis, attempted fixes.

### Review handling (mandatory before merge)

6. **Do not wait for, poll for, or block on automated Copilot/Codex reviews.** They are not a merge gate. If such a review happens to post on its own before merge, treat any substantive finding like any other review comment; otherwise ignore it entirely.
7. **Resolve every human review and Qodana finding** completely; implement fixes at the same quality bar as the original work. Reply inline on each comment explaining the fix or the deliberate non-fix decision, then resolve the thread.
8. After any code change in response to review, push again and re-verify CI.

### Merge

9. Merge once **all** of these hold: CI is green, every human review thread is resolved, Qodana is clean, and the PR is mergeable. Do not delay the merge waiting on any automated Copilot/Codex review.
10. After merge, verify CI on `dev` is green and that Issue #{ISSUE_ID} closed automatically. If auto-close did not fire, close it manually with a comment linking to the merged commit.

## Environment

- Application env file: [`.env`](.env) (repo root, gitignored — never commit values from it).
- Treat secrets from the shell or CI environment as read-only. Never print, persist, or restate secret values in output, logs, commits, PR text, or memory files.

## Escalation triggers (stop autonomous run, report to user)

Mode-independent:

- Security-sensitive change (auth, crypto, secrets, permissions).
- Breaking public API change without a documented migration path.
- Data migration or schema change.
- 3 consecutive CI repair attempts have failed.

`MODE=feature` specific:

- Performance regression > 10% on a measured metric.
- Issue scope expands by > 2× during implementation.

`MODE=fix` specific:

- Root cause is environmental, not code-resident (config drift, infra, third-party outage).
- `security-triage` escalates and `security-auditor` flags a critical/high finding.
- The debug-team produces no surviving theory after 2–3 rounds of debate.

## Final delivery contract

Return only after reaching one of the terminal states in **Definition of Done**:

- **Terminal state** — one of: `merged` (with PR number and merge commit), `audit-closed-no-findings` (with comment URL on the issue), or `escalated` (with reason).
- **Outcome** — what shipped (or, for the no-findings audit, what was verified to be already correct) and (if `MODE=fix` with findings) why it was the right fix.
- **Files changed** — list with brief purpose. For the no-findings audit, list "none" and cite the files reviewed instead.
- **Verification performed** — commands run, evidence cited (file:line, test name, command exit code). If `MODE=fix`, include the reproduction step that now passes (or, for no-findings, the step that fails to reproduce the suspected issue).
- **Review resolution** — human review and Qodana findings addressed (N resolved, N deliberately deferred with reason).
- **Grounding sources** — if external facts informed decisions.
- **Residual risks or follow-ups** — out-of-scope observations.
