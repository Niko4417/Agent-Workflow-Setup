# Shared agent memory (tool-neutral)

One curated `MEMORY.md` per canonical role (see `../roles.yaml`). Both harnesses
use this local store, so learnings survive a harness switch (Codex -> Claude).

## Rules

- **Local-only — do not commit.** The `.agents/memory/*/` role dirs are git-ignored
  by user directive (only this `README.md` is tracked). Curated memory is your
  **per-machine** learning asset; both harnesses on this machine read/write it, so it
  still survives a Codex↔Claude switch — it just isn't pushed or shared.
- Keep each file **under 25 KB**. Prefer short, dated bullets over transcripts.
- Store only durable lessons: codepaths, gotchas, verification commands,
  resolved false positives, architecture invariants.
- **Never** store secrets, tokens, customer data, raw private source dumps, or
  full command logs.
- Per-issue exploration dumps are **not** memory — they are work artifacts.
  Keep them out of this tree (they belong on the PR / issue as evidence).

- **Read-only roles never write**, including memory: return a candidate to the lead.
  Write-enabled roles/lead record only reusable lessons within authorized scope.
- No minimum size or quota: an empty file is valid when nothing durable was learned.
- Claude `memory:` frontmatter is intentionally omitted: it would create a second
  `.claude/agent-memory/` store and grant memory write tools to read-only agents.

## Format

```markdown
# <role> memory

- YYYY-MM-DD: <durable lesson, codepath, or gotcha>
```
