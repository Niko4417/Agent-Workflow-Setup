---
name: keiko-issue
description: Drive a single GitHub issue (task / feature / bug / user-finding) end-to-end from origin/dev to a green PR, the standard Keiko way — Definition-of-Ready gate, task-shaped agent team, quality bars, mandatory keiko-issue-audit, target-authorized delivery. Use when the operator selects one issue to work on. Takes an issue number.
---

# keiko-issue

Canonical, parameterized single-issue workflow for both harnesses. Replaces the
old `codex-task-prompt.md` / `claude-issue-prompt.md` run-cards. **Composes the 16
canonical roles** (`.agents/roles.yaml`), **defers to** `docs/workflow-contract.md`
for branching, gates, and target-owned delivery authority — follow them, do not
restate.

**Argument:** the issue number `#N` (optionally a mode: `feature` adds behavior,
`fix` repairs a defect/regression/finding).

## Role

You are the lead session — the sole orchestrator. Do not edit code yourself.

## 0. Select the product profile (before intake)

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

## 1. Intake (Definition-of-Ready gate)

Fetch `#N` (body, labels, comments, linked PRs/children). Apply the **active
profile's Definition of Ready**. **keiko-web:** the issue must have acceptance
criteria + a verification command; accepted `New`/`Triaged` work is executable
when those are complete. Actual `Blocked`/`Waiting for User` states require
resolution or the requested decision before resuming. **keiko-native:** it must be
a machine-validated accepted contract — a single `type:*` label, `status: ready` with a matching
readiness record (validated `Planning contract` version + fingerprint), and a
complete **Execution Authority** + **Quality Plan**; an instruction to consult the
private Fachkonzept or infer omitted requirements is a missing-requirement defect
(stop, return to planning). Follow the profile's **Issue lifecycle** rules
(`profiles/keiko-native.md`): **evaluate readiness independently of the `status:*`
label** (a label is not authority), treat **`triaged` as non-executable**, claim only
a genuinely **current-ready** claimable state, and **fail closed** on zero/multiple/
unknown labels or stale readiness. If missing/unready → triage first (comment the gap,
`status: new`), do not start. If it's an epic, use `keiko-epic`. If ambiguous or
conflicting with governance, stop and report.

**Collision check (do this first):** if `#N` already has a GitHub assignee other
than the operator, **do not start** — it's being worked by someone else. Skip and
report. (`gh issue view <N> --json assignees`.)

## 2. Claim on the delivery board

Claiming is mandatory before any implementation:

- **Assign the operator on GitHub** — `gh issue edit <N> --add-assignee @me`. The
  assignee is the cross-agent lock; never start an issue you haven't claimed. In
  **keiko-native** the assign **is** the claim (the claimable-state trigger).
- Board update. **keiko-web:** set `status: in progress`; `Workflow State`/`Status` =
  `In Progress`. **keiko-native:** **do not hand-write the derived `status: in
progress` label** — it is a reconciled effect the target owns; board / project fields
  are **one-way projections**, never authority. In both: `Owner / Agent` = active agent;
  `Human Review Required` reflects target requirements and explicit run holds;
  fill `Branch` once created.

Create the source branch before implementation: web `issue/<N>-<short>` or
`codex/issue-<N>-<short>` from `dev` (epic children from their epic branch); Native a runner-managed branch
including the issue number, from its frozen accepted delivery target. Record the
branch on the board. For isolated workers, verify their actual base includes the
required parent commits before they write; a default-branch worktree is not enough.

## 3. Route (task-shaped)

Smallest effective shape:

- `fix` with unclear root cause → execute the reproduction below, then debug fan-out with competing hypotheses before any fix.
- `fix` known/scoped → `implementor` (minimal diff).
- `feature` single-scope → `developer` (spec-first, TDD); cross-layer → feature team with strict, disjoint file ownership.
- **User-facing component** change → `ui-engineer` builds against the active profile's UI standard (keiko-web: Keiko Design System `docs/design-system/`; **keiko-native:** `docs/planning/native-design-baseline.md`, evidence generated anew); `a11y-auditor` reviews **WCAG 2.2 AA** plus that standard's fidelity and the issue's **Acceptance Journey** checkpoints.
- Add `security-triage`→`security-auditor`, `performance-engineer`, `a11y-auditor`, `architect`, `docs` only when the changed surface creates that risk.
  Assign explicit, disjoint file ownership before any write agent starts.

## 4. Implement

Apply the shared quality bar and the target's accepted Quality Plan. Issue-scoped only;
no unrelated refactors, TODOs, or placeholders. **User-facing components** conform
to the active profile's UI standard (keiko-web: Keiko Design System — semantic/
component tokens only, full `state-matrix.md` coverage, governance change-rules;
**keiko-native:** `native-design-baseline.md`, satisfying the issue's Acceptance
Journey). In **keiko-native** honor the issue's frozen **Execution Authority** (write
scope, delivery target, prohibitions) and **never** store/quote/request the private
Fachkonzept. Out-of-scope blockers → report up, the lead files a linked issue
(`status: new`); never expand scope.

**Bug reproduction (fix mode).** Before editing, run a command/test that asserts
the reported symptom on the current code; record expected vs actual behavior and
the command's result. A build failure or guessed explanation is not a reproduction
of a behavioral bug. Minimize the input while preserving the failure, then trace
the failing path. If the symptom cannot be reproduced, report the missing evidence
and continue bounded investigation; do not claim a proven fix. After the change,
rerun the original reproduction and relevant regressions. If using a temporary
mutation to prove a test detects the defect, inspect its diff against the pristine
version and prove it landed and caused the intended assertion failure; restore it
before continuing. Never manufacture a red result through a syntax/import error.

**Behavioral test plan.** In the existing test plan / Quality Plan, map accepted
requirements to observable public boundaries (API, adapter, component, CLI, or
production composition). For each seam state one line of what it **catches** and
**misses**, so a green unit test is not mistaken for wiring/platform evidence.
Implement one meaningful red → green slice at a time. Derive expected values from
the requirement or an independent oracle, not the same computation as production.
Use the accepted plan's authority; seek clarification only for unresolved scope
or product decisions, not routine test placement.

Commit the scoped implementation before SHA-bound receipt generation, using a
Conventional Commit referencing `#N`. Audit fixes or generated evidence may require
another commit; refresh all affected proof at that new HEAD. For ADR-0145 Web
targets, an unchanged accepted base-ref creation push matching the exact existing
`origin/dev` or canonical origin epic commit may establish the branch before
implementation. The first implementation push requires fresh full verify proof at
HEAD; it does not require an early audit when no PR exists. PR creation and
subsequent open-PR pushes require the audit and applicable UI proof below. Native
retains its accepted Execution Authority and target-owned delivery contract.

## 5. Verify, audit, ship (per target contract)

1. **Verify-green loop.** Run `.keiko-scripts/verify-receipt.sh #N` — it runs the
   **current target-required commands** through `verify.sh` (ADR-0145 targets use
   individual commands; older accepted wrappers remain compatibility paths) and
   writes the verify receipt **only if
   green**. Include every applicable target/accepted Quality Plan obligation,
   selecting semantic touched-area gates with repeatable `--also <script>`;
   default command selection alone does not prove those obligations. If red, fix
   and re-run, **looping until green** (bounded by 3 distinct attempts → escalate). The PR-create **verify-gate** blocks `gh pr create`/`gh pr
ready` until a green verify receipt exists at HEAD.
   **Cross-layer issue (spans ≥2 layers/packages):** a green unit suite is _not_
   sufficient — tests have passed while production wiring was broken (e.g. a
   composition silently dropping a configured Model-Gateway URL). Beyond tests, the
   verify-green loop must cover **root typecheck**, the **architecture check**, a
   **non-test production-composition build** (the real wiring compiles/loads, not
   just fixtures), and **at least one real request-path smoke** exercising the actual
   production path end-to-end. Use the target's current commands and add the real
   request-path smoke explicitly.
2. **Audit-clean loop.** Run `keiko-issue-audit` `#N` — mandatory before PR
   creation. Accepted scope stages may be audited separately against their own
   acceptance boundaries; name the audited stage and remaining stages explicitly.
   Stage evidence does not authorize closing the whole issue. If it reports
   confirmed findings, fix them and re-audit, **looping until `findings=0`**
   (bounded by 3 attempts → escalate). The audit re-verifies and writes the audit
   receipt at HEAD as its final verification step. **User-facing web issue:** write a runnable
   Playwright plan and run it via `.keiko-scripts/ui-verify-receipt.sh #N -- <playwright cmd>`
   (it stamps the ui-verify receipt only on green). Publish the SHA-bound plan
   comment after opening the draft PR (step 5); repost on every HEAD change.
   In Native, use the Acceptance Journey's native harness through the same receipt
   wrapper; do not assume Playwright can test the desktop host.
3. The lead uses `verifier`'s proposed evidence in the
   PR "Verification evidence" section. For a user-facing change, capture the
   profile's evidence (keiko-web: design-system evidence under
   `docs/design-system/evidence/<N>/` — theme screenshots + `*-fidelity-proof.json` +
   `a11y-proof.json`, ADR-0049/0051; **keiko-native:** the issue's **Acceptance
   Journey** automated/a11y/visual/recovery/platform evidence, machine-evaluated and
   bound to the exact head).
4. **PR gates.** Before opening the PR, two PreToolUse gates must pass and
   **block `gh pr create`** otherwise: `verify-gate` (green verify @ HEAD) and
   `audit-gate` (a **clean** audit @ HEAD — ran, `findings=0`, **and** a green
   ui-verify receipt when user-facing). Same for every PR, any target. If you
   committed after the audit, re-run the audit/verify (receipts are SHA-bound and
   go stale). **One verifier owns a given SHA:** on any new commit, **cancel
   superseded verification runs and close their agents** (their receipts are stale
   by design) — never leave duplicate or orphaned verification agents running
   against an outdated HEAD.
5. Open PR. **Know which mode you're in — issues run AFK:** an **epic child**
   (PR → the epic branch) has **no human-in-the-loop** — `keiko-epic` auto-merges it
   on green machine evidence or escalates as an exception; there is no per-child human
   review, no `Ready for Human Review` handoff. A **standalone** issue (PR → `dev`) is
   delivered under the target's authority or an explicit review hold.
   **User-facing PRs (including children):** open `--draft`, post the `<!-- keiko:manual-test-plan sha=<HEAD> -->` comment (the
   runnable Playwright plan), then `gh pr ready` — the **ready-gate** blocks `ready`
   until a comment naming the current commit exists.
   (Non-user-facing PRs open ready directly.) **Every merge requires the full
   current-head target check matrix and settled review findings; absent or skipped
   required PR checks never qualify through integration-only proven-tree reuse.**
   Arm native auto-merge only when target/run authority permits it.
   `pr-shepherd` drives CI/review to merge-ready; bounded CI repair (stop after 3
   distinct failed attempts). **Each CI-repair repush re-runs the QA:** the
   **push-gate** blocks a `git push` to any open work-branch PR, including a child,
   unless fresh verify + clean-audit (+ ui-verify) receipts exist at the new HEAD — and, for a
   user-facing PR, the `keiko:manual-test-plan sha=<HEAD>` comment reposted for the
   new commit — so fix → re-run the loops → repost the comment → push.
6. **Standalone → `dev` only:** use `Ready for Human Review` when the target or
   run requires a hold; otherwise continue authorized checked delivery. Flush
   current-state + next-action to the issue/PR. (An **epic child** does
   not stop here — it proceeds to AFK auto-merge under `keiko-epic`.)
7. **Close as done on merge.** When the issue's linked PR is **merged** — a child
   auto-merged into its **epic branch**, or an authorized standalone PR merged into
   `dev` — and **all accepted scope stages are complete with evidence**, transition
   the issue to the profile's **done** state and **close it**.
   **keiko-native:** the issue is closed with reason `completed` carrying exactly
   **`status: done`** (every other `status:*` removed), as a **projection** of the
   target's `docs/qa/issue-lifecycle.md` (done = closed + `status: done`; reopen →
   `new`) — read it at runtime and **fail closed** if labels/contract are missing/stale.
   **keiko-web:** close + `status: done` per the Keiko taxonomy. Only a **merged** PR
   closes an issue as done — never on `Ready for Human Review` alone. Follow the
   target's permitted merge path.

## Escalate (stop, report)

Escalate missing or contradictory acceptance criteria, unresolved product or
architecture decisions, authority conflicts, material scope expansion, overlapping
write ownership, prohibited sensitive artifacts, or exhaustion of 3 materially
distinct repair attempts. Accepted in-scope security, breaking public-API, and
migration work proceeds with the target-required audits and Quality Plan; its
category alone does not require another approval. Confirmed unsafe findings block
delivery until repaired and re-audited. A performance regression outside the
accepted budget must be repaired; escalate when safe resolution needs a missing
decision, additional authority, or exceeds the bounded recovery attempts.

## Final report

Issue · team used + why · files changed · tests/checks run · `keiko-issue-audit`
status · PR + `ci` status · board fields · residual risks/follow-ups.
