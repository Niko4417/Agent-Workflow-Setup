---
name: keiko-grill-epic
description: Turn a rough Keiko feature idea (or an existing epic) into an implementation-ready GitHub epic with scoped child issues, through one evidence-first grilling session. Use when planning a Keiko epic, stress-testing feature scope, converting a product idea into child issues, or hardening an epic before implementation. Inspects current dev, ADRs, templates, styleguide, security guardrails, code, and GitHub metadata before asking; asks only product, UX, policy, risk, or scope questions that project evidence cannot answer.
---

# keiko-grill-epic

Turn a rough Keiko feature idea into an implementation-ready parent epic plus scoped child issues, through one evidence-first grilling session. **Upstream of `keiko-epic`**: this skill _creates or hardens_ the epic package; `keiko-epic` later _executes_ a ready epic. **Defers to** `docs/workflow-contract.md` for the delivery model, quality bars, and guardrails — do not restate contract rules.

**Input:** a rough feature idea (→ new epic), or an existing epic number `#E` to harden.

## Core rule

No question cap. Unlimited useful questions, zero self-answerable ones. Classify every question before asking:

- `ask user` — product, UX, policy, business priority, scope, risk acceptance, rollout
- `inspect` — answerable from code, ADRs, templates, styleguide, GitHub metadata, or behavior
- `defer to issue` — implementation detail that belongs in a child issue; no scope/risk change
- `out of scope` — belongs in a follow-up epic or an explicit non-goal

Ask the user only `ask user` questions. `inspect` → examine and decide. `defer to issue` → write the constraint into the child issue. `out of scope` → preserve it on the parent epic as a deferred follow-up. If the user keeps answering "yes", stop and audit the line of questioning; continue only if the next answer changes scope, UX, policy, trust, rollout, or slicing.

## Evidence pass (before grilling)

Sync first: ensure the local checkout reflects the latest `origin/dev` (fetch/sync) so all evidence is current — never reason from a stale base or from memory. Then inspect, treating current code/templates/ADRs/styleguide as higher authority than older examples or chat memory:

1. `.github/ISSUE_TEMPLATE/` and `pull_request_template.md` — current templates override older examples.
2. Relevant ADRs, guardrail/security/product docs, design-system guidance, existing feature patterns.
3. Relevant code paths on current `dev`.
4. Strong completed epics/child issues for the quality bar — reconciled against current templates and behavior.
5. GitHub metadata when hardening an existing epic: parent-child links, labels, project fields, comments, body.

## Grilling discipline

Apply `grill-me` principles inside Keiko guardrails:

- One question at a time; include a recommended answer and why the decision matters.
- Walk the decision tree to shared understanding.
- Never ask what inspection can answer; never ask confirmations the contract/ADRs already imply.

Good: "Should v1 include text selection/copy, given governance implications?" · "Should a recoverable citation failure open an in-viewer recovery state, or only an inline chat error?" · "Is this follow-up part of v1, or a later epic?"

Bad: "Should the API accept `chatId + assistantMessageId + marker`?" · "Should we reuse the window config sanitizer?" · "Should the issue use the current template?" → inspect and encode the answer into the epic or child issue.

## Scope control

Define the smallest useful, shippable v1 — not a platform rewrite. Challenge every expansion against user value, implementation risk, ADR alignment, governance, and whether it should be a follow-up epic. Preserve out-of-scope ideas on the parent epic so they are not lost. If the idea needs multiple epics, say so and split it.

## Slicing into child issues

Use `to-issues` for the slicing **method only** — thin tracer-bullet vertical slices (each a complete path through every layer, independently verifiable), created in dependency order (blockers first). Its "quiz the user" step is **subordinated to the Core-rule classify-gate**: derive dependencies and sequencing by inspection; ask the user only slicing questions that change scope, UX, policy, or risk.

For every cross-child dependency, define the **interface contract** (inputs, outputs, types, error/empty states) in both issues, so the dependent slice is built against a stable boundary.

Author every issue with the **Keiko templates** (`epic.md` for the parent, `feature_task.md` for children). `to-issues`' minimal body is _not_ Keiko-compliant — it omits the reuse gate, board workflow, verification gates, stop conditions, and epic linking. One parent epic + child issues; declare dependencies; prefer one PR per child; children target the epic branch, not `dev` (see contract).

> Requires the `to-issues` skill (personal skill store). If unavailable, apply the same vertical-slice method inline.

## Definition of Ready (exit criterion)

Every child issue must satisfy the workflow Definition-of-Ready gate (`docs/workflow-contract.md` §1) so `keiko-issue`/`keiko-epic` can pick it up: acceptance criteria + a verification command, and the issue claimable (unassigned). Encode each technical unknown as an inspected, answered fact or as an explicit child-issue constraint — never leave it as an open user question the project could have answered.

## GitHub hygiene

Use the current templates for the epic and every child. Link children as GitHub sub-issues (not just body links). Set labels, classification, project fields, and priority per current conventions. Use comments only for temporary planning; fold useful planning into the bodies and remove clutter before finishing. Verify final state: bodies, parent-child links, project fields, dependencies, readiness. If you draft locally first, mark it temporary and remove it once the GitHub bodies are the source of truth.

## Escalate (stop, report)

The idea needs splitting across multiple epics · a required product or architecture decision is missing and cannot be inspected · the idea contradicts an ADR or guardrail · scope cannot be made shippable without weakening architecture, security, evidence semantics, or deterministic verification.

## Final output

Parent epic link (or draft path) · child issue links + dependency order · major scope decisions · deferred follow-ups preserved on the epic · verification/audit expectations · remaining product decisions, if any · confirmation that technical unknowns were inspected or placed in the right child issue. Do not claim implementation readiness until the issue bodies themselves contain the decisions, acceptance criteria, verification expectations, and audit/closure requirements.
