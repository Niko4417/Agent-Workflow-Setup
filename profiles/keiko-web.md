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
verification command; missing either → triage first. Accepted `New`/`Triaged`
issues meeting those requirements are executable (the target epic template uses
both states for executable children). Actual `Blocked`/`Waiting for User` states
require resolution or the requested decision before resuming. Acceptance criteria +
verification together cover the test dimensions (happy path, negative paths,
accessibility + design-system fidelity, security/governance, integration).

## Verify command

Run the target's current applicable local checks directly, or use the optional
`.keiko-scripts/verify.sh` runner from the target root. ADR-0145 targets use
individual minimum-loop and touched-area commands, including mandatory local
Sonar, without reviving retired aggregates. Select semantic gates from the target
contract/accepted Quality Plan with repeatable `--also <checking-script>`.
Package-surface assembly runs last because it prunes live dependencies. `--fast`
is a smoke and does not replace required checks. Report actual results and the
exact current PR head in the PR body or comment after independent audit.

## Templates (target-owned)

- `.github/ISSUE_TEMPLATE/epic.md`, `.github/ISSUE_TEMPLATE/feature_task.md`
- `.github/pull_request_template.md`

## Branch & merge model

Use ordinary `git`/`gh` commands from the deliberately chosen target workdir;
see [pre-PR process](../docs/delivery-preflight.md).

- Base branch `dev`; long-lived `epic/<name>` or `codex/epic-<name>` off `dev`;
  child `issue/<id>-<name>` or `codex/issue-<id>-<name>` off the epic branch.
- **Target-owned `dev` delivery** — Keiko ADR-0135 permits agents to arm native
  auto-merge for accepted work after the full app-bound required-check matrix is
  green on the exact current head and all review conversations are settled.
  Direct pushes, force pushes, and gate bypasses remain forbidden. Honor an
  explicit procedural final epic review hold; otherwise use human final review only where
  the target/user has not authorized another path.
- **Integration baseline** — evaluate the applicable current-HEAD integration run.
  ADR-0178's canonical resolver may reuse a complete successful PR run for the
  exact merged PR's byte-identical tree; record the integration run and evidence
  identity. Coverage and SonarCloud branch analysis still execute on every `dev`
  push. Missing/unproven evidence or a failed executed check remains blocking.
  Reuse applies only to integration runs, never to a required PR check.
- **child → accepted epic branch auto-merge** — applicable local checks,
  independent audit and required UI journeys are complete and reported at the
  exact PR head; the full target required-check matrix is green and reviews are
  settled. Use `gh pr merge <N> --auto --squash --match-head-commit <exact-head-sha>`.

Epic-branch server-side protection follows the target contract; stronger
protection is optional unless required there. Its absence alone does not block
this workflow or waive the full child quality matrix.

## Evidence model

- PR body/comment: exact current head, actual local command and independent audit
  results, accepted UI journey results, CI links and limitations.
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
