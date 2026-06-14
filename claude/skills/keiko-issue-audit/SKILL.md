---
name: keiko-issue-audit
description: Audit a GitHub issue's implementation against its acceptance criteria with a read-first agent wave, fix confirmed gaps, and ship a green PR targeting dev. Use as the final pass before an issue is PR-ready / Ready for Human Review, or on demand to audit an already-claimed-done issue. Takes an issue number.
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

## Source of truth

1. Fetch issue `#N`: body, labels, comments, linked PRs/commits, child issues.
2. Treat the issue's **acceptance criteria as the audit checklist**.
3. Find the implementation (linked PR or the commits claiming to resolve `#N`).
   If none exists, stop and report the issue is not audit-ready.
4. If scope is ambiguous or conflicts with governance, stop and report the
   blocker — do not invent product scope.

## Audit wave (read-first, full)

Run the read wave; right-size each role to relevance, but default to running them.

1. `explorer` — map the changed code, tests, and runtime paths.
2. `architect` — architecture, contracts, scope boundaries, ADR alignment.
3. `security-auditor` — trust boundaries, secrets, auth, model access, unsafe
   data flows (escalated from `security-triage` when the issue is security-light).
4. `performance-engineer` — measurable performance risk, when relevant.
5. `a11y-auditor` — WCAG / UI risk, when the issue touches UI.
6. `pr-reviewer` — review the implementation diff for correctness and regression
   risk (8-dimension).

Convert **only confirmed, evidence-cited findings** into fix slices. Speculative
findings are not blockers.

## Fix wave (scoped)

1. Assign **disjoint** file ownership to `implementor` (small) or `developer`
   (needs design) for each confirmed gap.
2. `test-engineer` for missing or weak regression coverage.
3. Preserve behavior unless the issue explicitly required a change. Preserve the
   deterministic-first architecture; keep model calls behind the Model Gateway;
   keep CI/tests/release-gates/CSP/security-scans/evidence at least as strict.

## Verify & ship (follow the contract — do not duplicate gate wording)

1. Run `scripts/verify.sh` (the CI-mirror) green locally before the PR.
2. `verifier` confirms every acceptance criterion with evidence and **fills the
   PR body's "Verification evidence" section**.
3. Branch `issue/<N>-audit` off `dev`; Conventional Commit referencing `#N`.
   Use `Refs #N` when the audit does not close the issue, `Resolves #N` only when
   it should close on merge.
4. Open/update a PR per the contract's **sacred-`dev`** rule: green CI required;
   any `-> dev` PR is human-gated. `pr-shepherd` drives CI/review to merge-ready.
5. Bounded CI repair: stop after 3 distinct failed repair attempts and escalate.

## Memory

Read/append only durable lessons to `.agents/memory/<role>/` (<25 KB). Never
store secrets, customer data, source dumps, or token-bearing logs.

## Final report

Issue audited · audit roles used + why · implementation inspected · findings
confirmed · findings fixed · files changed · tests/checks run · PR + `ci` status ·
residual risks / follow-ups.
