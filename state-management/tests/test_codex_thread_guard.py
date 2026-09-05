from __future__ import annotations

import json
import sys
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest import mock


STATE_MANAGEMENT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(STATE_MANAGEMENT))

from codex_thread_guard import (  # noqa: E402
    CodexThreadGuard,
    GuardError,
    authority_directory,
    ensure_private_directory,
)


class CodexThreadGuardTests(unittest.TestCase):
    FIRST = "00000000-0000-4000-8000-000000000001"
    SECOND = "00000000-0000-4000-8000-000000000002"

    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.home = Path(self.temporary.name) / "home"
        self.home.mkdir()
        self.project = Path(self.temporary.name) / "project"
        self.project.mkdir()
        self.authority = authority_directory(self.home, self.project)
        ensure_private_directory(self.authority)
        self.guard = CodexThreadGuard(self.authority, self.project)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def bind(self, task_name: str, thread_id: str) -> None:
        with self.guard.authorize(
            "statemng_project_resume",
            {"task_name": task_name},
            {"threadId": thread_id},
        ) as authorization:
            authorization.complete(True)

    def test_records_are_scoped_and_reset_is_exact_and_audited(self) -> None:
        self.bind("study-a", self.FIRST)
        self.bind("study-b", self.SECOND)
        self.assertEqual(self.guard.show("study-a")["thread_id"], self.FIRST)
        self.assertEqual(self.guard.show("study-b")["thread_id"], self.SECOND)

        with self.assertRaisesRegex(GuardError, "expected thread ID"):
            self.guard.reset("study-a", self.SECOND)
        self.assertIsNotNone(self.guard.show("study-a"))
        audit = self.guard.reset("study-a", self.FIRST)
        self.assertEqual(audit["action"], "reset")
        self.assertIsNone(self.guard.show("study-a"))
        self.assertEqual(self.guard.show("study-b")["thread_id"], self.SECOND)
        audit_lines = (self.authority / "audit.jsonl").read_text(
            encoding="utf-8"
        ).splitlines()
        self.assertEqual(len(audit_lines), 2)
        entries = [json.loads(line) for line in audit_lines]
        self.assertEqual([entry["phase"] for entry in entries], ["intent", "completed"])
        self.assertEqual(entries[0]["operation_id"], entries[1]["operation_id"])
        self.assertEqual(entries[0]["task_name"], "study-a")

        self.bind("study-a", self.SECOND)
        self.assertEqual(self.guard.show("study-a")["thread_id"], self.SECOND)

    def test_corrupt_or_wrong_scope_records_fail_closed(self) -> None:
        self.bind("study", self.FIRST)
        record_path = next(
            path
            for path in self.authority.glob("*.json")
            if path.name != "audit.jsonl"
        )
        record = json.loads(record_path.read_text(encoding="utf-8"))
        record["version"] = 999
        record_path.write_text(json.dumps(record), encoding="utf-8")
        record_path.chmod(0o600)
        with self.assertRaisesRegex(GuardError, "scope does not match"):
            self.guard.show("study")

        record_path.unlink()
        record_path.symlink_to(self.project)
        with self.assertRaisesRegex(GuardError, "symbolic link"):
            self.guard.show("study")

    def test_reset_waits_for_an_authorized_coordinator_call(self) -> None:
        self.bind("study", self.FIRST)
        entered = threading.Event()
        reset_finished = threading.Event()
        failures: list[Exception] = []

        def reset() -> None:
            try:
                self.guard.reset("study", self.FIRST)
            except Exception as exc:  # surfaced by the assertion below
                failures.append(exc)
            finally:
                reset_finished.set()

        with self.guard.authorize(
            "statemng_doctor",
            {"task_name": "study"},
            {"threadId": self.FIRST},
        ) as authorization:
            entered.set()
            thread = threading.Thread(target=reset)
            thread.start()
            self.assertTrue(entered.is_set())
            time.sleep(0.05)
            self.assertFalse(reset_finished.is_set())
            authorization.complete(True)
        thread.join(timeout=5)
        self.assertFalse(thread.is_alive())
        self.assertEqual(failures, [])
        self.assertIsNone(self.guard.show("study"))

    def test_unwritable_authority_and_incomplete_reset_fail_closed(self) -> None:
        for mode in (0o500, 0o000):
            with self.subTest(mode=oct(mode)):
                self.authority.chmod(mode)
                with self.assertRaisesRegex(GuardError, "mode 0700"):
                    CodexThreadGuard(self.authority, self.project)
        self.authority.chmod(0o700)

        self.bind("study", self.FIRST)
        with mock.patch.object(Path, "unlink", side_effect=OSError("injected")):
            with self.assertRaisesRegex(GuardError, "reset is incomplete"):
                self.guard.reset("study", self.FIRST)
        self.assertEqual(self.guard.show("study")["thread_id"], self.FIRST)
        entries = [
            json.loads(line)
            for line in (self.authority / "audit.jsonl")
            .read_text(encoding="utf-8")
            .splitlines()
        ]
        self.assertEqual([entry["phase"] for entry in entries], ["intent"])


if __name__ == "__main__":
    unittest.main()
