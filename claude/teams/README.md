# Agent-Team Templates

Audience: the coordinator (lead session).

These are **spawn-prompt templates** for Claude Code agent teams. They are not configuration files (Claude Code does not read project-local team JSON — team state lives under `~/.claude/teams/{team-name}/` and is auto-generated). Use them by reading the relevant template and reproducing the spawn prompt in your session.

## How to use

1. Decide the team type (review, feature, debug — see below).
2. Open the corresponding template file.
3. Read it into context (or paste the spawn prompt into the lead).
4. Adapt the placeholders (PR number, module, hypothesis count).
5. Tell the lead to create the team. The lead spawns teammates using existing subagent definitions from `.claude/agents/`.

## When NOT to use a team

A single subagent is **more cost-effective** when:

- The task is sequential (no parallel work possible).
- Workers would touch the same file (file conflicts → overwrites).
- The task is small (< 5 minutes for a single agent).

Quote from the Claude Code docs: "_Three focused teammates often outperform five scattered ones._" Default team size: 3–5.

## Available templates

| Template | Use case | Members | Parallelism | Cost profile |
|----------|----------|---------|-------------|--------------|
| [review-team](review-team.md) | PR pre-merge audit | security-triage, performance-engineer, a11y-auditor | High (all read-only) | High (3 Opus 5.5) |
| [feature-team](feature-team.md) | Cross-layer feature delivery | developer, test-engineer, ui-engineer | Medium (different files) | High (3 Opus 5.5) |
| [debug-team](debug-team.md) | Adversarial root-cause analysis | 3× explorer with competing hypotheses | High (read-only) | Very low (3× Haiku 5.5 / medium) |

## Hard rules (apply to every team)

1. **No nested teams** — teammates cannot spawn their own teams. Only the lead can.
2. **Permissions inherit from the lead** — be careful with destructive permissions before spawning.
3. **Always clean up** — `Clean up the team` after the work is done. Orphaned tmux sessions accumulate.
4. **Watch for file conflicts** — pre-assign file ownership per teammate when implementing in parallel.
5. **Wait for teammates** — if you (the lead) start implementing instead of delegating, tell yourself: "Wait for your teammates to complete their tasks before proceeding."

## Cost guidance

- Feature and review teams use three Opus 5.5 workers; no mixed-model savings apply.
- Bounded debug lookup uses Haiku 5.5 / medium. Broad root-cause analysis requires
  Opus; three cheap guesses are not an authoritative diagnosis.
- Parallel teams add coordination/context costs and share rate limits. Measure
  total usage and elapsed time; worker count alone does not predict either.
- Use the [dated cost/effort assessment](../../docs/model-cost-effort.md) for
  token rates, long-context thresholds, and accepted-task cost comparisons.

## Limitations to remember

- `/resume` does **not** restore in-process teammates. Spawn fresh after a resume.
- One team at a time per lead. Clean up before starting another.
- Tmux split-pane mode does not work in VS Code's integrated terminal, Windows Terminal, or Ghostty — use `in-process` mode there (already the default in [settings.json](../settings.json)).
