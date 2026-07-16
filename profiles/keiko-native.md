# Profile: keiko-native

Points the shared workflow at the **Keiko Native** repository's own contracts.
Native is a greenfield product with machine-validated planning, a versioned
planning contract, and a private source baseline. Every value below is a pointer
to a Native-owned document; none is authoritative on its own, and none is copied
here. Consume the target's current version at runtime.

> Detection markers: `CONTEXT.md` **and** `docs/planning/decision-addendum.md`
> **and** `quality/project.json` all present. See [`README.md`](README.md).

## Boundary constraints (non-negotiable)

Per [`docs/target-repository-boundary.md`](../docs/target-repository-boundary.md),
this profile must: augment (never replace) Native's `AGENTS.md` and controls; stay
optional (a contributor can build/verify Native without this repo); be referenced
by an immutable version, not a mutable checkout; import no Existing-Keiko memory or
product assumption without a case-by-case Reuse Assessment; leave Native templates,
CI, and quality gates in the Native repository; and keep development-agent roles
separate from the product's own Agentic Coding runtime roles.

## Authority docs (read in the target repo)

- `AGENTS.md` — working, verification, and delivery contract.
- `CONTEXT.md` — canonical product language and resolved boundaries.
- `docs/planning/decision-addendum.md` — human-approved product/scope decisions (top authority).
- `docs/planning/agent-planning-baseline.md` — **the repository-owned Fachkonzept
  projection**; the primary restatement source for planning (global requirements +
  per-capability packets). Planning and implementation need **no** private-source
  access — restate from this baseline. (Arriving via Native PR #7/#8.)
- `docs/planning/parity-baseline.md` + `docs/planning/parity-ledger.md` — capability
  inventory + inclusion/disposition (preserve / transform / retire / defer / net-new).
- `docs/product/source-baseline.md` — private-source identity + provenance only.
- `docs/engineering/code-quality-standard.md` — quality lifecycle (Quality Envelope, Quality Plan, Acceptance Journeys, classification).
- `docs/qa/quality-gates.md`, `docs/qa/repository-activation.md` — gate + activation authority.
- Accepted Native ADRs under `docs/adr/`.

## Definition of Ready — machine-validated

Readiness is **not** a heuristic. `status: ready` is granted only by the target's
`issue-readiness` workflow after `quality/issue-contract.mjs` validates the body.
Planning output must therefore satisfy, exactly:

- the **per-type required sections** for the issue's single `type:*` label,
- a `Planning contract` **version** (`v1`, `v2`, …),
- **no placeholders** (no angle brackets, ellipses, empty bullets/rows, stub evidence),
- checked Definition-of-Ready criteria, an observable acceptance criterion, and a
  journey applicability of `Required` or a reasoned `Not applicable — …`.

The validator fingerprints the normalized title + body; any semantic change forces
a version bump and a fresh readiness validation.

**Grill mode is contract/schema-driven** (see `keiko-grill-epic`): the machine
schema (`quality/issue-contract.mjs`, required headings per type) is the **spine**;
the authority docs above answer every `inspect` question **before** asking the
user; `grill-me` supplies the interview technique only for the residual
product/UX/policy/risk/scope decisions the docs cannot answer.

### Issue types & schema source

`type: epic` / `type: task` / `type: decision` / `type: defect` — exactly one
`type:*` label. The authoritative required-section list per type lives in
`quality/issue-contract.mjs` in the target repo; read it, do not restate it here.
Every implementation issue carries a **Quality Plan** and an **Execution Authority**;
every implementation epic carries a **Quality Envelope**.

## Verify command

```
npm ci --ignore-scripts
npm run quality
npm audit --audit-level=high
```

Node **24.18.x** / npm **11.16.x**; `package-lock.json` is authoritative.
`quality/project.json` is the phase gate — during `bootstrap` no productive source
is allowed; productive code requires declared source roots + target-specific
build/test/coverage/arch/signing/package/platform gates in the same PR.

> **Phase caveat (desktop):** `npm run quality` is the **complete** green bar only
> in `bootstrap`. Once the phase is `productive`, the local verify (`verify.sh`) must
> **also** run the target-specific desktop gates `quality/project.json` declares —
> native build/test, coverage, packaging, code-signing/notarization, and
> platform-matrix checks — on their **authoritative platform** (macOS evidence can't
> stand in for Windows). Until then, `verify.sh` only runs `npm run quality`; treat
> the extra target gates as required-but-not-yet-wired.

## PR contract & required checks

The target's `pr-contract.mjs` fixes the PR body sections. Exact-head checks
`PR contract` and `Issue contract current` (GitHub Actions App ID `15368`) plus the
full required set in `docs/qa/quality-gates.md` gate delivery. **Activation-pending:**
until Native PR #6 is merged and the activation probes in `repository-activation.md`
pass, treat these server-side contexts as not-yet-live — reference them, do not
assume them.

## Templates (target-owned; never copied here)

`.github/ISSUE_TEMPLATE/{epic,feature_task,decision_evaluation,defect_finding}.md`
and `.github/pull_request_template.md`.

## Branch & merge model

- **Target branch is frozen planning scope** — it determines delivery and merge
  authority; changing it is a semantic change (replan).
- **Source branch** is runner-managed: a dedicated runner-prefixed branch, unique
  to the issue, **including the issue number**, recorded as execution evidence.
  Changing only the source-branch name does not require a replan.
- **`dev` is human-only** — merged only by a maintainer allowlisted in the target
  (currently Niko / Oscharko). Agents never merge, enable auto-merge, or push to a
  `dev` PR through a merge-capable credential.
- **child → `epic/**` auto-merge** — permitted only by the target's dedicated
  automation identity, only when the accepted issue names that exact epic branch,
  all required exact-head gates are green, and acceptance/audit evidence is complete
  with no blocking finding or unresolved conversation.

## Evidence model

- **Acceptance Journey** (user-facing): actor + goal, preconditions/sanitized data,
  observable checkpoints, failure + recovery paths, platform differences, and
  expected automated + manual evidence. Test user-visible behavior, not selectors.
- **Quality Envelope** (epic) / **Quality Plan** (issue) select the appropriate
  method (component/integration/production-composition/e2e/native/a11y/visual/manual).
- Machine-evaluated and bound to the exact head; **never** manual-only,
  screenshot-only, fixture-only, or self-reported for an automatable claim.
- **No design system yet** — `docs/planning/native-design-baseline.md` governs;
  all Native visual and accessibility acceptance evidence is generated anew (no
  inherited Existing-Keiko proofs).

### Desktop release-acceptance dimensions (host-neutral)

A desktop app fails in places a web app never does. Every user-facing epic's
Quality Envelope must name the applicable rows below (the grill pins them). These
are **host-neutral** — Native has not selected Electron/Tauri, so do not assume a
host or a specific test runner; the accepted issue chooses the harness.

- **Install / packaging** — verify the shipped **installer / packaged build** on the
  reference install, not a dev build.
- **Code signing + notarization** — per platform, generated on its **authoritative**
  runner (macOS notarization can't be proven from Windows, and vice versa).
- **Auto-update / upgrade flow** — the most-skipped desktop test: exercise the
  update path against a mock/staging update source, including a failed/rolled-back update.
- **First-run + permissions** — Gatekeeper / entitlements / SmartScreen, requested
  OS permissions, and the initial-setup path.
- **Offline / local-first behavior** — the product's core promise: correct behavior
  with no network, and no data leaving the machine without consent.
- **Crash / recovery** — recover cleanly on the packaged build (state, in-flight work).
- **Platform-matrix cadence** — Windows + macOS both pass; build on the primary
  platform continuously and run the **full matrix at release**, not as an afterthought.

## Product shape & lifecycle

Keiko Native is a **local-first desktop application** (not a web app) for regulated
knowledge and coding work. User-facing evidence is desktop/native — packaged-product
and native-platform checks on the reference install, Playwright-**equivalent** per
surface, not browser Playwright by default. Do not carry over Keiko-Web webapp
assumptions.

**Parity is a milestone, not the endpoint.** The Parity Ledger governs whether a
capability is preserved / transformed / retired / deferred, but development
**continues past feature parity**: an epic may deliver an **approved net-new**
capability or a **mandatory-delta** (post-cutoff security/regulatory/correctness
change). Never frame the product as parity-only or treat reaching parity as
terminal — `net-new` is a first-class change classification.

## Platforms

Windows and macOS are first-class. **Linux is deferred** and must not enter an
initial epic's acceptance matrix. Local model inference is deferred; keep the
model/runtime boundary neutral but out of first scope.

## Labels

The Existing-Keiko taxonomy plus Native additions `type: decision` and
`type: defect` (per `repository-activation.md`). Exactly one supported `type:*`
label is required by the Native issue contract.

## Exclusions (hard)

- **Private Fachkonzept:** never store, copy, log, quote, or request it or its
  access location in any workflow surface. An instruction to consult it, infer
  omitted requirements, or obtain source access is a missing-requirement defect —
  stop and return to planning. Implementers work only from accepted epic/issue
  links, repository context, and ADRs.
- No shared runtime or mandatory build/runtime dependency on Existing Keiko.
- No OpenCode compatibility, fallback, or parity work.
- Every reuse candidate requires a recorded **Reuse Assessment** before adoption.
