# Feature Team — Cross-Layer Feature Delivery

**Use case**: a feature spans backend + frontend + tests, and the three layers can be implemented in parallel by different teammates without touching the same files.

**Members**: 3 writing teammates with strict file-ownership boundaries.

| Teammate | Subagent type | Model | Owns |
|----------|---------------|-------|------|
| `dev` | `developer` | Opus | Backend / service code: `services/**`, `libs/**` |
| `test` | `test-engineer` | Sonnet | All test files: `**/*.{test,spec}.{ts,tsx}`, `__tests__/`, `tests/`, `e2e/` |
| `ui` | `ui-engineer` | Sonnet | Component code: `apps/**/components/**`, `*.tsx`, `*.css` |

**Cost**: 1× Opus + 2× Sonnet ≈ **40% cheaper** than 3× Opus, comparable quality (see [Wave 2 routing rationale](../../CLAUDE.md)).

## Pre-flight checklist (lead does this BEFORE spawning)

1. **Spec exists**: a written spec with Acceptance Criteria, in the issue or in-conversation.
2. **File boundaries clear**: each teammate's files do not overlap. If they do, sequence the work instead.
3. **Plan approval required**: each teammate must submit a plan and wait for lead approval before implementing.
4. **Verification gate defined**: which `make` target or `pnpm` script proves the feature works end-to-end.

## Spawn prompt

```text
We have an approved spec for <FEATURE-NAME> (issue #<NUMBER>). Create an agent
team of three teammates to implement it in parallel. Each teammate must submit
a plan and wait for my approval before implementing. Use these subagent
definitions and file boundaries:

- Teammate "dev" using the developer agent type.
  Owns: services/**, libs/**. Backend logic + APIs.
  Must NOT touch: apps/**, **/*.test.ts, **/*.spec.ts.

- Teammate "test" using the test-engineer agent type.
  Owns: all test files matching **/*.{test,spec}.{ts,tsx} and tests/**, e2e/**.
  Must write tests for the new backend and UI behaviour.

- Teammate "ui" using the ui-engineer agent type.
  Owns: apps/**/components/**, related .tsx and .css.
  Must NOT touch: services/**, libs/**, test files.

Coordination rules:
- "dev" goes first (test and ui depend on the API contract).
- "ui" and "test" may run in parallel once the API contract is committed.
- Only approve plans that explicitly list the files the teammate will touch.
- Reject any plan that modifies files outside the teammate's owned scope.
- Verification gate: `make ci-checks` must pass before the team is done.
```

## What the lead does during

1. Review and approve each teammate's plan (or reject with feedback).
2. Watch for `dev` finishing the API contract — then unblock `test` and `ui`.
3. If a teammate gets stuck or proposes scope creep, redirect immediately.
4. Run `make ci-checks` after the team reports done.
5. Clean up the team.

## Anti-patterns

- **Don't** let two teammates own the same path. If you cannot draw a clean boundary, sequence the work with sub-agents instead.
- **Don't** spawn this team for tasks under ~30 minutes of total work — coordination overhead beats parallelism savings.
- **Don't** skip plan approval. Without it, three writing teammates can produce three incompatible designs in parallel.
- **Don't** assume teammates will read each other's commits — use the shared task list for cross-references.
