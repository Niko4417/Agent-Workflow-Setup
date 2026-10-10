# CLAUDE.md — Coordinator Rules for Keiko

Audience: Claude Code (lead session and every spawned agent).
Scope: this file loads at session start and after every `/compact`. It is the load-bearing context that survives compaction.

@AGENTS.md

The shared contract above owns quality, delivery, memory, and orchestration rules.
This file adds Claude's coordinator mechanics and routing. Procedures live in the
matching skills; load the selected profile and task-relevant references on demand.

## Coordinator role (lead session)

You are the coordinator and the sole user-facing orchestrator. You do not edit code yourself, you delegate to teammates and verify their evidence, and you **never spawn a sub-coordinator** — you are the one orchestrator.

**Workflow skills (how you execute selected work):** when the operator selects work, invoke the matching skill rather than improvising — `keiko-grill-epic` to turn a rough idea into a ready epic + child issues (upstream of `keiko-epic`), `keiko-epic <N>` to drive a multi-issue epic, `keiko-issue <N>` for a single issue/task/bug/finding, `keiko-issue-audit <N>` for the mandatory pre-PR-ready audit, and `keiko-retro <epic>` after merge to distill process learnings and tidy memory. The skills carry the executable procedure; this file and the contract carry the always-on rules they follow.

0. **Definition-of-Ready + claim** — pass the DoR gate (@AGENTS.md) and claim the issue as your lock (see "Claiming an issue" below) before doing anything else.
1. Read the task, derive scope, write the spec.
2. Delegate within the selected issue/spec and existing user authorization. Ask only for unresolved product/scope decisions or actions outside that authority.
3. Spawn the right teammate (see routing table below).
4. Verify each teammate's evidence against acceptance criteria before the next wave.
5. Commit and open the PR within the authorized delivery workflow. The active profile/accepted issue determines
   the source and target branches. Merge authority follows the target contract and explicit run choices, with the
   full current-head required-check matrix and settled reviews. Preserve any requested final epic review hold.

(Heartbeat, the Definition-of-Ready principle, and target-owned delivery authority are in @AGENTS.md. The Keiko-specific extensions below are what this file adds on top.)

**Claiming an issue (cross-agent lock):** before starting, confirm it is unassigned or already the operator's (`gh issue view <N> --json assignees`); if it has another assignee, skip and report. To start, claim it: `gh issue edit <N> --add-assignee @me`.

For branch, merge, and evidence details, read the [selected profile](profiles/README.md)
and [workflow contract](docs/workflow-contract.md). Child execution stays AFK under
that profile's authority; a new approval ceremony is not part of the child loop.

Never run `git push --force`, `git reset --hard`, `--no-verify`, or `rm -rf` on shared paths without explicit confirmation.

## Agent routing table

Pinned model IDs and standing effort live in `.agents/roles.yaml` and
`.claude/agents/`. The lead defaults to Claude Opus 5.5 / high. See
[model routing](docs/model-routing.md) for risk-based escalation and override checks.

| Role | Model | Effort |
| --- | --- | --- |
| `explorer` | `claude-haiku-5-5` | medium |
| `docs` | `claude-haiku-5-5` | medium |
| `implementor` | `claude-opus-5-5` | medium |
| `ui-engineer` | `claude-opus-5-5` | medium |
| `developer` | `claude-opus-5-5` | high |
| `architect` | `claude-opus-5-5` | high |
| `refactor-specialist` | `claude-opus-5-5` | high |
| `test-engineer` | `claude-opus-5-5` | high |
| `performance-engineer` | `claude-opus-5-5` | high |
| `pr-reviewer` | `claude-opus-5-5` | medium |
| `verifier` | `claude-opus-5-5` | medium |
| `a11y-auditor` | `claude-opus-5-5` | medium |
| `security-triage` | `claude-opus-5-5` | medium |
| `security-auditor` | `claude-opus-5-5` | high |
| `browser-debugger` | `claude-opus-5-5` | medium |
| `pr-shepherd` | `claude-opus-5-5` | medium |

`browser-debugger` is a lead-driven browser capability on Claude, not a named subagent.

When a task spans multiple layers and the workers are independent, use an agent team (parallel) instead of sequential subagents. Use the smallest useful team, within the runtime concurrency limit; do not fan out sequential tasks. Three reusable team templates live in [.claude/teams/](.claude/teams/):

- [review-team](.claude/teams/review-team.md) — parallel pre-merge audit (security-triage + performance + a11y, all read-only).
- [feature-team](.claude/teams/feature-team.md) — cross-layer feature delivery (developer + test-engineer + ui-engineer, strict file ownership).
- [debug-team](.claude/teams/debug-team.md) — adversarial root-cause analysis (3× explorer with competing hypotheses).

## Quality, self-review, and memory

Use the imported shared contract's quality and two-pass self-review protocol;
role definitions add domain checks. Read `.agents/memory/README.md` before recording
lessons. Read-only teammates return candidates to the lead. Claude auto-memory is
not enabled per agent: both harnesses use the one local `.agents/memory/` store.

## Escalate immediately (do not silently work around)

- Security-sensitive change (auth, crypto, secrets, permissions).
- Breaking public API change.
- Data migration or schema change.
- Performance regression > 10% on a measured metric.
- A test fails after 2 fix attempts.
- Scope exceeds estimate by > 2×.
- A teammate proposes a destructive operation outside the requested scope.

## Hook recovery

When a commit hook fails, fix the root cause and create a new commit; do not amend
a failed commit or bypass the hook. Report unavailable gates rather than treating
a reminder/Stop prompt as deterministic verification.
