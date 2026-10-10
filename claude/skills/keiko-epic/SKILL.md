---
name: keiko-epic
description: Drive a multi-issue GitHub epic end-to-end — plan and order child issues, run them on an epic integration branch, and deliver one green epic PR to dev under target authority and explicit run review choices. Use when the operator selects an epic to work on. Composes keiko-issue per child. Takes an epic number.
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

## 0. Select the product profile (before planning)

Select against the target checkout using [profile selection](../../../profiles/README.md).
State the profile on the first output line; explicit operator selection wins.
Load only the selected profile and its task-relevant authority docs, including the
target's `AGENTS.md` and `CONTEXT.md` when present. Take readiness, verification,
templates, evidence, exclusions, and merge authority from it; ambiguity requires
clarification. The accepted target contract governs product requirements.

Target `AGENTS.md`, scoped instructions, ADRs, and explicit user choices override
generic workflow defaults. For Keiko, ADR-0135 authorizes accepted, checked
`dev` delivery through native auto-merge; ADR-0145 retires `agent:pre-pr`.
An explicit final epic review hold is a procedural instruction for that run,
not a universal helper-enforced restriction, and adds no per-child approval. Otherwise retain the generic final human-review default
where the target and user have not authorized another path.

Child-loop examples below use web branches and Playwright. Native uses its frozen
delivery target, runner-managed source branches, dedicated automation identity, and
Acceptance Journey harness; never assume a browser host or private-source access.

## 1. Read & plan

Fetch `#E`: body, comments, labels, child issues (sub-issues + linked), linked
PRs, board state. Build the execution plan:

- list every child with state, labels, area, likely file ownership, dependencies, verification, **and current GitHub assignee**;
- classify readiness using the selected profile. **keiko-web:** accepted children in
  `New` or `Triaged` are executable when acceptance criteria and verification are
  complete; those states alone do not block intake. Resume `In Progress`/`PR Open`
  work only within its accepted scope. Actual `Blocked` or `Waiting for User`
  states remain non-executable until the blocker is resolved or the requested
  decision arrives. **keiko-native:** follow the target's validated lifecycle
  (`profiles/keiko-native.md` → Issue lifecycle); `new`/`triaged` remain
  non-executable, and a current accepted readiness record does not bypass state
  action limits. Treat `done` as completed, and a child assigned to someone other
  than the operator as **owned — skip it**;
- respect the epic's required order; detect safe parallelism **only** when children have disjoint file ownership, independent acceptance criteria, and no ordering dependency.
  If the epic has no executable children and scope isn't clear enough to create them, stop and report.

Each `keiko-issue` child run assigns the operator (`--add-assignee @me`) as it
claims, and skips any child that's already assigned to someone else.

## 2. Epic branch

**Dev-baseline preflight (before committing to a long Web epic).** Check the
applicable integration run at the current `dev` HEAD against the target's current
contract. Under ADR-0178, the canonical resolver may reuse complete successful
pull-request evidence for the exact merged PR's byte-identical tree. Record the
integration run and its proven-tree evidence identity; sanctioned reused jobs do
not need duplicate check runs on the squash SHA. The coverage chain and SonarCloud
branch analysis still run on every `dev` push. A failed executed check remains red;
missing, pending, or unproven evidence is not green. Resolve or wait before starting.
This integration-only reuse never permits missing, skipped, or stale required
checks on a child or final epic PR: every PR needs the full exact-head matrix.
Native uses its frozen accepted delivery target and current activation contract.

Create one long-lived `epic/<name>` or `codex/epic-<name>` off the latest `dev`.
Record it on the board and an epic comment before implementation starts. Child
branches `issue/<id>-<short>` or `codex/issue-<id>-<short>` are cut **off the epic
branch**, not off `dev`. On ADR-0145 Web targets, an unchanged accepted base-ref
creation push matching the exact existing `origin/dev` or canonical origin epic
commit may establish the branch before implementation. Before the first
implementation push, obtain fresh full verify proof at HEAD; the audit is required
before PR creation, not for that first push alone. Native retains its accepted
Execution Authority and target-owned delivery contract.

## 3. Child loop (per executable child)

**Children run AFK (no human-in-the-loop per child).** A child integrates into the
epic branch **autonomously** — there is no per-child human review or sign-off. The
final review hold, when requested, applies to the **epic → `dev`** PR (the full
feature). A child
either **auto-merges on green machine evidence**, or it **escalates as an exception**
(something went wrong); it never pauses to wait for a human to approve that one child.

1. Run **`keiko-issue` `#child`** on its branch off the epic branch (it runs
   `verify.sh` + `keiko-issue-audit` as part of its flow).
2. The child PR targets the **epic branch**. Auto-merge requires a completed,
   successful full target required-check matrix on the exact PR head (no skipped
   or absent required checks), settled review findings, **and** matching SHA-bound local verify/audit evidence:
   - **Non-user-facing child (no UI):** run `keiko-issue-audit`; when it reports
     confirmed findings, **fix them and re-audit, looping until the audit is clean**
     (`findings=0`), wait for the full exact-head target check matrix and settled
     reviews, then **auto-merge** into the
     epic branch, no human. Each loop
     fixes the findings (scoped `implementor`/`developer`/`test-engineer`),
     re-runs the audit (which re-runs `verify.sh` and re-writes the SHA-bound
     receipt), and continues. **Bound the loop to 3 materially distinct fix
     attempts** (the contract's escalation threshold); if it is still not clean,
     **stop and escalate to the human — do not merge**.
   - **User-facing child** (touches user-facing UI / needs design-system evidence):
     drive the audit clean the **same way** (fix findings + re-audit until
     `findings=0`, bounded by the 3-attempt rule), then verify it locally:
     1. Write a **runnable Playwright spec** for the test plan — numbered
        `do X → expect Y` steps Playwright can assert (visible text/DOM,
        navigation, computed styles, focus order, ARIA, responsive viewports,
        visual snapshots), covering the acceptance criteria. Keep it automatable —
        optional subjective visual / screen-reader follow-ups go into final epic
        evidence and any requested human review. Required UI proof still runs
        before child integration.
     2. Post the plan as a **PR comment** marked
        `<!-- keiko:manual-test-plan sha=<HEAD> -->` (SHA-bound; the merge gate
        requires a comment naming the audited commit, so repost on any fix).
     3. Run it via **`.keiko-scripts/ui-verify-receipt.sh #child -- <playwright cmd>`**
        — it executes the spec and writes the ui-verify receipt **only on a real
        green exit** (the result is not self-reported).
     - ui-verify receipt green at HEAD **and** comment present → **auto-merge** (AFK).
     - Playwright **red** after the bounded 3 attempts → **stop and escalate to the
       operator** (an exception surfaced to the epic-level human — **not** a per-child
       human merge).
     - A result the automated journey **cannot assert** (subjective visual /
       screen-reader judgment) → **auto-merge on the machine-green evidence** and
       **carry the optional follow-ups into final epic evidence and any requested
       human review** (recorded on the epic). No per-child human sign-off.

   `epic-merge-gate.sh` checks child integration evidence; target/user authority
   governs final delivery. Into an accepted epic branch it allows the merge
   only when the full exact-head target check matrix, settled review findings, a
   matching green verify receipt, and (`findings=0`) hold **and** either
   `user_facing=false`, or
   `user_facing=true` with a **green ui-verify receipt at the audited commit** (the
   Playwright plan actually ran green) **and** the marked test-plan comment present.
   Invoke exactly `gh pr merge <N> --auto --squash --match-head-commit
<audited-sha>` (optionally `--delete-branch`); the gate rejects other selectors,
   repository/content overrides, shell chaining, missing or stale merge-time
   guards, and every admin bypass.

3. **Child closeout — mechanical checklist (all must hold before the next child):**
   - [ ] PR **base** is the epic branch (not `dev`/`main`/`release`).
   - [ ] **Merge** landed (auto-merge gate passed, or human-merged).
   - [ ] **Post-merge verification:** epic branch still builds (`verify.sh`) at the new epic HEAD.
   - [ ] **Close the child as done.** With the child PR **merged into the epic branch**
         and all accepted scope stages and their evidence complete, transition the
         child to the profile's **done** state and **close it**. **keiko-native:** close with reason `completed` carrying
         exactly **`status: done`** (other `status:*` removed), a projection of
         `docs/qa/issue-lifecycle.md` — read it at runtime and **fail closed** if
         labels/contract are missing/stale; never let the board grant the transition.
         **keiko-web:** close + `status: done`. Never close a child whose PR is not
         merged or whose accepted stages remain. Separately audited stages do not complete the whole issue.
   - [ ] **Closure evidence** recorded: child comment linking PR/commit + verification/audit evidence; board updated (a projection of the closed/`done` state).
         Any unchecked box → stop and resolve before moving on.
4. Rebase/merge `dev` into the epic branch regularly (esp. before the final PR).
   **Dependency-readiness trace (before starting any runtime/dependent child):** do
   not start a child on the strength of an upstream issue merely being "closed" —
   trace the dependency **end-to-end** and confirm it is _actually_ ready: the
   upstream runtime / contract / artifact it consumes exists on the epic branch,
   builds, and its interface contract holds. If the trace fails, the child stays
   `blocked`. Never start `blocked` work. Parallelize children only when section 1's
   safety conditions all hold.

## 4. Final epic PR (target authority and run review hold)

When all required children are integrated on the epic branch:

1. **Rebase/merge the latest `dev` into the epic branch FIRST** — resolve conflicts
   without dropping others' work. Everything below runs against this integrated
   HEAD; if `dev` moves again, re-integrate and re-run the loops.
2. **Run the airtight loops on the integrated epic, until all clean** (the receipts
   are SHA-bound, so they must cover the post-rebase HEAD):
   - `.keiko-scripts/verify-receipt.sh` — loop verify→fix until green.
   - `keiko-issue-audit` on the integrated surface — loop fix→re-audit until
     `findings=0` (it re-verifies and writes the audit receipt at HEAD as its last
     step).
   - **user-facing epic:** `.keiko-scripts/ui-verify-receipt.sh #E -- <playwright cmd>`
     — the integrated Playwright plan must actually run green.
3. **Open the epic PR `epic/<name> -> dev` — it will not open unless all of the
   above are clean at HEAD.** `verify-gate` (green verify) + `audit-gate` (clean
   audit: ran, `findings=0`, + ui-verify when user-facing) enforce it on
   `gh pr create`. **User-facing epic:** open it `--draft`, post the
   `<!-- keiko:manual-test-plan sha=<HEAD> -->` comment carrying the **integrated**
   epic's runnable Playwright plan, then `gh pr ready` — the **ready-gate** blocks
   `ready` until a comment naming the current commit exists. Body: child-issue
   matrix, summary by capability, verification evidence, known limitations/follow-ups.
4. **Watch the real GitHub CI and drive it green** (`pr-shepherd`) — bounded repair,
   stop after 3 distinct failed attempts and escalate. **Each CI-repair repush
   re-runs the QA:** the **push-gate** blocks a `git push` to any open work-branch PR, including children,
   unless fresh verify + clean-audit (+ ui-verify) receipts exist at the new HEAD —
   and, for a user-facing epic, the `keiko:manual-test-plan sha=<HEAD>` comment
   reposted for the new commit — so fix → re-run the loops → repost the comment → push.
5. **Only once the full current-head target matrix is green and reviews are
   settled**, honor the requested final epic review hold: set `Ready for Human
   Review` and do not arm final auto-merge until that hold is lifted. When no hold
   applies, follow target-authorized delivery (Keiko ADR-0135 native auto-merge);
   otherwise retain the generic final human-review default.
6. **Closure evidence — capture the post-merge baseline.** After the authorized
   merge of the epic into `dev`, the epic is only truly closed out when `dev` is green **at the new
   HEAD** under the applicable integration contract (including canonical ADR-0178
   reuse, never a skipped PR matrix): record the **post-merge branch analysis**
   (e.g. the `dev` Sonar branch run and any other required post-merge check) as closure evidence on the epic. A merged
   epic whose post-merge `dev` run is red is **merged but not closed out** — track the
   failing check as follow-up, don't mark the epic done on a red post-merge baseline.

## Escalate (stop, report)

Escalate missing or contradictory acceptance criteria, unresolved product or
architecture decisions, authority conflicts, material scope expansion, overlapping
write ownership, prohibited sensitive artifacts, or exhaustion of 3 materially
distinct repair attempts. Accepted in-scope security, public-API, and migration work
proceeds with the target-required audits and Quality Plan; its category alone does
not require another approval. Confirmed unsafe findings block delivery until
repaired and re-audited; escalate when safe resolution needs a missing decision,
additional authority, or exceeds the bounded recovery attempts.

## Final report

Terminal state (`ready-for-human-review` / `completed` / `escalated`) · child matrix (issue,
status, branch, PR, merge commit, verification) · epic branch + final PR + base +
latest `dev` sync · parallelism used + why safe · files by area · verification ·
board state · residual risks/follow-ups.
