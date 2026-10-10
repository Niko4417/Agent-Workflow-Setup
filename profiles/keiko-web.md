# Profile: keiko-web

The default profile. It follows the target's current Keiko (Web) contract. Every
value below points at the **target repository's own** contracts;
nothing here is authoritative on its own.

> Detection markers: `docs/design-system/` present, Native markers absent.
> See [`README.md`](README.md) for the selection order.

## Authority docs (read in the target repo)

- `AGENTS.md` and `CONTRIBUTING.md` — current contribution and delivery contract.
- Explicit user run choices override generic defaults; retain a requested final
  epic PR review hold without adding per-child approval.
- `docs/design-system/` — design system (tokens, `state-matrix.md`, `governance.md`).
- Relevant ADRs under `docs/adr/`.

## Definition of Ready

**Heuristic.** An issue is ready when it has acceptance criteria **and** a
verification command; missing either → triage first. Acceptance criteria +
verification together cover the test dimensions (happy path, negative paths,
accessibility + design-system fidelity, security/governance, integration).

## Verify command

Use `.keiko-scripts/verify.sh` from the target root. On targets that accepted
ADR-0145, it executes the current individual minimum-loop and selected touched-area
commands from `AGENTS.md`, including the mandatory local Sonar gate; it never
revives a retired aggregate. Older targets retain their existing compatibility
path. Delivery receipts require full verification of a clean, unchanged tracked
HEAD; `--fast` is a smoke run and cannot mint a delivery receipt. Select any
additional touched-area gates from the current target contract/accepted plan with
repeatable `--also <current npm checking script>` on `verify.sh` or
`verify-receipt.sh <N>`; the receipt runs and records those commands itself.

## Templates (target-owned)

- `.github/ISSUE_TEMPLATE/epic.md`, `.github/ISSUE_TEMPLATE/feature_task.md`
- `.github/pull_request_template.md`

## Branch & merge model

Delivery commands use the self-gating explicit-root entrypoint described in
[`delivery-preflight.md`](../docs/delivery-preflight.md). For example:
`python3 "/absolute/target/.keiko-scripts/delivery-command.py" --root "/absolute/target" -- git push -u origin codex/issue-123-task`.
Use actual literal absolute paths and the assigned branch. The dispatcher denies
raw delivery when the runtime omits the effective command directory; the entrypoint
checks proof itself and executes argv at the same validated Git root.

- Base branch `dev`; long-lived `epic/<name>` or `codex/epic-<name>` off `dev`;
  child `issue/<id>-<name>` or `codex/issue-<id>-<name>` off the epic branch.
- **Target-owned `dev` delivery** — Keiko ADR-0135 permits agents to arm native
  auto-merge for accepted work after the full app-bound required-check matrix is
  green on the exact current head and all review conversations are settled.
  Direct pushes, force pushes, and gate bypasses remain forbidden. Honor an
  explicit procedural final epic review hold; otherwise use human final review only where
  the target/user has not authorized another path.
- **child → accepted epic branch auto-merge** — the full current-head target required-check
  matrix, settled review findings, and matching SHA-bound verify/audit receipts.
  A user-facing child also
  needs a green `ui-verify-receipt` and a posted `keiko:manual-test-plan` comment.

Epic-branch server-side protection follows the target contract; stronger
protection is optional unless required there. Its absence alone does not block
this workflow or waive the full child quality matrix.

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
