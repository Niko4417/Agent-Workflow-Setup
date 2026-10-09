#!/usr/bin/env python3
"""Public record contract: retain status metadata, exclude private payload content."""
from pathlib import Path
import importlib.util
import json
import unittest

path = Path(__file__).resolve().parents[1] / "codex/hooks/cluster_lifecycle_logger.py"
spec = importlib.util.spec_from_file_location("logger", path)
logger = importlib.util.module_from_spec(spec)
spec.loader.exec_module(logger)


class LoggerTests(unittest.TestCase):
    def test_private_content_never_enters_record(self):
        private = "customer-source secret-token"
        payload = {"tool_name": "Bash", "tool_input": {"command": private},
                   "tool_input.command": private, "tool_response": private,
                   "last_assistant_message": private, "raw_stdin": private}
        for action in ("session-start", "post-tool-use", "stop"):
            record = logger.build_record(action, payload)
            self.assertNotIn(private, json.dumps(record))
            for forbidden in ("command", "tool_response", "last_assistant_message", "raw_stdin"):
                self.assertNotIn(forbidden, record)

    def test_exit_status_from_supported_tool_responses(self):
        for response, expected in (({"exit_code": 0}, "ok"), ({"exitCode": 1}, "error"),
                                   ("Process exited with code 2", "error"), (None, "unknown"),
                                   ({"exit_code": True}, "unknown")):
            self.assertEqual(logger.build_record("post-tool-use", {"tool_response": response})["status"], expected)

    def test_keep_lifecycle_ids_and_stop_flag(self):
        payload = {"session_id": "session", "turn_id": "turn", "model": "model", "stop_hook_active": True}
        record = logger.build_record("stop", payload)
        self.assertEqual((record["session_id"], record["turn_id"], record["model"]), ("session", "turn", "model"))
        self.assertTrue(record["stop_hook_active"])


if __name__ == "__main__":
    unittest.main()
