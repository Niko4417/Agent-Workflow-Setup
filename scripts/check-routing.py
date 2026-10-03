#!/usr/bin/env python3
"""Validate the deliberately simple routing maps against both harnesses and docs.

The policy's model/effort fields use two-entry YAML flow maps. Reject unsupported
syntax rather than pretending to parse arbitrary YAML. Python 3.11+; no packages.
"""
from pathlib import Path
import json
import re
import sys
import tomllib

ROOT = Path(__file__).resolve().parents[1]
FIELDS = re.compile(r"^\s+(model|effort): \{ codex: ([\w.\-]+), claude: ([\w.\-]+) \}$", re.M)


def text(path):
    return path.read_text(encoding="utf-8")


def settings(block):
    entries = FIELDS.findall(block)
    if len(entries) != 2 or {entry[0] for entry in entries} != {"model", "effort"}:
        raise ValueError("Expected one model map and one effort map")
    return {key: {"codex": gpt, "claude": None if claude == "null" else claude}
            for key, gpt, claude in entries}


def policy(root):
    value = text(root / ".agents/roles.yaml")
    sections = re.split(r"^(lead|escalation|roles):\n", value, flags=re.M)
    if len(sections) != 7:
        raise ValueError("Expected lead, escalation, and roles sections")
    sections = dict(zip(sections[1::2], sections[2::2]))
    roles = re.split(r"^  ([\w-]+):\n", sections["roles"], flags=re.M)
    pairs = list(zip(roles[1::2], roles[2::2]))
    if len({name for name, _ in pairs}) != len(pairs):
        raise ValueError("Duplicate role name")
    return settings(sections["lead"]), settings(sections["escalation"]), dict(pairs)


def check(root=ROOT):
    errors = []
    lead, escalation, roles = policy(root)
    expected_codex = {name + ".toml" for name in roles}
    expected_claude = {name + ".md" for name in roles if name != "browser-debugger"}
    for folder, expected in [("codex/agents", expected_codex), ("claude/agents", expected_claude)]:
        actual = {path.name for path in (root / folder).iterdir() if path.suffix in {".toml", ".md"}}
        if actual != expected:
            errors.append(f"{folder}: roster differs from canonical roles")
    readme, claude_doc = text(root / "README.md"), text(root / "CLAUDE.md")
    for name, block in roles.items():
        route = settings(block)
        codex = tomllib.loads(text(root / "codex/agents" / (name + ".toml")))
        for field, setting in [("model", "model"), ("model_reasoning_effort", "effort")]:
            if codex.get(field) != route[setting]["codex"]:
                errors.append(f"{name}: Codex {field} differs from policy")
        if "    posture: read-only\n" in block and codex.get("sandbox_mode") != "read-only":
            errors.append(f"{name}: read-only posture lacks read-only Codex sandbox")
        cm, ce = route["model"]["claude"], route["effort"]["claude"]
        if name != "browser-debugger":
            frontmatter = text(root / "claude/agents" / (name + ".md")).split("---", 2)[1]
            fields = dict(re.findall(r"^(model|effort): (.+)$", frontmatter, re.M))
            if fields.get("model") != cm or fields.get("effort") != ce:
                errors.append(f"{name}: Claude model/effort differs from policy")
        row = f"| `{name}` | `{route['model']['codex']}` | {route['effort']['codex']} | `{cm}` | {ce or 'n/a'} |"
        if row not in readme:
            errors.append(f"{name}: README routing row differs from policy")
        if f"| `{name}` | `{cm}` | {ce or 'n/a'} |" not in claude_doc:
            errors.append(f"{name}: CLAUDE routing row differs from policy")
        if route["effort"]["codex"] not in {"low", "medium", "high", "xhigh", "max"}:
            errors.append(f"{name}: unsupported configured Codex effort")
        if ("haiku" in cm) != (ce is None):
            errors.append(f"{name}: Haiku must omit effort; other Claude models must specify it")
    config = tomllib.loads(text(root / "codex/config.toml"))
    claude = json.loads(text(root / "claude/settings.json"))
    if (config.get("model"), config.get("model_reasoning_effort")) != (lead["model"]["codex"], lead["effort"]["codex"]):
        errors.append("Codex lead differs from policy")
    if (claude.get("model"), claude.get("effortLevel")) != (lead["model"]["claude"], lead["effort"]["claude"]):
        errors.append("Claude lead differs from policy")
    quality_hooks = [hook for group in claude.get("hooks", {}).get("Stop", [])
                     for hook in group.get("hooks", []) if hook.get("type") == "prompt"]
    if len(quality_hooks) != 1:
        errors.append("Expected exactly one Claude prompt quality hook")
    elif quality_hooks[0].get("model") != settings(roles["verifier"])["model"]["claude"]:
        errors.append("Claude quality hook differs from verifier model")
    if not escalation["model"]["codex"] or not escalation["model"]["claude"]:
        errors.append("Escalation model is missing")
    return errors


if __name__ == "__main__":
    try:
        issues = check()
    except (ValueError, KeyError, OSError) as error:
        issues = [str(error)]
    for issue in issues:
        print("FAIL:", issue)
    if not issues:
        print("PASS: 16 role routes, both harnesses, lead defaults, quality hook, and routing tables agree")
    raise SystemExit(bool(issues))
