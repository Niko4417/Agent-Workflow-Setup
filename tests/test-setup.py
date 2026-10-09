#!/usr/bin/env python3
"""Regression coverage for structural lint, read-only hooks, and retired-file readiness."""
from pathlib import Path
import importlib.util
import json
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("setup_check", ROOT / "scripts/check-setup.py")
lint = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lint)


class SetupTests(unittest.TestCase):
    def test_current_setup(self):
        self.assertEqual(lint.check(ROOT), [])

    def test_invalid_hook_shell(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "bad.json").write_text(json.dumps({"hooks": [{"type": "command", "command": "if then"}]}))
            self.assertTrue(any("shell syntax" in error for error in lint.check(root)))

    def test_duplicate_yaml_key(self):
        with self.assertRaisesRegex(ValueError, "duplicate"):
            lint.load_yaml("name: first\nname: second\n")

    def test_local_link_mapping_and_missing_link(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "claude").mkdir()
            (root / "claude/reference.md").write_text("# Reference\n")
            (root / "README.md").write_text("[installed](.claude/reference.md)\n[missing](gone.md)\n")
            self.assertEqual(lint.check(root), ["README.md: missing local link target gone.md"])

    def test_skill_missing_discovery(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            skill = root / "claude/skills/example/SKILL.md"
            skill.parent.mkdir(parents=True)
            skill.write_text("---\nname: example\n---\n# Skill\n")
            self.assertTrue(any("discovery" in error for error in lint.check(root)))

    def test_reject_second_memory_store(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            agent = root / "claude/agents/explorer.md"
            agent.parent.mkdir(parents=True)
            agent.write_text("---\nname: explorer\ndescription: Map code\nmemory: project\n---\n")
            self.assertTrue(any("single local" in error for error in lint.check(root)))

    def test_readonly_hooks_deny_memory_and_source_writes(self):
        roles = lint.load_yaml((ROOT / ".agents/roles.yaml").read_text())["roles"]
        for role, definition in roles.items():
            if definition["posture"] != "read-only":
                continue
            agent = lint.frontmatter((ROOT / f"claude/agents/{role}.md").read_text())
            self.assertNotIn("memory", agent)
            for group in agent["hooks"]["PreToolUse"]:
                for command in lint.hook_commands(group):
                    for path in ("src/file.ts", f".agents/memory/{role}/MEMORY.md"):
                        result = subprocess.run(["bash", "-c", command], input=json.dumps({"tool_input": {"file_path": path}}), capture_output=True, text=True)
                        self.assertEqual(result.returncode, 2, (role, path))

    def test_readiness_without_old_prompts_or_coordinator(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "codex/scripts").mkdir(parents=True)
            (root / "codex/agents").mkdir()
            (root / ".agents").mkdir()
            shutil.copy2(ROOT / "codex/scripts/check-mcp-readiness.sh", root / "codex/scripts/check-mcp-readiness.sh")
            (root / "codex/config.toml").write_text("[mcp_servers]\n")
            (root / "codex/RUNBOOK.md").write_text("# Runbook\n")
            (root / ".agents/roles.yaml").write_text("version: 2\nroles:\n  explorer:\n    kind: read\n")
            (root / "codex/agents/explorer.toml").write_text('name = "explorer"\n')
            (root / "bin").mkdir()
            gh = root / "bin/gh"
            gh.write_text("#!/bin/sh\nexit 0\n")
            gh.chmod(0o755)
            env = {**os.environ, "PATH": f"{root / 'bin'}:{os.environ['PATH']}"}
            run = lambda script: subprocess.run(["bash", str(script)], env=env, capture_output=True, text=True)
            self.assertEqual(run(root / "codex/scripts/check-mcp-readiness.sh").returncode, 0)
            # Installed symlink layout also works, without a local memory file.
            target = root / "target"
            target.mkdir()
            (target / ".codex").symlink_to(root / "codex")
            (target / ".agents").symlink_to(root / ".agents")
            self.assertEqual(run(target / ".codex/scripts/check-mcp-readiness.sh").returncode, 0)
            (root / "codex/agents/explorer.toml").unlink()
            result = run(root / "codex/scripts/check-mcp-readiness.sh")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("missing agent definition", result.stderr)


if __name__ == "__main__":
    unittest.main()
