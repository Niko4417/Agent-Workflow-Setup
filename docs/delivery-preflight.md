# Before a pull request

Read the target's current `AGENTS.md`, scoped instructions and accepted Quality
Plan. Run the applicable local checks, fix confirmed failures, and complete the
independent `keiko-issue-audit`. Execute required UI journeys using the selected
profile's harness. Report the exact current PR head, actual commands/results,
audit findings and resolution, UI results and limitations in the PR body or a
comment. Refresh affected evidence after code changes.

`verify.sh` is an optional convenient runner for target-owned checks. For Web
ADR-0145 targets it selects individual minimum-loop commands and mandatory Sonar;
add semantic touched-area obligations using repeatable `--also <script>`. Preview
selection with `verify-web-policy.py --plan --also <script>`. Run generators/fixes
as implementation work and package-surface assembly last because it prunes live
dependencies. A fast smoke does not replace required verification.

Use ordinary Git/GitHub commands from the deliberately chosen repository workdir.
Fill the target PR template. Before merge, require the full target required-check
matrix on the exact current PR head and settled review findings. The optional
read-only `required-checks-gate.py <PR-number> <base-branch> <head-sha>` can inspect
Web App-bound checks and review settlement; it neither grants authority nor
replaces Native's accepted quality control plane.

Where target/run authority permits, arm `gh pr merge <N> --auto --squash
--match-head-commit <exact-head-sha>`. Honor an explicit final epic review hold
without adding per-child approvals. Never force-push, push directly to `dev`, or
bypass target gates. ADR-0178 evidence reuse is for byte-identical integration
runs only; every PR still needs its full current-head matrix. Native retains its
frozen Execution Authority, lifecycle and Acceptance Journey.
