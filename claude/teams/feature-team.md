# Feature Team — Cross-Layer Feature Delivery

Use when independent work across backend, UI and tests benefits from parallel
execution. The lead may implement a small task directly or own a disjoint slice.
Choose only the roles the accepted scope needs; this template is not a fixed roster.

| Teammate | Role | Model / effort | Example Keiko ownership |
| --- | --- | --- | --- |
| `dev` | `developer` | Opus 5.5 / high | Named domain files under `packages/` and composition files under `src/` |
| `test` | `test-engineer` | Opus 5.5 / high | Named co-located tests or cross-package / e2e files under `tests/` |
| `ui` | `ui-engineer` | Opus 5.5 / medium | Named component and CSS Module files under `packages/keiko-ui/` |

These are ownership examples, not broad write grants. Assign exact files after
inspection; test and UI scopes must not overlap another worker's files. Native
uses its own accepted paths, Quality Plan and Acceptance Journey.

## Before spawning

- Read the accepted spec, acceptance criteria and unresolved decisions.
- Assign disjoint files, dependencies, expected evidence and stop conditions.
- Resolve shared API contracts before dependent writes; sequence overlapping work.
- Select current target commands and platform checks. Keiko uses npm workspaces;
  its `AGENTS.md` owns the local minimum loop and applicable touched-area gates.
- Request a new decision only for unresolved scope/authority or product choices.
  Approved scope and ownership do not require another universal plan-approval round.

## Spawn prompt

```text
Implement the accepted slice of issue #<NUMBER> using the <ROLE> role.
Own only: <EXACT FILES>.
Dependencies: <ACCEPTED CONTRACT OR PREDECESSOR>.
You are not alone; preserve others' edits. Do not expand scope or delegate.
Verification: <CURRENT TARGET COMMANDS AND ACCEPTANCE CHECKPOINTS>.
Return changed files, actual command/journey results, and limitations.
Stop and report missing decisions, authority or conflicting ownership.
```

## Lead responsibilities

Verify dependency readiness and worker evidence, integrate the composition and
run applicable target checks. Complete the required independent issue audit and
accepted UI/platform journeys before delivery. Record actual results at the exact
PR head, then clean up the team. Lead writes must remain disjoint from active
workers; never overwrite their files.

Parallelism adds coordination cost; choose it for independent work, not to satisfy
a fixed team size or elapsed-time threshold. Detailed cost comparisons belong to
routing qualification or a requested experiment.
