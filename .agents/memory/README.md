# Shared agent memory (tool-neutral)

One curated `MEMORY.md` per canonical role (see `../roles.yaml`). Both harnesses
read and write here, so learnings survive a harness switch (Codex -> Claude).

## Rules
- **Commit** curated `MEMORY.md` files — they are the learning asset.
- Keep each file **under 25 KB**. Prefer short, dated bullets over transcripts.
- Store only durable lessons: codepaths, gotchas, verification commands,
  resolved false positives, architecture invariants.
- **Never** store secrets, tokens, customer data, raw private source dumps, or
  full command logs.
- Per-issue exploration dumps are **not** memory — they are work artifacts.
  Keep them out of this tree (they belong on the PR / issue as evidence).

## Format
```markdown
# <role> memory

- YYYY-MM-DD: <durable lesson, codepath, or gotcha>
```
