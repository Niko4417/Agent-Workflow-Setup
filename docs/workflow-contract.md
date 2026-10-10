# Agent Workflow Contract (tool-neutral)

The shared delivery reference for target-product work. [AGENTS.md](../AGENTS.md)
carries the always-on contract; [CLAUDE.md](../CLAUDE.md) adds Claude mechanics and
[Codex RUNBOOK](../codex/RUNBOOK.md) adds Codex operation. The five skills contain
executable procedures. Select [one product profile](../profiles/README.md) before
product work; target-owned contracts govern requirements, readiness, branches,
checks, and evidence. Web examples below are not Native policy.

Target `AGENTS.md`, scoped instructions, ADRs, and explicit user choices override
generic workflow defaults. For Keiko, ADR-0135 authorizes accepted, checked
`dev` delivery through native auto-merge; ADR-0145 retires `agent:pre-pr`.
An explicit final epic review hold is a procedural instruction for that run,
not a universal helper-enforced restriction, and adds no per-child approval. Otherwise retain the generic final human-review default
where the target and user have not authorized another path.

## Roles and authorization

- The human selects work and settles unresolved product/scope/risk decisions.
- The lead is the sole orchestrator: plan, route, integrate, maintain GitHub state,
  and gate delivery. Never spawn a sub-coordinator.
- Workers own bounded tasks with explicit file scopes, evidence, dependencies,
  and stop conditions. Return findings to the lead; do not expand scope, file
  issues, contact the human, or recursively delegate.

Use the smallest effective shape: single-agent for tiny work; independent read
reviews or disjoint writers when they materially help. The accepted issue/spec and
user instruction authorize in-scope delivery; do not insert repeated approval
steps into an approved child loop. Missing authority, acceptance, or a material
scope decision is a blocker to surface immediately.

## Branching and delivery

Web: `epic/<name>` (or `codex/epic-<name>`) off `dev`, children
`issue/<id>-<name>` (or `codex/issue-<id>-<name>`) off their epic branch,
standalone issues off `dev`. Native: source branch and frozen delivery target come
from the accepted Execution Authority; merge-capable operations belong to the
profile's dedicated automation identity. Validate isolated worker bases before
writes, since a temporary worktree may start from the default branch.

Every issue ships through a PR. Children integrate into their accepted epic branch
after all applicable current-head evidence and the full target required-check
matrix are green and review findings are settled. Children execute AFK; missing
proof triggers repair or escalation, not a per-child human-review ceremony. Final
`dev` delivery follows the target and explicit run authority above.

Before the final epic PR, integrate the latest accepted base and verify the whole
production composition and accepted journeys at that new HEAD. If HEAD changes,
refresh the evidence. After authorized merge, inspect the new integration baseline
and record post-merge results before claiming closure.

## Issue lifecycle

1. **Intake:** load the accepted issue and selected profile's readiness contract.
   Web requires acceptance criteria plus a verification command. Native requires
   current machine-validated readiness and its Execution Authority / Quality Plan;
   a ready label or board field alone is insufficient. Respect another assignee.
2. **Claim and branch:** assign the operator before implementation; use the
   target-owned lifecycle interface. Native derived labels/board fields are
   projections, never manually granted execution authority.
3. **Implement:** keep accepted scope and shared quality bars. For bugs, execute
   the reported symptom before fixing and rerun it afterward. Map accepted
   behaviors to public test seams and their catches/misses in the existing plan.
4. **Verify and audit:** commit fixes, run the canonical verify command and the
   issue-scoped `keiko-issue-audit`, then record exact-head receipts. Separate
   accepted-requirement gaps from repository-standard violations; only confirmed,
   cited defects block. Required UI/platform evidence must actually run.
5. **PR and handoff:** fill the target template with actual evidence. User-facing
   PRs open draft, receive the current SHA-bound journey-plan comment, then become
   ready. Child PRs continue to machine-gated integration; `dev` PRs follow the
   target's delivery authority or an explicit final review hold after required CI
   is green.
6. **Report and close:** flush current state + next action to the issue/PR at each
   milestone. Close only after merge and the target's completion predicates hold;
   readiness for human review alone is not completion. Record acceptance results,
   commands/checks, audit, limitations, PR/commit, and follow-ups.

Use [keiko-issue](../claude/skills/keiko-issue/SKILL.md) for the full single-issue
procedure and [keiko-epic](../claude/skills/keiko-epic/SKILL.md) for child ordering,
integration, and final handoff.

## Verification and gate stack

`verify-receipt.sh <N>` invokes `verify.sh`: follow current target instructions
first. Keiko ADR-0145 uses individual minimum-loop and touched-area commands,
including mandatory local Sonar, without reviving a retired wrapper. Older targets
may use `agent:pre-pr`, Native `quality` + audit, web `codex:pre-pr`, or the legacy
CI-mirror fallback only where their current contract still accepts that path.
Follow the target's current toolchain, dependency setup, and
required platform runners. Select additional touched-area gates from that contract
and the accepted plan using repeatable `--also <current npm checking script>` on
`verify.sh` or `verify-receipt.sh <N>`. The receipt runs and records selected
commands itself; a `--fast` smoke is not a full verify receipt.

| Gate | Evidence checked / scope |
| --- | --- |
| `verify-gate.sh` | Green verify receipt at HEAD for PR create/ready on `issue/*`, `epic/*`, or `codex/*` work branches |
| `audit-gate.sh` | Audit at HEAD with known `findings=0`, known UI applicability, and green UI receipt when required |
| `ready-gate.sh` | Current `<!-- keiko:manual-test-plan sha=<HEAD> -->` comment before readying user-facing work-branch PRs, including children |
| `push-gate.sh` | ADR-0145 Web first implementation push: fresh verify; unchanged existing base bootstrap allowed. Open work-PR pushes: fresh verify/audit/UI receipts and current plan comment, including children |
| `epic-merge-gate.sh` | Full current-head target required-check matrix, settled review findings, matching verify/clean-audit/UI evidence and current plan; target/user merge authority |

Receipt writers are explicit workflow steps; hooks check them, they do not create
proof. After any fix commit, reverify/re-audit, rerun applicable UI journeys,
repost the SHA-bound plan on an existing PR, and push. One verifier owns a SHA;
cancel superseded runs instead of accepting stale output.

The web epic merge command is exactly `gh pr merge <N> --auto --squash
--match-head-commit <audited-sha>` (optional `--delete-branch`). The gate rejects
repository/content overrides, shell chaining, missing/stale evidence, and admin
bypass. Native's accepted contract and dedicated automation remain authoritative;
the web command is not a grant of Native merge authority.

Local pre-commit hooks are target-owned (see [template snippets](../templates/README.md));
do not assume every target installed lint-staged or a secret scan. Every agent
performs two-pass self-review. Claude's prompt Stop judge allows one blocking
continuation (`stop_hook_active` ends repeated blocking); it is a heuristic check,
not a test runner. Codex's Stop hook currently logs lifecycle metadata, not an
independent completion judge. Server-side controls follow the target's contract.
Stronger epic-branch protection is an optional recommendation unless that
contract requires it; absence alone is not a workflow blocker. Do not demand `dev` protection parity or new maintainer
configuration before every epic. Required current-head checks and review
settlement remain mandatory.

## Blockers and recovery

Workers return out-of-scope blockers with evidence and a proposed follow-up scope.
The lead deduplicates against open issues and uses the target's current template
and lifecycle interface for any authorized follow-up. Do not expand the current
issue to fix unrelated findings.

Stop immediately for missing authority/acceptance, unresolved security or product
risk, conflicting ownership, or a required secret. For a recoverable verify/audit/CI
failure, allow at most three materially distinct attempts on the same problem,
then escalate with attempts, failure evidence, and the next required decision.
Re-splitting does not reset that budget. More specific role budgets may stop sooner.

## Status, memory, and observability

GitHub issue/PR state is the durable delivery record; board fields are projections
where the target lifecycle says so. No parallel local task-status store. Post a
heartbeat at each wave/milestone and flush enough state to resume across harnesses.

Memory is local-only at `.agents/memory/<role>/MEMORY.md`, under 25 KB/file. Follow
[the memory contract](../.agents/memory/README.md): only durable lessons, no minimum
quota, no secrets/private-source dumps/session logs. Read-only roles return
candidates to the lead. Retros propose workflow repairs; they do not implicitly
edit target authority. Hook logs contain lifecycle metadata, not raw tool output
or assistant/source content.

## Transport and safety

Prefer SSH; inspect local agent/config/key registration on failure before a
reported HTTPS fallback. Never expose credentials during diagnosis.

Agents may have full local access. Prompt rules and command hooks reduce mistakes
but are not a filesystem/security boundary: Bash can write, and hooks cover only
recognized paths/commands and configured events. Verify actual runtime sandboxes.
Protected branches, required checks, and human reviews protect repository merges
when configured; they do not make all local destructive actions impossible.
Never bypass gates or perform destructive shared operations without explicit
authorization. Never present missing evidence as verified; use an explicit error
or recovery state for trust-sensitive product flows.
