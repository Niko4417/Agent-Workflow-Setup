# CI Repair Playbook

Use when a PR is blocked by failing GitHub Actions.

1. Identify the current PR and failing checks.
2. Use `gh` for job logs when needed.
3. Classify the failure:
   - product regression;
   - test expectation drift;
   - workflow/config error;
   - dependency/toolchain issue;
   - flaky or infrastructure-only failure.
4. Assign a single owner to each failure class.
5. Fix the smallest confirmed cause.
6. Commit the fix; rerun affected local checks, independent audit and accepted UI
   journeys. Push using ordinary Git commands and report the actual results with
   the exact current PR head in its body/comment. Recheck required exact-head CI
   and settle review findings.
7. Stop after three repair attempts with different root causes and report the
   blocker.

Never bypass or weaken a quality gate to make CI green.
