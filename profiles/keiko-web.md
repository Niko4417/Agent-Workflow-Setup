# Profile: keiko-web

The default profile. It externalizes the workflow's original Keiko (Web) behavior
unchanged. Every value below points at the **target repository's own** contracts;
nothing here is authoritative on its own.

> Detection markers: `docs/design-system/` present, Native markers absent.
> See [`README.md`](README.md) for the selection order.

## Authority docs (read in the target repo)

- `AGENTS.md` — contribution contract.
- `docs/design-system/` — design system (tokens, `state-matrix.md`, `governance.md`).
- Relevant ADRs under `docs/adr/`.

## Definition of Ready

**Heuristic.** An issue is ready when it has acceptance criteria **and** a
verification command; missing either → triage first. Acceptance criteria +
verification together cover the test dimensions (happy path, negative paths,
accessibility + design-system fidelity, security/governance, integration).

## Verify command

`npm run verify` (the full CI mirror: typecheck, version-consistency, lint,
architecture checks, supply-chain check, tests). Where the target defines
`npm run codex:pre-pr`, prefer it as the canonical pre-PR script.

## Templates (target-owned)

- `.github/ISSUE_TEMPLATE/epic.md`, `.github/ISSUE_TEMPLATE/feature_task.md`
- `.github/pull_request_template.md`

## Branch & merge model

- Base branch `dev`; long-lived `epic/<name>` off `dev`; child `issue/<id>-<name>`
  off the epic branch.
- **`dev` is sacred** — every merge into `dev` (epic or standalone) needs a human
  reviewer **and** green GitHub CI. Agents never merge or enable auto-merge into `dev`.
- **child → `epic/*` auto-merge** — a completed successful exact-head GitHub `ci`
  check plus matching SHA-bound verify/audit receipts. A user-facing child also
  needs a green `ui-verify-receipt` and a posted `keiko:manual-test-plan` comment.

## Evidence model

- SHA-bound receipts: verify, audit, ui-verify (Playwright).
- User-facing changes: design-system **fidelity + a11y** evidence under
  `docs/design-system/evidence/<N>/` (ADR-0049 / ADR-0050 / ADR-0051), full
  `state-matrix.md` coverage, semantic/component tokens only.

## Platforms

Windows and macOS desktop behavior (native, frictionless).

## Labels

The Keiko issue-label taxonomy: `type: epic` / `type: task`, `status: *`, and
`area:x` (no space after the colon).

## Exclusions

None specific to this profile beyond the shared safety posture (no secrets,
customer data, or generated caches in source, logs, or evidence).
