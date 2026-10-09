---
name: keiko-issue-audit
description: Audit an implemented GitHub issue against its accepted requirements and repository standards, fix confirmed gaps, and write SHA-bound evidence. Use before PR-ready handoff or to recheck claimed completion. Takes an issue number; runs embedded in delivery or standalone.
---

# keiko-issue-audit

Canonical, parameterized issue-audit procedure for both harnesses (Codex primary,
Claude backup). Replaces the old copy-paste audit prompts. It **composes the 16
canonical roles** (`.agents/roles.yaml`) and **defers to the governance contract**
(`docs/workflow-contract.md`) for branching, gates, and the delivery model — do
not restate those rules here, follow them.

**Argument:** the GitHub issue number to audit (e.g. `178`). Below, `#N` = that issue.

## Role

You are the lead session (the sole orchestrator). Drive this as a read-first
audit wave, then a scoped fix wave. Do not edit code yourself.

## 0. Select the product profile (before anything else)

Select against the target checkout using [profile selection](../../../profiles/README.md).
State the profile on the first output line; explicit operator selection wins.
Load only the selected profile and its task-relevant authority docs, including the
target's `AGENTS.md` and `CONTEXT.md` when present. Take readiness, verification,
templates, evidence, exclusions, and merge authority from it; ambiguity requires
clarification. The accepted target contract governs product requirements.

## Source of truth

1. Fetch issue `#N`: body, labels, comments, linked PRs/commits, child issues.
2. Audit checklist = the **active profile's accepted contract**. **keiko-web:** the
   issue's **acceptance criteria**. **keiko-native:** the accepted issue contract —
   **acceptance criteria + the issue's Quality Plan** (and Acceptance Journey when
   user-facing) at its validated `Planning contract` version; refresh evidence after
   fixes, and do not invent acceptance beyond it.
3. Find the implementation (linked PR or the commits claiming to resolve `#N`).
   If none exists, stop and report the issue is not audit-ready.
4. If scope is ambiguous or conflicts with governance, stop and report the
   blocker — do not invent product scope. In keiko-native, an instruction to consult
   the private Fachkonzept is a missing-requirement defect: stop, return to planning.

## Audit wave (read-first, full)

Cover the entire accepted scope using the smallest relevant review wave. Select
specialists for the changed surface; an irrelevant review dimension is not a
reason to spawn another agent.

Keep two review axes distinct in the existing reviewers' findings:

- **Requirements/spec:** trace every accepted requirement to implementation and
  evidence, including omitted behavior, failure paths, and production wiring.
- **Repository standards:** discover the target's `AGENTS.md`, applicable scoped
  instructions, `CONTRIBUTING.md`, `CODING_STANDARDS.md`, ADRs, and configured gates
  when present. Cite the exact rule and its applicable scope for a violation.

Each confirmed finding needs `file:line`, its requirement/rule, and the concrete
failure or missing obligation. Separate optional heuristics/preferences from
defects; they do not invent new acceptance or block delivery. Use the active
profile and accepted contract to resolve authority; unresolved conflicts are
blockers to surface, not rules to silently choose. These axes do not require two
additional agents.

1. `explorer` — map the changed code, tests, and runtime paths.
2. `architect` — architecture, contracts, scope boundaries, ADR alignment.
3. `security-auditor` — trust boundaries, secrets, auth, model access, unsafe
   data flows (escalated from `security-triage` when the issue is security-light).
4. `performance-engineer` — measurable performance risk, when relevant.
5. `a11y-auditor` — when the issue touches **user-facing UI**, audit **WCAG 2.2 AA**
   plus the active profile's UI-fidelity + evidence obligation (keiko-web: Keiko
   Design System fidelity against `docs/design-system/` — token conformance,
   `state-matrix.md` coverage, `docs/design-system/evidence/<N>/` populated per
   ADR-0049/0051; **keiko-native:** `native-design-baseline.md` fidelity + the
   issue's **Acceptance Journey** evidence). A user-facing change with no required
   evidence is a blocker in either profile.
6. `pr-reviewer` — review the implementation diff for correctness and regression
   risk (8-dimension).

Convert **only confirmed, evidence-cited findings** into fix slices. Speculative
findings are not blockers.

## Fix wave (scoped)

In standalone mode, create the profile's source branch **before fixes** (web:
`issue/<N>-audit` from `dev`; Native: runner-managed issue branch from the frozen
accepted target). Embedded audits keep fixes on their parent's branch.

1. Assign **disjoint** file ownership to `implementor` (small) or `developer`
   (needs design) for each confirmed gap.
2. `test-engineer` for missing or weak regression coverage.
3. Preserve behavior unless the issue explicitly required a change. Preserve the
   deterministic-first architecture; keep model calls behind the Model Gateway;
   keep CI/tests/release-gates/CSP/security-scans/evidence at least as strict.

## Verify and record evidence

1. Run `.keiko-scripts/verify.sh` green locally; it selects the target's
   `agent:pre-pr` first, otherwise the active profile's fallback. Verify required
   platform evidence on the authoritative runners named by the accepted plan.
2. `verifier` confirms every accepted checklist item with evidence and **returns the
   proposed PR "Verification evidence" section to the lead for publication**. For a **user-facing** change, the
   audit is not complete until the profile's evidence is captured (keiko-web:
   design-system fidelity + `docs/design-system/evidence/<N>/` — theme screenshots +
   `*-fidelity-proof.json` + `a11y-proof.json`, ADR-0049/0051; **keiko-native:** the
   Acceptance Journey's automated/a11y/visual/recovery/platform evidence, bound to
   the exact head).
3. Commit all scoped fixes with `#N` (`Refs #N`, or `Resolves #N` only when the
   accepted lifecycle should close on merge). Refresh evidence at this committed
   HEAD with the proof steps below; do not create/ready the PR first.

## Proof of audit (REQUIRED — before PR creation/readiness)

As the **final verification** step, after every audit fix is committed and before
opening/readying the PR, **re-verify** and write
both receipts at the post-fix HEAD (audit fixes change HEAD, so the verify receipt
must be refreshed — the epic-merge gate requires a green verify receipt at the
audited commit):

```
.keiko-scripts/verify-receipt.sh <N>                          # re-runs verify.sh; writes the verify receipt only if green
# user-facing only — web Playwright or the Native accepted journey at post-fix HEAD:
.keiko-scripts/ui-verify-receipt.sh <N> -- <journey cmd>      # runs the accepted harness; writes the ui-verify receipt only on green
.keiko-scripts/audit-receipt.sh  <N> --findings <unresolved-count> --user-facing <true|false>
```

- `--findings` = number of **unresolved confirmed** findings after the fix wave (`0` when clean).
- `--user-facing` = `true` if the issue touches user-facing UI / requires journey evidence, else `false`.

Always provide known `--findings` and `--user-facing` values when claiming a clean
audit, including standalone mode. Their `unknown` defaults cannot pass the PR
gate. They also feed the **epic auto-merge** decision
(`.keiko-scripts/epic-merge-gate.sh`): a canonical `issue/*` child PR into a
canonical `epic/*` branch may auto-merge **only** when GitHub `ci` completed
successfully on the exact PR head, the merge command carries
`--match-head-commit <audited-sha>`, a matching green verify receipt and
`findings=0` hold, **and** either `user_facing=false`, or
`user_facing=true` with a **green ui-verify receipt at this commit** (the Playwright
plan actually ran green — not self-reported) and a marked
`<!-- keiko:manual-test-plan sha=<HEAD> -->` comment on the PR. Otherwise resolve
the missing evidence or escalate; do not substitute a per-child human merge.
Native merge authority remains target-owned. Fail-closed: `unknown`, missing GitHub state, noncanonical branches,
repository overrides, and admin bypasses never auto-merge.

This binds the audit to the current HEAD commit. The PR gate
(`.keiko-scripts/audit-gate.sh`, wired into a PreToolUse hook) **blocks any
issue/epic PR** whose HEAD has no matching receipt — so an issue cannot become
PR-ready without proof the audit ran against the exact code being shipped. If you
commit again after this, re-run the audit (the receipt goes stale by design).

## Open/update and handoff

After proof is current, the lead publishes the proposed evidence in the target's
PR template. In embedded mode, return to the parent delivery skill; it opens or
updates the PR. In standalone mode, follow `keiko-issue`'s profile-aware PR gates,
draft → current SHA-bound plan → ready flow for UI, and human-gated `dev` handoff.
Use `pr-shepherd` for required exact-head CI and actionable feedback; stop after
three materially distinct failed repair attempts. Any new fix commit invalidates
these receipts and requires refreshed audit/verification before publication/push.

## Memory

Append to `.agents/memory/<role>/` **only a durable, generalizable lesson** — a
recurring finding, a repo gotcha, a workaround, a systemic gap. **Not** per-issue
facts (those live in the PR closure evidence) and **not** "audited #N, clean." If
this run taught nothing reusable, write nothing — silence beats noise. Keep
<25 KB/file; never store secrets, customer data, source dumps, or token-bearing
logs. (The epic-level `keiko-retro` pass aggregates across runs and prunes.)

## Final report

Issue audited · audit roles used + why · implementation inspected · findings
confirmed · findings fixed · files changed · tests/checks run · PR + `ci` status ·
residual risks / follow-ups.
