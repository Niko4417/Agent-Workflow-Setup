#!/usr/bin/env python3
"""Structural setup lint. Python 3.11+ and requirements-dev.txt; no network calls."""
from pathlib import Path
import ast
import json
import re
import subprocess
import sys
import tomllib

import yaml

ROOT = Path(__file__).resolve().parents[1]


class UniqueLoader(yaml.SafeLoader):
    """Reject duplicate YAML keys rather than silently accepting the last one."""


def unique_mapping(loader, node):
    pairs = loader.construct_pairs(node, deep=True)
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate YAML key: {key}")
        result[key] = value
    return result


UniqueLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, unique_mapping)


def load_yaml(value):
    return yaml.load(value, Loader=UniqueLoader)


def frontmatter(value):
    match = re.match(r"\A---\n(.*?)\n---(?:\n|$)", value, re.S)
    if not match:
        raise ValueError("missing YAML frontmatter")
    data = load_yaml(match[1])
    if not isinstance(data, dict):
        raise ValueError("frontmatter must be a mapping")
    return data


def hook_commands(value):
    if isinstance(value, dict):
        if value.get("type") == "command":
            yield value["command"]
        for child in value.values():
            yield from hook_commands(child)
    elif isinstance(value, list):
        for child in value:
            yield from hook_commands(child)


def check(root=ROOT):
    errors = []
    # Deliberately exclude local memory, generated caches, and historical records.
    files = list(root.glob("*.md")) + list(root.glob("*.json"))
    for folder in (".agents", "claude", "codex", "profiles", "docs", "scripts", "tests", "templates"):
        files.extend(p for p in (root / folder).rglob("*") if p.is_file())
    for p in files:
        rel = p.relative_to(root)
        if "tmp" in rel.parts or "__pycache__" in rel.parts or "worktrees" in rel.parts:
            continue
        if rel.parts[:2] == (".agents", "memory") and p.name != "README.md":
            continue
        if "archive" in rel.parts or p.name == "workflow-blueprint.md" or p.name == "settings.local.json":
            continue
        if p.suffix and p.suffix not in {".md", ".json", ".toml", ".yaml", ".yml", ".py", ".sh"}:
            continue
        try:
            value = p.read_text(encoding="utf-8")
            data = None
            if p.suffix == ".json":
                data = json.loads(value)
            elif p.suffix == ".toml":
                data = tomllib.loads(value)
            elif p.suffix in (".yaml", ".yml"):
                data = load_yaml(value)
            elif p.suffix == ".md" and (rel.parts[:2] == ("claude", "agents") or (rel.parts[:2] == ("claude", "skills") and p.name == "SKILL.md")):
                data = frontmatter(value)
                expected = p.parent.name if p.name == "SKILL.md" else p.stem
                if data.get("name") != expected or not isinstance(data.get("description"), str) or not data["description"].strip():
                    errors.append(f"{rel}: invalid discovery name/description")
                if p.name == "SKILL.md":
                    if len(data["description"]) > 1024 or re.search(r"[<>]", data["description"]):
                        errors.append(f"{rel}: skill description must be concise and contain no angle brackets")
                    if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", expected):
                        errors.append(f"{rel}: invalid skill name")
                elif "memory" in data:
                    errors.append(f"{rel}: use the single local .agents/memory store, not Claude auto-memory")
            if p.suffix == ".py":
                ast.parse(value, filename=str(rel))
            if data is not None:
                for command in hook_commands(data):
                    run = subprocess.run(["bash", "-n", "-c", command], capture_output=True, text=True)
                    if run.returncode:
                        errors.append(f"{rel}: invalid hook shell syntax: {run.stderr.strip()}")
            if value.startswith("#!") and re.search(r"\b(?:bash|sh)\b", value.splitlines()[0]):
                run = subprocess.run(["bash", "-n", str(p)], capture_output=True, text=True)
                if run.returncode:
                    errors.append(f"{rel}: invalid shell syntax: {run.stderr.strip()}")
            if p.suffix == ".md":
                # Ignore code examples; installed .claude/.codex paths map to source folders.
                prose = re.sub(r"```.*?```", "", value, flags=re.S)
                for link in re.findall(r"(?<!!)\[[^\]\n]*\]\(([^\s)]+)\)", prose):
                    if ":" in link or link.startswith("#"):
                        continue
                    dest = (p.parent / link.split("#")[0]).relative_to(root)
                    dest = Path(*("claude" if part == ".claude" else "codex" if part == ".codex" else part for part in dest.parts))
                    if not (root / dest).exists():
                        errors.append(f"{rel}: missing local link target {link}")
        except (ValueError, KeyError, OSError, SyntaxError, yaml.YAMLError) as exc:
            errors.append(f"{rel}: {exc}")
    return errors


if __name__ == "__main__":
    issues = check()
    for issue in issues:
        print("FAIL:", issue)
    if not issues:
        print("PASS: setup formats, discovery metadata, hook/shell syntax, and local documentation links")
    raise SystemExit(bool(issues))
