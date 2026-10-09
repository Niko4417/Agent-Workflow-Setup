# Maintaining the workflow setup

## Instruction ownership

Keep durable, cross-task rules in [AGENTS.md](../AGENTS.md). Keep Claude mechanics
in [CLAUDE.md](../CLAUDE.md); its explicit `@AGENTS.md` import loads the shared
contract. Put ordered procedures and task-specific outputs in the five skills.
Use conditional references for substantial details that only one profile needs.

The target's `CONTEXT.md` defines product language/boundaries; its `AGENTS.md`
defines contribution rules. Read the selected profile's task-relevant authorities
without copying them into the workflow. Native installation preserves both root
files. Read current package scripts, schemas, ADRs, and accepted plans instead of
caching their state in several prompts. Historical blueprint/archive documents
are design history, not operating instructions.

This follows OpenAI's guidance to [keep skills focused with explicit inputs and
outputs](https://learn.chatgpt.com/docs/build-skills) and [separate persistent
instructions from reusable procedures](https://learn.chatgpt.com/docs/customization/overview),
plus Anthropic's guidance on [instruction consistency and imports](https://code.claude.com/docs/en/memory).
Reviewed 2026-10-09. Keep profile-required delivery/evidence gates when pruning;
brevity is not permission to weaken them.

## Upstream skill review (2026-10-09)

Reviewed [Matt Pocock's skills](https://github.com/mattpocock/skills/tree/49dd158d1076134a641b33efb035946536778336),
commit `49dd158d1076134a641b33efb035946536778336`. These are scoped adaptations;
they preserve Keiko's accepted contracts, profile authority, and human-only `dev`
merges rather than importing the upstream bundle or its delivery policy.

| Adaptation | Keiko procedure | Why it helps |
| --- | --- | --- |
| [Executed bug diagnosis](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/engineering/diagnosing-bugs/SKILL.md) | `keiko-issue`, debug-team, test roles | A symptom-specific failing assertion proves the bug; rerunning it tests the fix. A manufactured red must prove the intended mutation actually landed. |
| [Behavioral TDD seams](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/engineering/tdd/SKILL.md) | Planning/issue Quality Plans, test roles | Catches/misses distinguish public behavior tests from wiring/platform evidence; independent oracles avoid tautologies. |
| [Requirements and standards review](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/engineering/code-review/SKILL.md) | Issue audit and existing reviewers | Finds omitted acceptance as well as rule violations, with cited authority; preferences do not become blockers. |
| [Independent question rounds](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/productivity/grilling/SKILL.md) | Epic grill | Small batches settle independent decisions efficiently; dependent questions wait and settled choices are not reopened. |
| [Environment/automation reflection](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/engineering/retro/SKILL.md) | Retro proposals | Repair absent, broken, or unwired checks for recurring mechanical failures; reserve guidance for judgment. |

Routine test placement uses the existing accepted plan without another approval
step. Review axes use existing reviewers without forcing extra agents. Retro
changes remain proposals until authorized. Native planning details load only when
that profile is selected; web UI/a11y checklists live in conditional shared role
references.

## Repeatable lint and regression checks

Use Python 3.11+ in an isolated environment with [requirements-dev.txt](../requirements-dev.txt).
The [README commands](../README.md#skill-maintenance-and-setup-checks) run:

- `check-setup.py`: JSON/TOML/YAML and Python syntax, duplicate YAML keys, skill/agent
  discovery metadata, shell and inline hook syntax, and active local Markdown links.
- `check-routing.py`: canonical model/effort, both rosters, read-only Codex sandbox
  declarations, coordinator defaults, Stop judge, and displayed tables.
- Python regressions: setup lint failures, read-only Edit/Write hook behavior,
  current readiness files in source/installed layouts, logger record privacy,
  and routing drift.
- Every shell test: install, profile selection/verification, worktree propagation,
  lifecycle, receipts, and PR/push/merge gates.

Skill Creator's `quick_validate.py` also validates each skill's frontmatter and
body. During semantic review, walk at least a known bug, unclear-root-cause bug,
standalone audit, AFK epic child, Native user-facing journey, and interrupted retro.
Check that each uses the accepted authority, evidence, branch, and stop condition.
Do not interpret a static walkthrough as a live harness/platform smoke test.

## Memory and runtime limits

Both harnesses use the [single local memory store](../.agents/memory/README.md),
with no minimum quota. Claude auto-memory is omitted per agent because its
[`memory` field enables a separate store and memory write tools](https://code.claude.com/docs/en/sub-agents).
Read-only agents return candidates to the lead. Before compaction, delivery status
goes to GitHub; memory receives only reusable lessons. The Codex logger stores
lifecycle metadata and exit status, not commands, raw output, or assistant text.

Edit/Write hooks do not constrain Bash or arbitrary API calls. The configured
full-access posture and runtime sandbox inheritance must be checked in the actual
harness; prompt rules and local receipt files are not security boundaries. Named
role launch/model/effort checks and target-owned acceptance runs remain separate
from repository lint. Native immutable pinning is an integration responsibility,
not an installer-enforced guarantee; use the [detached checkout procedure](local-editing.md#pinning-an-optional-native-integration).
