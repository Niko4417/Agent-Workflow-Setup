# Debug Team — Adversarial Root-Cause Analysis

**Use case**: a bug with an unclear root cause, where a single investigator would anchor on the first plausible theory. Parallel adversarial investigation fights this.

**Members**: 3 read-only teammates, each gathering bounded evidence for a
different hypothesis. The Opus lead owns broad causal reasoning and synthesis.

| Teammate | Subagent type | Model | Hypothesis lens |
|----------|---------------|-------|-----------------|
| `h1` | `explorer` | Haiku 5.5 / medium | Most likely cause from the bug-report symptoms |
| `h2` | `explorer` | Haiku 5.5 / medium | Second-most-likely cause, deliberately different from h1's track |
| `h3` | `explorer` | Haiku 5.5 / medium | "Wildcard" hypothesis — an indirect cause (data state, race, env, dep version) |

**Cost**: 3× Haiku 5.5 / medium for bounded evidence lookup. Escalate broad,
ambiguous root-cause reasoning to Opus 5.5; keep each lookup prompt within 100K
tokens where possible to avoid Haiku's higher pricing tier.

## Why this beats a single investigator

Sequential investigation suffers from **anchoring**: once an explorer finds a plausible explanation, subsequent steps bias toward it. With three independent investigators actively trying to disprove each other's theories, the theory that survives is much more likely to be the actual root cause (per [Claude Code agent-teams docs](https://code.claude.com/docs/en/agent-teams)).

## Spawn prompt

```text
A bug is reported: <ONE-PARAGRAPH-DESCRIPTION>.
Symptoms observed: <CONCRETE-SYMPTOMS>.
Reproduction steps: <STEPS-OR-"NOT-YET-REPRODUCIBLE">.

Create an agent team of 3 teammates to investigate this with a scientific
debate. Each teammate is read-only and uses the explorer subagent type. Their
job is not just to investigate their own theory but to actively disprove
the others' theories. Give each a bounded file/search surface and explicit
evidence checklist. They gather evidence; escalate architectural, auth,
migration, or concurrency interpretation to Opus before accepting a diagnosis.
Spawn:

- Teammate "h1": Investigate the most likely cause given the symptoms.
- Teammate "h2": Investigate a different track — do not overlap with h1.
- Teammate "h3": Investigate a wildcard hypothesis — indirect causes such as
  data-state corruption, race conditions, environment drift, dependency
  version mismatch, or recently merged unrelated PRs.

Have them talk to each other (via the team mailbox) to challenge each
other's findings, like a scientific debate. After 2-3 rounds of debate,
synthesise the surviving theory into a findings document with file:line
evidence and a proposed fix. Do not implement the fix — that is a separate
spawn (developer or implementor).
```

## What the lead does after

1. Read the synthesised findings document.
2. Sanity-check: is the evidence at file:line actually present?
   The Opus lead validates the causal explanation; Haiku lookup alone is not
   sufficient for a broad or consequential diagnosis.
3. If the theory is confirmed, spawn `developer` (or `implementor` for a known-pattern fix) to implement.
4. If no theory survives the debate, broaden the search: more hypotheses, more codebase areas, or escalate to user with the disproofs as artifacts.
5. Clean up the team.

## When NOT to use

- **Bug is obvious**: don't waste 3 agents on a typo or off-by-one.
- **Bug requires reproduction first**: if you cannot reproduce the bug locally, no investigator can verify a theory. Reproduce first, then debate.
- **Bug is environment-specific** and only manifests in CI/prod: spawn a single explorer to gather the env diff first; team-debate after.

## Anti-patterns

- **Don't** let teammates collaborate too early — anchoring returns if they share a working theory before independent investigation.
- **Don't** force all three to investigate the same area — defeats the parallelism.
- **Don't** skip the debate phase — that is where adversarial pressure actually surfaces the right answer.
- **Don't** implement during the debate — read-only investigation only.
