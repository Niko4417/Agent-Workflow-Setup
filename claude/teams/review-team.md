# Review Team — Pre-Merge PR Triple Audit

**Use case**: a PR is ready for review and you want security, performance, and accessibility looked at in parallel before merging.

**Members**: 3 read-only teammates (no merge conflicts possible).

| Teammate | Subagent type | Model | Focus |
|----------|---------------|-------|-------|
| `sec` | `security-triage` | Sonnet | OWASP grep, secrets, dep advisories. Escalates to `security-auditor` (Opus, on-demand) only if critical/high findings. |
| `perf` | `performance-engineer` | Sonnet | Bundle size, Core Web Vitals, N+1 queries, React re-renders |
| `a11y` | `a11y-auditor` | Haiku | WCAG 2.2 AA checklist on changed UI |

**Cost**: ~1× Haiku + 2× Sonnet for the parallel pass. If `sec` escalates, add one Opus deep-audit pass.

## Spawn prompt

```text
Create an agent team to review PR #<NUMBER> in parallel before merge. Spawn three
read-only teammates using these subagent definitions:

- Teammate "sec" using the security-triage agent type. Task: run a first-pass
  security scan against the PR diff. Escalate to security-auditor only if
  critical/high findings.
- Teammate "perf" using the performance-engineer agent type. Task: audit the
  PR diff for bundle impact, Core Web Vitals regressions, N+1 query risks,
  and React re-render hotspots.
- Teammate "a11y" using the a11y-auditor agent type. Task: WCAG 2.2 AA review
  of any UI changes in the PR diff.

Have each teammate produce a structured report. Wait for all three to finish
before synthesising. Do not start implementing fixes — just collect findings.

Only approve plans that include file:line evidence for every finding.
```

## What the lead does after

1. Read all three reports.
2. Cross-check for overlapping findings (the same issue flagged by multiple lenses → highest priority).
3. If any teammate flagged a critical finding, spawn `security-auditor` (Opus) for a deep-audit pass.
4. Decide: APPROVE / REQUEST CHANGES / NEEDS DISCUSSION based on the union of findings.
5. Post the synthesised review to the PR (manually or via `pr-shepherd`).
6. Clean up the team.

## Anti-patterns

- **Don't** give review-team teammates write access. They must report, not fix.
- **Don't** start a review-team while another team is active — clean up first.
- **Don't** spawn `pr-reviewer` AND `review-team` for the same PR — `pr-reviewer` is the single-agent fallback when parallel work is overkill.
