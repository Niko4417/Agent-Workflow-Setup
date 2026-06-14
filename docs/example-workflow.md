# Example workflow

Concrete prompts to give the orchestrator, and what happens under the hood. The
GitHub issue/epic is always the source of truth — you give a number, not a spec.

---

## A. Work a single issue

**Prompt:**

```text
Act as the orchestrator for Keiko and resolve issue #178.
Run the standard workflow end-to-end and stop only on a real blocker.
```

**What happens:**

- **Intake (Definition-of-Ready).** Fetches #178; confirms it has acceptance
  criteria + a verification command. If missing → triages first, doesn't start.
- **Claim.** Marks the issue `In Progress` on the delivery board, sets owner and
  `Human Review Required = Yes`.
- **Route (task-shaped).** Picks the smallest effective team — `explorer` to map
  the code, then `implementor` (small) or `developer` (needs design); adds
  `security-*`, `performance-engineer`, `a11y-auditor`, `test-engineer` only if
  the changed surface warrants it.
- **Implement.** Branch `issue/178-<short>` off `dev`; quality bars enforced
  (no `any`, complexity ≤10, TDD); each agent runs a 2-pass self-critique.
- **Verify.** `verify.sh` (local CI mirror) must be green; then `keiko-issue-audit
178` runs the read-first audit wave — mandatory even if it finds nothing.
- **Ship.** `verifier` fills the PR's evidence section; PR opens targeting `dev`.
  `pr-shepherd` drives CI/review to merge-ready.
- **Hand off.** Sets `Ready for Human Review`. **Stops there** — a human merges to
  `dev`. You're pinged; nothing auto-merges into `dev`.

---

## B. Work a multi-issue epic

**Prompt:**

```text
Act as the orchestrator for Keiko and run epic #532 to a closure-ready state.
Process children in dependency order, parallelize only where it's safe, and hand
me one green epic PR for review.
```

**What happens:**

- **Plan.** Fetches #532 and its children; classifies each `ready` / `blocked` /
  `done` / `needs-triage`; respects required order; flags safe parallelism (only
  disjoint file ownership, no ordering dependency).
- **Epic branch.** Cuts one long-lived `epic/<name>` off `dev`; records it on the
  board.
- **Child loop.** For each ready child, runs the **`keiko-issue`** skill on a
  branch off the epic branch. Each child PR targets the **epic branch** and
  **auto-merges on green CI** (the only auto-merge in the system) — no human per
  child. Re-syncs `dev` into the epic branch regularly.
- **Heartbeat.** Posts a one-line status at each child/milestone and flushes
  state to GitHub so either harness can resume.
- **Final PR.** Once children are integrated and verified, audits the integrated
  surface and opens one epic PR `epic/<name> → dev` with a child matrix +
  evidence.
- **Hand off.** Sets the epic `Ready for Human Review`. **Stops** — the human
  merges the epic PR into `dev`.

---

## C. Audit something already claimed done

`keiko-issue-audit` also runs standalone — to audit an issue someone says is
finished, find gaps, and ship fixes:

```text
Act as the orchestrator for Keiko and audit issue #178 against its acceptance
criteria. Fix only confirmed gaps and open a PR.
```

- Read-first wave (`explorer`/`architect`/`security`/`pr-reviewer`) audits the
  implementation against the acceptance criteria.
- Only **evidence-cited** findings become fix slices (`implementor`/`developer`
  - `test-engineer`); speculative findings never block.
- Ends with `verifier` + a green PR per the sacred-`dev` rule.

---

## While it runs

- **Watch it live:** `KEIKO_ROOT=/path/to/Keiko /path/to/Agent-Workflow-Setup/scripts/keiko-watch`
  in a side terminal — a per-agent stream so you can see work happening.
- **You're only interrupted** for a true blocker (after the orchestrator's own
  recovery attempts) or to review/merge a PR into `dev`.
