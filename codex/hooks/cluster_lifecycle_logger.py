#!/usr/bin/env python3
"""Lifecycle metadata only: never persist commands, tool output, or assistant text."""

from __future__ import annotations

import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


LOG_PATH = Path(__file__).resolve().parents[1] / "tmp" / "cluster-hooks.log"
EXIT_CODE_RE = re.compile(r"Process exited with code (\d+)")


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def load_payload() -> dict[str, Any]:
    raw = sys.stdin.read().strip()
    if not raw:
        return {}
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return {}
    return data if isinstance(data, dict) else {}


def detect_exit_code(tool_response: Any) -> int | None:
    if tool_response is None:
        return None
    if isinstance(tool_response, dict):
        for key in ("exit_code", "exitCode"):
            value = tool_response.get(key)
            if isinstance(value, int) and not isinstance(value, bool):
                return value
    if not isinstance(tool_response, str):
        try:
            tool_response = json.dumps(tool_response, sort_keys=True)
        except TypeError:
            tool_response = str(tool_response)
    match = EXIT_CODE_RE.search(tool_response)
    return int(match.group(1)) if match else None


def append_log(record: dict[str, Any]) -> None:
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with LOG_PATH.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, sort_keys=True) + "\n")


def build_record(action: str, payload: dict[str, Any]) -> dict[str, Any]:
    record: dict[str, Any] = {
        "ts": utc_now(),
        "action": action,
        "session_id": payload.get("session_id"),
        "turn_id": payload.get("turn_id"),
        "cwd": payload.get("cwd"),
        "model": payload.get("model"),
        "hook_event_name": payload.get("hook_event_name"),
    }

    if action == "session-start":
        record["source"] = payload.get("source")

    if action == "post-tool-use":
        tool_response = payload.get("tool_response")
        exit_code = detect_exit_code(tool_response)
        record["tool_name"] = payload.get("tool_name")
        record["tool_use_id"] = payload.get("tool_use_id")
        record["exit_code"] = exit_code
        record["status"] = (
            "error" if exit_code not in (None, 0) else "ok" if exit_code == 0 else "unknown"
        )

    if action == "stop":
        record["stop_hook_active"] = payload.get("stop_hook_active")

    return record


def main() -> int:
    action = sys.argv[1] if len(sys.argv) > 1 else "unknown"
    payload = load_payload()
    append_log(build_record(action, payload))

    if action == "stop":
        sys.stdout.write("{\"continue\": true}\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
