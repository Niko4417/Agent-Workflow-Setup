#!/usr/bin/env python3
"""Regression checks: detect policy/config/doc drift without calling models."""
from pathlib import Path
import importlib.util
import json
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("routing", ROOT / "scripts/check-routing.py")
routing = importlib.util.module_from_spec(spec)
spec.loader.exec_module(routing)


class RoutingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="keiko-routing-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        for folder in ["codex/agents", "claude/agents"]:
            shutil.copytree(ROOT / folder, self.root / folder)
        for name in [".agents/roles.yaml", "codex/config.toml", "claude/settings.json", "README.md", "CLAUDE.md"]:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, path)

    def mutate(self, name, before, after):
        path = self.root / name
        value = path.read_text(encoding="utf-8")
        self.assertIn(before, value)
        path.write_text(value.replace(before, after, 1), encoding="utf-8")

    def test_current_policy(self):
        self.assertEqual(routing.check(self.root), [])

    def test_catches_codex_model_drift(self):
        self.mutate("codex/agents/explorer.toml", "gpt-6-luna", "gpt-6.1-sol")
        self.assertTrue(any("explorer: Codex model differs" in error for error in routing.check(self.root)))

    def test_catches_claude_effort_drift(self):
        self.mutate("claude/agents/implementor.md", "effort: medium", "effort: high")
        self.assertTrue(any("implementor: Claude" in error for error in routing.check(self.root)))

    def test_catches_missing_read_only_sandbox(self):
        self.mutate("codex/agents/security-triage.toml", 'sandbox_mode = "read-only"', '')
        self.assertTrue(any("security-triage: read-only" in error for error in routing.check(self.root)))

    def test_catches_stale_readme(self):
        self.mutate("README.md", "| `explorer` | `gpt-6-luna`", "| `explorer` | `gpt-5.6-luna`")
        self.assertTrue(any("explorer: README" in error for error in routing.check(self.root)))

    def test_catches_quality_hook_drift(self):
        self.mutate("claude/settings.json", '"model": "claude-sonnet-5-5"', '"model": "claude-sonnet-4-6"')
        self.assertIn("Claude quality hook differs from verifier model", routing.check(self.root))

    def test_catches_missing_quality_hook(self):
        path = self.root / "claude/settings.json"
        config = json.loads(path.read_text(encoding="utf-8"))
        config["hooks"]["Stop"] = []
        path.write_text(json.dumps(config), encoding="utf-8")
        self.assertIn("Expected exactly one Claude prompt quality hook", routing.check(self.root))

    def test_catches_duplicate_role(self):
        self.mutate(".agents/roles.yaml", "  docs:\n", "  explorer:\n")
        with self.assertRaisesRegex(ValueError, "Duplicate role"):
            routing.check(self.root)


if __name__ == "__main__":
    unittest.main()
