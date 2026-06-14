---
name: keiko-issue
description: Drive a single GitHub issue (task / feature / bug / user-finding) end-to-end from origin/dev to a green PR, the standard Keiko way — Definition-of-Ready gate, task-shaped agent team, quality bars, mandatory keiko-issue-audit, sacred-dev delivery. Use when the operator selects one issue to work on. Takes an issue number.
---

# keiko-issue

Canonical, parameterized single-issue workflow for both harnesses. Replaces the
old `codex-task-prompt.md` / `claude-issue-prompt.md` run-cards. **Composes the 16
canonical roles** (`.agents/roles.yaml`), **defers to** `docs/workflow-contract.md`
for branching, gates, and the sacred-`dev` rule — follow them, do not restate.

**Argument:** the issue number `#N` (optionally a mode: `feature` adds behavior,
`fix` repairs a defect/regression/finding).

## Role

You are the lead session — the sole orchestrator. Do not edit code yourself.

## 1. Intake (Definition-of-Ready gate)

Fetch `#N` (body, labels, comments, linked PRs/children). The issue must have
acceptance criteria + a verification command. If missing → triage first
(comment the gap, `status: new`), do not start. If it's an epic, do not run this
skill — use `keiko-epic`. If ambiguous or conflicting with governance, stop and
report.

## 2. Claim on the delivery board

Add to `Keiko Product Delivery` if missing; `status: in progress`; `Workflow
State`/`Status` = `In Progress`; `Owner / Agent` = active agent; `Human Review
Required` = `Yes` for any PR targeting `dev`; fill `Branch` once created.

## 3. Route (task-shaped)

Smallest effective shape:

- `fix` with unclear root cause → debug fan-out (competing hypotheses) before any fix; reproduce first when steps exist.
- `fix` known/scoped → `implementor` (minimal diff).
- `feature` single-scope → `developer` (spec-first, TDD); cross-layer → feature team with strict, disjoint file ownership.
- Add `security-triage`→`security-auditor`, `performance-engineer`, `a11y-auditor`, `architect`, `docs` only when the changed surface creates that risk.
  Assign explicit, disjoint file ownership before any write agent starts.

## 4. Implement

Quality bars (per contract): complexity ≤10, function ≤50 LOC, file ≤400 LOC,
no `any`, TDD for new behavior, mandatory 2-pass self-critique. Issue-scoped only;
no unrelated refactors, TODOs, or placeholders. Out-of-scope blockers → report up,
the lead files a linked issue (`status: new`); never expand scope.

## 5. Verify, audit, ship (per contract — sacred-`dev`)

1. `.keiko-scripts/verify.sh` green locally (CI mirror).
2. **Run `keiko-issue-audit` `#N`** — mandatory before PR-ready, even if it finds
   nothing. It writes the audit receipt for HEAD as its last step.
3. Branch `issue/<N>-<short>` off `dev`; Conventional Commit referencing `#N`;
   `verifier` fills the PR "Verification evidence" section.
4. **Proof-of-audit gate.** Before opening the PR, `.keiko-scripts/audit-gate.sh`
   must pass — it's enforced by a PreToolUse hook that **blocks `gh pr create`**
   unless a valid audit receipt exists at HEAD. If you committed after the audit,
   re-run `keiko-issue-audit` (the receipt is SHA-bound and goes stale).
5. Open PR. **Every merge into `dev` is human-gated + green CI** — never
   auto-merge to `dev`, never enable auto-merge. `pr-shepherd` drives CI/review
   to merge-ready; bounded CI repair (stop after 3 distinct failed attempts).
6. Set `Workflow State` = `PR Open` → `Ready for Human Review`; flush
   current-state + next-action to the issue/PR.

## Escalate (stop, report)

Security-sensitive change; breaking public API; data/schema migration; >10% perf
regression; scope >2×; 3 distinct failed CI repairs; security-auditor critical/high.

## Final report

Issue · team used + why · files changed · tests/checks run · `keiko-issue-audit`
status · PR + `ci` status · board fields · residual risks/follow-ups.
