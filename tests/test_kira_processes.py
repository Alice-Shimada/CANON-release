"""Native process ownership across successful exit, timeout and descendants."""

import importlib.util
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("kira_backend", ROOT / "components/reducers/kira/run.py")
kira = importlib.util.module_from_spec(spec)
spec.loader.exec_module(kira)


@unittest.skipUnless(os.name == "posix" and hasattr(os, "WNOWAIT"), "requires POSIX waitid")
class KiraProcessTest(unittest.TestCase):
    def run_child(self, program, timeout=3):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            owner = kira.OwnedProcesses(output, .05)
            try:
                result = owner.run([sys.executable, "-c", program], output, "native.log",
                                   os.environ.copy(), timeout)
                log = (output / "native.log").read_text()
            finally:
                owner.close()
            with self.assertRaises(ProcessLookupError):
                os.kill(result["pid"], 0)
            return result, log

    def test_successful_quick_exit_is_reaped_without_cleanup_error(self):
        result, log = self.run_child("print('native complete', flush=True)")
        self.assertEqual(result["returncode"], 0)
        self.assertFalse(result["timed_out"])
        self.assertIn("native complete", log)

    def test_timeout_kills_child_ignoring_term(self):
        result, _ = self.run_child(
            "import signal,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); time.sleep(30)", .2)
        self.assertTrue(result["timed_out"])
        self.assertEqual(result["returncode"], -signal.SIGKILL)

    def test_successful_leader_exit_still_cleans_live_descendant(self):
        result, log = self.run_child(
            "import subprocess,sys; p=subprocess.Popen([sys.executable,'-c','import time; time.sleep(30)']); "
            "print(p.pid,flush=True)")
        self.assertEqual(result["returncode"], 0)
        descendant = int(log.strip())
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            state = subprocess.run(["ps", "-o", "stat=", "-p", str(descendant)],
                                   capture_output=True, text=True, check=False).stdout.strip()
            if not state or state.startswith("Z"):
                break
            time.sleep(.02)
        self.assertTrue(not state or state.startswith("Z"), state)

    def test_permission_denial_for_live_group_is_not_suppressed(self):
        # Permit the final cleanup call so this negative test leaves no child.
        real_killpg = os.killpg
        calls = 0

        def deny_once(group, number):
            nonlocal calls
            calls += 1
            if calls == 1:
                raise PermissionError("fixture denial")
            return real_killpg(group, number)

        with patch.object(kira.os, "killpg", side_effect=deny_once), \
                patch.object(kira.sys, "platform", "darwin"):
            with self.assertRaises(PermissionError):
                self.run_child("import time; time.sleep(30)", .1)


if __name__ == "__main__":
    unittest.main()
