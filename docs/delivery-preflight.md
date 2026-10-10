# Delivery helper qualification

The target repository owns its commands, required checks and merge authority.
The helper preflight augments those controls. Its receipts are workflow evidence,
not a replacement for GitHub protection or a security boundary against a user who
can alter local files.

For web targets that accepted ADR-0145, `verify.sh` reads the individual minimum
loop from the target's current `AGENTS.md`, checks that each command exists, and
runs it with Sonar. Structurally certain runtime, UI, e2e and workflow changes
select their target-required gates. Semantic touched-area obligations (public
exports, retrieval, context, dependencies, releases and coverage) come from the
accepted target Quality Plan, not filename guesses. Pass each selected checking
script as `verify-receipt.sh <issue> --also <script>` (repeat `--also` as needed).
The receipt runs every selected command itself and records the full command list
for the audit to compare with the target requirements. Preview modern selection
with `verify-web-policy.py --plan --also <script>` from the target root.
Generator and `--fix` commands belong to implementation. Delivery receipts require
an unchanged committed HEAD, with no tracked edits or non-ignored untracked inputs,
and `mode: full`; old or fast receipts cannot satisfy the gate. Ignored working
notes, PR bodies and generated outputs do not invalidate HEAD
proof; keep scratch artifacts in ignored locations. Source, tests and configuration
must be committed rather than hidden as working notes. Package-surface assembly
runs last because it prunes the live dependency tree.

Audit/UI writers and every proof consumer reject tracked dirty bytes and
non-ignored untracked inputs, and UI journeys cannot change HEAD, branch, or delivery inputs while minting proof.

PR creation, readiness and open-PR fix pushes check `issue/*`, `epic/*` and
`codex/*` branches. A missing helper blocks the matching delivery command. A
successful empty PR inventory on ADR-0145 Web targets requires current verify
proof before implementation pushes, without requiring an early audit. Only an
exact existing origin/dev or canonical origin epic base commit with clean inputs
may bootstrap an unchanged branch without that proof. Older/Native targets retain
their own pre-PR policy. A lookup error never qualifies a push. Child fix pushes
require the same local evidence as dev fix pushes.

A child merge requires the live `dev` App-bound matrix and every requirement on
its epic target when protection is configured. `/branches/<name>` supplies the producer bindings
without administrator access. The complete exact-head check-run inventory is
read to exhaustion (bounded at ten pages); only each trusted App's latest
successful completed check qualifies. Every paginated review thread must be
resolved, and the PR must remain open, non-draft, at the same head and base. The
canonical merge command still requires `--match-head-commit` and rejects admin,
repository overrides and shell chaining. An unprotected epic target does not block a child whose full dev matrix is green;
the helper never creates or relaxes protection.

## Target-owned dev delivery

Generic targets retain the human-review default for dev integration. A target
whose current `AGENTS.md` references its accepted ADR-0135 may route accepted
accepted issue or epic work into dev through the same exact-head checks, clean audit,
verification and applicable UI proof. This includes the workflow-admission
bootstrap; it needs no extra authority receipt, body hash or native-parent lookup.
The helper provides workflow feedback, not a human-authorization security boundary.
Accepted issue scope remains governed by the target and the operator's task.
The operator's explicit final review hold for epic #3914 remains a task instruction
and is respected by the orchestrator. It does not become a universal branch-name
restriction or another local permission receipt.

## Hook runtime and installation

[Codex's official hook documentation](https://developers.openai.com/codex/hooks)
identifies unified `exec_command` as `Bash`, with shell payload in
`tool_input.command`. It also specifies that hook commands run in the session
working directory. A configured matcher alone does not prove that a particular
installed runtime triggered it. Qualify a harmless deny canary through the actual
tool path before delivery and record its result. Codex CLI 0.160.1 normalizes
unified-exec `tool_input` to the command alone, dropping its effective `workdir`.
The session `cwd` cannot establish where that command will execute. Raw delivery
commands therefore fail closed when the effective tool directory is unavailable.

Use the explicit-root entrypoint with literal, canonical absolute paths:

```bash
python3 "/absolute/target/.keiko-scripts/delivery-command.py" --root "/absolute/target" -- gh pr create --base codex/epic-name --head codex/issue-123-task --title "Task title" --body-file "/absolute/target/pr-body.md"
python3 "/absolute/target/.keiko-scripts/delivery-command.py" --root "/absolute/target" -- gh pr ready 123
python3 "/absolute/target/.keiko-scripts/delivery-command.py" --root "/absolute/target" -- git push -u origin codex/issue-123-task
python3 "/absolute/target/.keiko-scripts/delivery-command.py" --root "/absolute/target" -- gh pr merge 123 --auto --squash --match-head-commit <exact-head-sha>
```

Replace the paths, branch, PR and SHA with the accepted task's actual values;
`<exact-head-sha>` above is a placeholder, not shell syntax to execute. The hook
and entrypoint validate the same exact Git top level and assigned branch. The
entrypoint must be that root's `.keiko-scripts/delivery-command.py`, and its
helpers must resolve to the dispatcher's reviewed source. No aliases, extra
entrypoint flags, executable prefixes, repository overrides, environment
redirections, shell chaining or command substitution are accepted. Git pushes
name `origin` and the current branch explicitly, with no force or default refspec; harmless dry-run and output flags are accepted.
Create accepts standard title/body, branch, draft, dry-run and issue-metadata flags;
an explicit `--head` must match the verified local branch. Ready names one
positive PR number; merge retains its existing strict canonical parser.
Quoted examples and simple non-delivery heredoc bodies do not trigger delivery gates.
Commands following a heredoc remain inspected. Readiness also reads that exact PR and requires its remote branch and head SHA
to match the verified local branch and HEAD, including non-user-facing changes.

The entrypoint independently repeats the applicable gates and executes the inner
argv directly with `subprocess` at the validated root, without a shell. Calling
it through another tool cannot skip local proof or the target-owned delivery checks.
Qualify missing-proof create/ready/open-PR push and unsafe merge canaries against
an alternate worktree through the actual tool path. A merge-zero denial alone
proves interception, not repository binding. Record static tests separately from
actual runtime results; do not claim qualification from configuration alone.

Validate edits in an isolated workflow worktree, obtain an independent review,
and install only the reviewed snapshot. Do not overwrite a dirty owner checkout
or point the target at an unreviewed worktree. Existing target-specific hook
configuration must be preserved when updating helper hooks. Re-run the installed
canary and targeted regressions after installation. If the harness cannot prove
blocking hooks through its real command path, report that limitation and require
the self-gating explicit-root entrypoint before each delivery; do not describe
hooks as qualified.
