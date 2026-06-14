# Audit / Verify Playbook

Issue audits use the canonical, parameterized **`keiko-issue-audit`** skill —
do not copy-paste an audit prompt or restate the steps here.

- Skill: `claude/skills/keiko-issue-audit/SKILL.md`
  (available to Codex at `~/.codex/skills/keiko-issue-audit` via `install.sh`).
- Invoke it with the issue number. It runs the read-first audit wave, scopes
  confirmed fixes, verifies, and ships a green PR per `docs/workflow-contract.md`.
- It is the mandatory pre-handoff gate before an issue becomes
  `Ready for Human Review`.

The procedure lives in one place. This file is only a pointer.
