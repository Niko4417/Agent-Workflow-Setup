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

**Collision check (do this first):** if `#N` already has a GitHub assignee other
than the operator, **do not start** — it's being worked by someone else. Skip and
report. (`gh issue view <N> --json assignees`.)

## 2. Claim on the delivery board

Claiming is mandatory before any implementation:

- **Assign the operator on GitHub** — `gh issue edit <N> --add-assignee @me`. The
  assignee is the cross-agent lock; never start an issue you haven't claimed.
- Add to `Keiko Product Delivery` if missing; `status: in progress`; `Workflow
State`/`Status` = `In Progress`; `Owner / Agent` = active agent; `Human Review
Required` = `Yes` for any PR targeting `dev`; fill `Branch` once created.

## 3. Route (task-shaped)

Smallest effective shape:

- `fix` with unclear root cause → debug fan-out (competing hypotheses) before any fix; reproduce first when steps exist.
- `fix` known/scoped → `implementor` (minimal diff).
- `feature` single-scope → `developer` (spec-first, TDD); cross-layer → feature team with strict, disjoint file ownership.
- **User-facing component** change → `ui-engineer` builds against the Keiko Design System (`docs/design-system/`); `a11y-auditor` reviews **WCAG + design-system fidelity** (token conformance, `state-matrix.md` coverage, evidence).
- Add `security-triage`→`security-auditor`, `performance-engineer`, `a11y-auditor`, `architect`, `docs` only when the changed surface creates that risk.
  Assign explicit, disjoint file ownership before any write agent starts.

## 4. Implement

Quality bars (per contract): complexity ≤10, function ≤50 LOC, file ≤400 LOC,
no `any`, TDD for new behavior, mandatory 2-pass self-critique. Issue-scoped only;
no unrelated refactors, TODOs, or placeholders. **User-facing components** conform
to the Keiko Design System (`docs/design-system/`): semantic/component tokens only
(no raw Tier-1 primitives or hex), full `state-matrix.md` coverage, governance
change-rules. Out-of-scope blockers → report up, the lead files a linked issue
(`status: new`); never expand scope.

## 5. Verify, audit, ship (per contract — sacred-`dev`)

1. **Verify-green loop.** Run `.keiko-scripts/verify-receipt.sh #N` — it runs
   `verify.sh` (the CI mirror) and writes the verify receipt **only if green**. If
   red, fix and re-run, **looping until green** (bounded by 3 distinct attempts →
   escalate). The PR-create **verify-gate** blocks `gh pr create`/`gh pr ready`
   until a green verify receipt exists at HEAD.
2. **Audit-clean loop.** Run `keiko-issue-audit` `#N` — mandatory. If it reports
   confirmed findings, fix them and re-audit, **looping until `findings=0`**
   (bounded by 3 attempts → escalate). The audit re-verifies and writes the audit
   receipt at HEAD as its last step. **User-facing issue:** also write a runnable
   Playwright plan, run it via `.keiko-scripts/ui-verify-receipt.sh #N -- <playwright cmd>`
   (it stamps the ui-verify receipt only on green), and post the
   `<!-- keiko:manual-test-plan -->` PR comment.
3. Branch `issue/<N>-<short>` off `dev`; Conventional Commit referencing `#N`;
   `verifier` fills the PR "Verification evidence" section. For a user-facing
   change, capture design-system evidence under `docs/design-system/evidence/<N>/`
   (theme screenshots + `*-fidelity-proof.json` + `a11y-proof.json`, ADR-0049/0051).
4. **PR gates.** Before opening the PR, three PreToolUse gates must pass and
   **block `gh pr create`** otherwise: `verify-gate` (green verify @ HEAD),
   `audit-gate` (audit ran @ HEAD), and — for a `-> dev` PR — `dev-pr-gate`
   (`findings=0` **and** a green ui-verify receipt when user-facing). If you
   committed after the audit, re-run the audit/verify (receipts are SHA-bound and
   go stale).
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
