# Example workflow

Concrete prompts to give the orchestrator, the **real skill invocations** they
trigger, and what happens under the hood. The GitHub issue/epic is always the
source of truth — you give a number, not a spec.

## How invocation works

You can drive it two ways — both end up running the same skill:

- **Natural language:** `… resolve issue #178` → the orchestrator invokes the
  `keiko-issue` skill.
- **Explicit:** invoke the skill directly — `keiko-issue 178`.

**You do not need to ask for the audit.** `keiko-issue` and `keiko-epic` invoke
`keiko-issue-audit` themselves as a mandatory step. Invoke `keiko-issue-audit`
directly only for a standalone audit (Example C). It's an instruction in the
skill, not a hard gate, so the chains below show exactly where it fires — and if
you want belt-and-suspenders you can add "and run keiko-issue-audit before the
PR" to your prompt.

---

## A. Work a single issue

**Prompt:**

```text
Act as the orchestrator for Keiko and resolve issue #178.
Run the standard workflow end-to-end and stop only on a real blocker.
```

**Skill chain it runs:**

```text
keiko-issue 178
└─ keiko-issue-audit 178      ← fires automatically as the mandatory pre-PR-ready step
```

**What happens:**

- **Intake (Definition-of-Ready).** Fetches #178; confirms acceptance criteria +
  a verification command. If missing → triages first, doesn't start.
- **Claim.** Marks the issue `In Progress` on the delivery board, sets owner and
  `Human Review Required = Yes`.
- **Route (task-shaped).** Smallest effective team — `explorer` to map the code,
  then `implementor` (small) or `developer` (needs design); adds `security-*`,
  `performance-engineer`, `a11y-auditor`, `test-engineer` only if the changed
  surface warrants it.
- **Implement.** Branch `issue/178-<short>` off `dev`; quality bars enforced
  (no `any`, complexity ≤10, TDD); each agent runs a 2-pass self-critique.
- **Verify + audit.** `verify.sh` (local CI mirror) must be green; then
  **`keiko-issue-audit 178`** runs the read-first audit wave — mandatory even if
  it finds nothing.
- **Ship.** `verifier` fills the PR's evidence section; PR opens targeting `dev`;
  `pr-shepherd` drives CI/review to merge-ready.
- **Hand off.** Sets `Ready for Human Review`. **Stops there** — a human merges to
  `dev`. Nothing auto-merges into `dev`.

---

## B. Work a multi-issue epic

**Prompt:**

```text
Act as the orchestrator for Keiko and run epic #532 to a closure-ready state.
Process children in dependency order, parallelize only where it's safe, and hand
me one green epic PR for review.
```

**Skill chain it runs:**

```text
keiko-epic 532
├─ keiko-issue 533  └─ keiko-issue-audit 533     ┐ per child, on a branch off the
├─ keiko-issue 534  └─ keiko-issue-audit 534     ┘ epic branch; auto-merge child→epic
└─ keiko-issue-audit 532                          ← final audit of the integrated surface
```

**What happens:**

- **Plan.** Fetches #532 and its children; classifies each `ready` / `blocked` /
  `done` / `needs-triage`; respects required order; flags safe parallelism (only
  disjoint file ownership, no ordering dependency).
- **Epic branch.** Cuts one long-lived `epic/<name>` off `dev`; records it on the
  board.
- **Child loop.** For each ready child, runs **`keiko-issue <child>`** (which runs
  its own **`keiko-issue-audit <child>`**) on a branch off the epic branch. Each
  child PR targets the **epic branch** and **auto-merges on green CI** (the only
  auto-merge in the system) — no human per child. Re-syncs `dev` regularly.
- **Heartbeat.** Posts a one-line status at each child/milestone and flushes state
  to GitHub so either harness can resume.
- **Final PR.** Once children are integrated, runs **`keiko-issue-audit`** on the
  integrated surface, then opens one epic PR `epic/<name> → dev` with a child
  matrix + evidence.
- **Hand off.** Sets the epic `Ready for Human Review`. **Stops** — the human
  merges the epic PR into `dev`.

---

## C. Audit something already claimed done

`keiko-issue-audit` also runs standalone — audit an issue someone says is
finished, find gaps, ship fixes:

**Prompt:**

```text
Act as the orchestrator for Keiko and audit issue #178 against its acceptance
criteria. Fix only confirmed gaps and open a PR.
```

**Skill chain it runs:**

```text
keiko-issue-audit 178      ← invoked directly (not wrapped by keiko-issue)
```

- Read-first wave (`explorer` / `architect` / `security` / `pr-reviewer`) audits
  the implementation against the acceptance criteria.
- Only **evidence-cited** findings become fix slices (`implementor` / `developer`
  - `test-engineer`); speculative findings never block.
- Ends with `verifier` + a green PR per the sacred-`dev` rule.

---

## While it runs

- **Watch it live:** `KEIKO_ROOT=/path/to/Keiko /path/to/Agent-Workflow-Setup/scripts/keiko-watch`
  in a side terminal — a per-agent stream so you can see work happening.
- **You're only interrupted** for a true blocker (after the orchestrator's own
  recovery attempts) or to review/merge a PR into `dev`.
