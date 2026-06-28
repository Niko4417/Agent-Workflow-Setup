---
name: keiko-epic
description: Drive a multi-issue GitHub epic end-to-end — plan and order child issues, run them on an epic integration branch, and hand off one green epic PR to dev for human review. Use when the operator selects an epic to work on. Composes keiko-issue per child. Takes an epic number.
---

# keiko-epic

Canonical, parameterized epic workflow for both harnesses. Replaces the old
`codex-epic-prompt.md` / `claude-epic-prompt.md` run-cards. **Defers to**
`docs/workflow-contract.md` for the model and **composes** `keiko-issue` (per
child) and `keiko-issue-audit`. Do not restate contract rules.

**Argument:** the epic issue number `#E`.

## Role

You are the lead session — the sole orchestrator. Never spawn a sub-coordinator.
Do not edit code yourself; delegate child execution to `keiko-issue`.

## 1. Read & plan

Fetch `#E`: body, comments, labels, child issues (sub-issues + linked), linked
PRs, board state. Build the execution plan:

- list every child with state, labels, area, likely file ownership, dependencies, verification, **and current GitHub assignee**;
- classify each: `ready` / `blocked` / `done` / `needs-triage`; treat a child already assigned to someone other than the operator as **owned — skip it** (someone else is on it);
- respect the epic's required order; detect safe parallelism **only** when children have disjoint file ownership, independent acceptance criteria, and no ordering dependency.
  If the epic has no executable children and scope isn't clear enough to create them, stop and report.

Each `keiko-issue` child run assigns the operator (`--add-assignee @me`) as it
claims, and skips any child that's already assigned to someone else.

## 2. Epic branch

Create one long-lived `epic/<name>` off the latest `dev`. Record it on the board
and an epic comment before implementation starts. Child branches `issue/<id>-<short>`
are cut **off the epic branch**, not off `dev`.

## 3. Child loop (per `ready` child)

1. Run **`keiko-issue` `#child`** on its branch off the epic branch (it runs
   `verify.sh` + `keiko-issue-audit` as part of its flow).
2. The child PR targets the **epic branch**. CI does not run on `epic/*` PRs, so
   the child→epic gate is the **audit**, not GitHub CI:
   - **Non-user-facing child (no UI):** run `keiko-issue-audit`; when it reports
     confirmed findings, **fix them and re-audit, looping until the audit is clean**
     (`findings=0`), then **auto-merge** into the epic branch, no human. Each loop
     fixes the findings (scoped `implementor`/`developer`/`test-engineer`),
     re-runs the audit (which re-runs `verify.sh` and re-writes the SHA-bound
     receipt), and continues. **Bound the loop to 3 materially distinct fix
     attempts** (the contract's escalation threshold); if it is still not clean,
     **stop and escalate to the human — do not merge**.
   - **User-facing child** (touches user-facing UI / needs design-system evidence):
     drive the audit clean the **same way** (fix findings + re-audit until
     `findings=0`, bounded by the 3-attempt rule), then verify it locally:
     1. Write a **Playwright-reviewable** test plan — numbered, concrete
        `do X → expect Y` steps (action + expected result) for the user-facing
        behavior Playwright can assert (visible text/DOM, navigation, computed
        styles, focus order, ARIA, responsive viewports, visual snapshots),
        covering the acceptance criteria. Keep it automatable — subjective
        visual / screen-reader judgment is **deferred to the epic→`dev` human
        review**, not the child plan.
     2. Post it as a **PR comment** marked `<!-- keiko:manual-test-plan -->`
        (documentation, and the gate checks the marker exists).
     3. **Drive the plan with Playwright** locally (the repo's `test:e2e` harness /
        Playwright MCP) and assert every expected result.
     - All expected results green → record `--ui-verified true` → **auto-merge**.
     - Any failure (or a result Playwright cannot assert) → leave `ui_verified`
       false → **human review + merge** (the fallback).

   Auto-merge is the only place merges happen without a human, and it is
   **enforced** by `epic-merge-gate.sh` (a PreToolUse hook on `gh pr merge`): it
   **always blocks** an agent merge into `dev`/`main`/`release` (human-only via the
   UI); into an epic / integration branch it allows the merge only when
   `findings=0` **and** either `user_facing=false`, or `user_facing=true` with
   `ui_verified=true` **and** the marked test-plan comment present on the PR. The
   audit records `--findings`/`--user-facing`/`--ui-verified` in the receipt.

3. After merge, confirm the epic branch still builds (`verify.sh`); add a child
   comment linking PR/commit + evidence; update the board.
4. Rebase/merge `dev` into the epic branch regularly (esp. before the final PR).
   Activate a child only when its dependencies are satisfied; never start `blocked`
   work. Parallelize children only when section 1's safety conditions all hold.

## 4. Final epic PR (human-gated)

When all required children are integrated and verified on the epic branch:

1. Sync `dev` into the epic branch; resolve conflicts without dropping others' work.
2. `.keiko-scripts/verify.sh` green; run `keiko-issue-audit` on the integrated
   surface (it writes the audit receipt for the epic branch's HEAD as its last
   step). The proof-of-audit gate **blocks the epic PR** without a receipt at HEAD.
3. Open one epic PR `epic/<name> -> dev`. **Sacred-`dev`: human review + green CI
   required.** Body includes the child-issue matrix, summary by capability,
   verification evidence, known limitations/follow-ups, and that it is the
   accumulated epic branch.
4. Set the epic and remaining children to `Ready for Human Review`. Do **not**
   merge the epic PR or close the epic without explicit maintainer authorization.

## Escalate (stop, report)

Children contradict the epic or each other; missing required architecture/product
decision; parallel work would need overlapping ownership; CI repair exceeds 3
distinct attempts; security-auditor critical/high; public-API or data migration.

## Final report

Terminal state (`ready-for-human-review` / `escalated`) · child matrix (issue,
status, branch, PR, merge commit, verification) · epic branch + final PR + base +
latest `dev` sync · parallelism used + why safe · files by area · verification ·
board state · residual risks/follow-ups.
