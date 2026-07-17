---
name: keiko-issue
disable-model-invocation: true
description: Drive a single GitHub issue (task / feature / bug / user-finding) end-to-end from origin/dev to a green PR, the standard Keiko way — Definition-of-Ready gate, task-shaped agent team, quality bars, mandatory keiko-issue-audit, sacred-dev delivery. Use when the operator selects one issue to work on. Takes an issue number.
---

# keiko-issue

Canonical, parameterized single-issue workflow for both harnesses. Replaces the
old `codex-task-prompt.md` / `claude-issue-prompt.md` run-cards. **Composes the 15
canonical roles** (`.agents/roles.yaml`), **defers to** `docs/workflow-contract.md`
for branching, gates, and the sacred-`dev` rule — follow them, do not restate.

**Argument:** the issue number `#N` (optionally a mode: `feature` adds behavior,
`fix` repairs a defect/regression/finding).

## Role

You are the lead session — the sole orchestrator. Do not edit code yourself.

## 0. Select the product profile (before intake)

Select the product profile against the target checkout and **state it on your first
output line**. Per [`profiles/README.md`](../../../profiles/README.md): Native
markers (`CONTEXT.md` + `docs/planning/decision-addendum.md` + `quality/project.json`)
→ `keiko-native`; `docs/design-system/` with Native markers absent → `keiko-web`;
ambiguous → **stop and ask**. **Load only the selected profile** and take the
Definition of Ready, verify command, templates, evidence model, branch/merge
authority, labels, and exclusions from it. Explicit operator selection overrides
detection.

## 1. Intake (Definition-of-Ready gate)

Fetch `#N` (body, labels, comments, linked PRs/children). Apply the **active
profile's Definition of Ready**. **keiko-web:** the issue must have acceptance
criteria + a verification command. **keiko-native:** it must be a machine-validated
accepted contract — a single `type:*` label, `status: ready` with a matching
readiness record (validated `Planning contract` version + fingerprint), and a
complete **Execution Authority** + **Quality Plan**; an instruction to consult the
private Fachkonzept or infer omitted requirements is a missing-requirement defect
(stop, return to planning). If missing/unready → triage first (comment the gap,
`status: new`), do not start. If it's an epic, use `keiko-epic`. If ambiguous or
conflicting with governance, stop and report.

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
- **User-facing component** change → `ui-engineer` builds against the active profile's UI standard (keiko-web: Keiko Design System `docs/design-system/`; **keiko-native:** `docs/planning/native-design-baseline.md`, evidence generated anew); `a11y-auditor` reviews **WCAG 2.2 AA** plus that standard's fidelity and the issue's **Acceptance Journey** checkpoints.
- Add `security-triage`→`security-auditor`, `performance-engineer`, `a11y-auditor`, `architect`, `docs` only when the changed surface creates that risk.
  Assign explicit, disjoint file ownership before any write agent starts.

## 4. Implement

Quality bars (per contract): complexity ≤10, function ≤50 LOC, file ≤400 LOC,
no `any`, TDD for new behavior, mandatory 2-pass self-critique. Issue-scoped only;
no unrelated refactors, TODOs, or placeholders. **User-facing components** conform
to the active profile's UI standard (keiko-web: Keiko Design System — semantic/
component tokens only, full `state-matrix.md` coverage, governance change-rules;
**keiko-native:** `native-design-baseline.md`, satisfying the issue's Acceptance
Journey). In **keiko-native** honor the issue's frozen **Execution Authority** (write
scope, delivery target, prohibitions) and **never** store/quote/request the private
Fachkonzept. Out-of-scope blockers → report up, the lead files a linked issue
(`status: new`); never expand scope.

## 5. Verify, audit, ship (per contract — sacred-`dev`)

1. **Verify-green loop.** Run `.keiko-scripts/verify-receipt.sh #N` — it runs the
   **active profile's verify command** (keiko-web: `verify.sh`, the CI mirror;
   **keiko-native:** `npm ci --ignore-scripts && npm run quality && npm audit
--audit-level=high` on Node 24.18.x) and writes the verify receipt **only if
   green**. If red, fix and re-run, **looping until green** (bounded by 3 distinct
   attempts → escalate). The PR-create **verify-gate** blocks `gh pr create`/`gh pr
ready` until a green verify receipt exists at HEAD.
   **Cross-layer issue (spans ≥2 layers/packages):** a green unit suite is _not_
   sufficient — tests have passed while production wiring was broken (e.g. a
   composition silently dropping a configured Model-Gateway URL). Beyond tests, the
   verify-green loop must cover **root typecheck**, the **architecture check**, a
   **non-test production-composition build** (the real wiring compiles/loads, not
   just fixtures), and **at least one real request-path smoke** exercising the actual
   production path end-to-end. (`codex:pre-pr` covers typecheck/arch/build; add the
   real request-path smoke explicitly.)
2. **Audit-clean loop.** Run `keiko-issue-audit` `#N` — mandatory. If it reports
   confirmed findings, fix them and re-audit, **looping until `findings=0`**
   (bounded by 3 attempts → escalate). The audit re-verifies and writes the audit
   receipt at HEAD as its last step. **User-facing issue:** also write a runnable
   Playwright plan, run it via `.keiko-scripts/ui-verify-receipt.sh #N -- <playwright cmd>`
   (it stamps the ui-verify receipt only on green), and post the PR comment marked
   **`<!-- keiko:manual-test-plan sha=<HEAD> -->`** (SHA-bound: name the exact
   commit; repost it whenever HEAD changes).
3. Branch off the base the profile names (keiko-web: `issue/<N>-<short>` off `dev`;
   **keiko-native:** a runner-prefixed source branch unique to the issue and
   **including its number**, off the frozen target the accepted issue names — never
   change that target); Conventional Commit referencing `#N`; `verifier` fills the
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
5. Open PR. **User-facing → handoff flow:** open it `--draft`, post the
   `<!-- keiko:manual-test-plan sha=<HEAD> -->` comment (the runnable Playwright
   plan), then `gh pr ready` — the **ready-gate** blocks `ready` until a comment
   naming the current commit exists.
   (Non-user-facing PRs open ready directly.) **Every merge into `dev` is
   human-gated + green CI** — never auto-merge to `dev`, never enable auto-merge.
   `pr-shepherd` drives CI/review to merge-ready; bounded CI repair (stop after 3
   distinct failed attempts). **Each CI-repair repush re-runs the QA:** the
   **push-gate** blocks a `git push` to an open `-> dev` PR unless fresh verify +
   clean-audit (+ ui-verify) receipts exist at the new HEAD — and, for a
   user-facing PR, the `keiko:manual-test-plan sha=<HEAD>` comment reposted for the
   new commit — so fix → re-run the loops → repost the comment → push.
6. Set `Workflow State` = `PR Open` → `Ready for Human Review`; flush
   current-state + next-action to the issue/PR.

## Escalate (stop, report)

Security-sensitive change; breaking public API; data/schema migration; >10% perf
regression; scope >2×; 3 distinct failed CI repairs; security-auditor critical/high.

## Final report

Issue · team used + why · files changed · tests/checks run · `keiko-issue-audit`
status · PR + `ci` status · board fields · residual risks/follow-ups.
