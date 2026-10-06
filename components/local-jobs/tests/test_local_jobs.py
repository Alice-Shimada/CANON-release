"""Bounded synthetic subprocess tests; no reducer, host session or service."""

import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest


CANON = Path(os.environ["CANON_TEST_ROOT"]).resolve()
PACKAGE = Path(__file__).resolve().parents[1]


def read(path):
    return json.loads(path.read_text())


def write(path, value):
    path.write_text(json.dumps(value))


def wait_until(predicate, timeout=4):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = predicate()
        if value:
            return value
        time.sleep(0.02)
    raise AssertionError("bounded subprocess did not finish")


SCIENCE = r'''
import json, os
from pathlib import Path
import subprocess, sys, time
request, output = map(Path, sys.argv[1:])
task = json.loads(request.read_text())
output.mkdir(parents=True)
payload = task["payload"]
mode = payload.get("mode", "success")
if mode == "grandchild":
    child = subprocess.Popen([sys.executable, "-c", "import signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); time.sleep(30)"])
    (output / "descendant.pid").write_text(str(child.pid))
    time.sleep(30)
time.sleep(payload.get("delay", 0))
if mode == "missing":
    sys.exit(0)
status = {"science-failure":"FAIL","science-inconclusive":"INCONCLUSIVE"}.get(mode,"PROVISIONAL")
result = {"schema":"canon-neu/script-result/v1", "task_id":task["task_id"], "step":task["step"],
          "status":status, "code":"SYNTHETIC_FIXTURE", "artifacts":{},
          "summary":{"synthetic":True, "components":os.environ.get("CANON_COMPONENTS"),
                     "marker":os.environ.get("DECLARED_TEST_MARKER"), "pid":os.getpid()}}
(output / "result.json").write_text(json.dumps(result))
sys.exit(7 if mode == "exit-failure" else 0)
'''

RECEIVER = r'''
import json
from pathlib import Path
import sys
database, mode, event_path = sys.argv[1:]
database, event_path = Path(database), Path(event_path)
event = json.loads(event_path.read_text())
state = json.loads(database.read_text()) if database.exists() else {"calls":0,"accepted":{}}
state["calls"] += 1
state["accepted"].setdefault(event["event_id"], event["target"])
database.write_text(json.dumps(state))
sys.exit(9 if mode == "fail-first" and state["calls"] == 1 else 0)
'''

CHECKER = r'''
import json
from pathlib import Path
import sys
checkpoint = json.loads(Path(sys.argv[-1]).read_text())
print(json.dumps({"schema":"canon-neu/local-checkpoint/v1", "job_id":checkpoint["job_id"],
                  "run_id":checkpoint["run_id"], "terminal":checkpoint["done"],
                  "status":checkpoint["outcome"], "result":checkpoint.get("result")}))
'''


class LocalJobTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="local jobs test ")
        self.base = Path(self.temporary.name)
        self.package = self.base / "external packages" / "local jobs"
        shutil.copytree(PACKAGE, self.package, ignore=shutil.ignore_patterns("__pycache__", "tests"))
        self.science = self.base / "external science package"
        self.science.mkdir()
        (self.science / "fixture.py").write_text(SCIENCE)
        (self.science / "instructions.md").write_text("Synthetic fixture; no physics claim.\n")
        write(self.science / "components.json", {"schema":"canon-neu/components/v1", "steps":{
            "SYNTHETIC": {"command":["{python}","{package}/fixture.py"],"instructions":"instructions.md"}}})
        (self.base / "fake receiver.py").write_text(RECEIVER)
        (self.base / "fixed check.py").write_text(CHECKER)
        self.jobs, self.watches, self.serial = [], [], 0
        self.env = os.environ.copy()
        self.env["PYTHONDONTWRITEBYTECODE"] = "1"
        self.env.pop("CANON_COMPONENTS", None)

    def tearDown(self):
        try:
            for handle in self.watches:
                if handle.exists():
                    self.call("CANCEL_WATCH", {"watch":{"path":str(handle)}})
                    state = handle.with_name("monitor.json")
                    if state.exists():
                        wait_until(lambda: not read(state)["running"])
            for handle in self.jobs:
                if handle.exists() and not handle.with_name("terminal.json").exists():
                    self.call("CANCEL_JOB", {"job":{"path":str(handle)}})
                    wait_until(lambda: handle.with_name("terminal.json").exists())
        finally:
            self.temporary.cleanup()

    def call(self, step, payload, destination=None):
        self.serial += 1
        request = self.base / f"request {self.serial}.json"
        output = destination or self.base / f"output {self.serial}"
        write(request, {"schema":"canon-neu/script-input/v1", "task_id":f"TEST-{self.serial}",
                        "step":step, "sector":None, "payload":payload})
        completed = subprocess.run([sys.executable, str(CANON / "run_step.py"), str(request), str(output),
                                    "--components", str(self.package / "components.json")],
                                   cwd=self.base, env=self.env, capture_output=True, text=True, timeout=5)
        self.assertTrue((output / "result.json").exists(), completed.stdout + completed.stderr)
        result = read(output / "result.json")
        self.assertNotEqual(result["status"], "PASS")
        self.assertFalse(result["summary"]["scientific_acceptance"])
        return result, output

    def submit(self, mode="success", delay=0):
        request = self.base / "science request.json"
        write(request, {"schema":"canon-neu/script-input/v1", "task_id":"SYNTHETIC-1", "step":"SYNTHETIC",
                        "sector":None,"payload":{"mode":mode,"delay":delay}})
        result, output = self.call("SUBMIT_JOB", {"request":{"path":"science request.json"},
                                                  "run_id":"synthetic-run-1", "cancel_grace_seconds":0.05,
                                                  "components":["external science package/components.json"],
                                                  "environment":{"DECLARED_TEST_MARKER":"explicit"}})
        self.assertEqual(result["code"], "JOB_SUBMITTED")
        handle = output / result["artifacts"]["job"]["path"]
        self.jobs.append(handle)
        return handle

    def terminal(self, handle):
        wait_until(lambda: handle.with_name("terminal.json").exists())
        return read(handle.with_name("terminal.json"))

    def watch_payload(self, checkpoint, job_id="fixture-job", run_id="fixture-run", callback_mode="normal"):
        return {"checkpoint":{"path":os.path.relpath(checkpoint, self.base)},
                "job_id":job_id,"run_id":run_id,
                "target":{"host":"fake-host","session":"fake-session","message":"Continue from the saved checkpoint."},
                "callback":{"argv":[sys.executable,"fake receiver.py","receiver.json",callback_mode],
                            "cwd":".", "timeout_seconds":1}, "interval_seconds":0.03}

    def watch(self, payload):
        result, output = self.call("WATCH_COMPLETION", payload)
        if "watch" in result["artifacts"]:
            handle = (output / result["artifacts"]["watch"]["path"]).resolve()
            if handle not in self.watches:
                self.watches.append(handle)
            return result, handle
        return result, None

    def checkpoint(self, name="checkpoint.json", **changes):
        path = self.base / name
        write(path, {"schema":"canon-neu/local-checkpoint/v1", "job_id":"fixture-job", "run_id":"fixture-run",
                     "terminal":True, "status":"succeeded", **changes})
        return path

    def test_detached_completion_relocated_collection_and_environment(self):
        handle = self.submit(delay=0.12)
        terminal = self.terminal(handle)
        self.assertEqual(terminal["status"], "succeeded")
        invocation = read(handle.with_name("invocation.json"))
        self.assertEqual(invocation["components"], [str(self.science / "components.json")])
        self.assertEqual(set(invocation["runtime_environment"]), {"CANON_COMPONENTS", "CANON_PYTHON"})
        self.assertNotIn("PATH", invocation["environment_overrides"])
        scientific = read(handle.parent / "science" / "result.json")
        self.assertEqual(scientific["summary"]["components"], str(self.science / "components.json"))
        self.assertEqual(scientific["summary"]["marker"], "explicit")
        relocated = self.base / "moved completed job"
        shutil.move(str(handle.parent), relocated)
        moved_handle = relocated / "job.json"
        result, output = self.call("COLLECT_JOB", {"job":{"path":os.path.relpath(moved_handle,self.base)}})
        self.assertEqual(result["code"], "JOB_FINISHED")
        self.assertFalse(Path(result["artifacts"]["scientific_result"]["path"]).is_absolute())
        result_path = output / result["artifacts"]["scientific_result"]["path"]
        before = result_path.stat().st_mtime_ns
        again, _ = self.call("COLLECT_JOB", {"job":{"path":str(moved_handle)}})
        self.assertEqual(again["code"], "JOB_FINISHED")
        self.assertEqual(result_path.stat().st_mtime_ns, before)

    def test_exit_failure_and_missing_result_are_terminal_failure(self):
        for mode in ("exit-failure", "missing"):
            with self.subTest(mode=mode):
                handle = self.submit(mode)
                terminal = self.terminal(handle)
                self.assertEqual(terminal["status"], "failed")
                result, _ = self.call("COLLECT_JOB", {"job":{"path":str(handle)}})
                self.assertEqual(result["code"], "JOB_FAILED")
                watched, watch = self.watch(self.watch_payload(handle.with_name("terminal.json"),
                                                               terminal["job_id"], terminal["run_id"]))
                self.assertEqual(watched["code"], "EVENT_DELIVERED")
                self.assertEqual(read(watch.with_name("event.json"))["outcome"], "failed")

    def test_scientific_fail_and_inconclusive_are_completed_calls(self):
        for mode, expected in (("science-failure","FAIL"),("science-inconclusive","INCONCLUSIVE")):
            with self.subTest(scientific_status=expected):
                handle = self.submit(mode)
                terminal = self.terminal(handle)
                self.assertEqual(terminal["status"], "succeeded")
                self.assertEqual(terminal["scientific_status"], expected)
                result, _ = self.call("COLLECT_JOB", {"job":{"path":str(handle)}})
                self.assertEqual(result["code"], "JOB_FINISHED")
                self.assertEqual(result["summary"]["scientific_status"], expected)
                watched, watch = self.watch(self.watch_payload(handle.with_name("terminal.json"),
                                                               terminal["job_id"],terminal["run_id"]))
                self.assertEqual(watched["code"], "EVENT_DELIVERED")
                event = read(watch.with_name("event.json"))
                self.assertEqual(event["scientific_status"], expected)
                self.assertFalse(event["scientific_acceptance"])

    def test_saved_supervisor_environment_restores_selection_and_removes_null(self):
        original = self.submit()
        self.terminal(original)
        for selected in (str(self.science / "components.json"), None):
            with self.subTest(selected=selected):
                directory = self.base / ("restored selected" if selected else "restored defaults")
                directory.mkdir()
                job = read(original)
                job["job_id"] = directory.name
                invocation = read(original.with_name("invocation.json"))
                invocation["command"][-1] = str(directory / "science")
                invocation["runtime_environment"]["CANON_COMPONENTS"] = selected
                write(directory / "job.json", job)
                write(directory / "invocation.json", invocation)
                changed = {**self.env,"CANON_COMPONENTS":"different-package.json","DECLARED_TEST_MARKER":"changed"}
                completed = subprocess.run([sys.executable,str(self.package / "local_jobs.py"),
                                            "--supervise",str(directory / "job.json")],
                                           env=changed, capture_output=True, text=True, timeout=4)
                self.assertEqual(completed.returncode, 0, completed.stderr)
                self.assertEqual(read(directory / "terminal.json")["status"], "succeeded")
                result = read(directory / "science" / "result.json")
                self.assertEqual(result["summary"]["components"], selected)
                self.assertEqual(result["summary"]["marker"], "explicit")

    def test_cancel_terminates_same_group_descendant_and_notifies(self):
        handle = self.submit("grandchild")
        pid_file = handle.parent / "science" / "descendant.pid"
        wait_until(pid_file.exists)
        # Let the descendant install its SIGTERM handler; it survives leader TERM.
        time.sleep(0.06)
        pid = int(pid_file.read_text())
        cancelled, _ = self.call("CANCEL_JOB", {"job":{"path":str(handle)}})
        self.assertEqual(cancelled["code"], "JOB_CANCEL_REQUESTED")
        terminal = self.terminal(handle)
        self.assertEqual(terminal["status"], "cancelled")
        result, _ = self.call("COLLECT_JOB", {"job":{"path":str(handle)}})
        self.assertEqual(result["code"], "JOB_CANCELLED")
        # ps reports zombies as already terminated on hosts whose init reaps later.
        status = subprocess.run(["ps","-o","stat=","-p",str(pid)], capture_output=True, text=True)
        self.assertTrue(not status.stdout.strip() or status.stdout.strip().startswith("Z"), status.stdout)
        watched, watch = self.watch(self.watch_payload(handle.with_name("terminal.json"),
                                                       terminal["job_id"],terminal["run_id"]))
        self.assertEqual(watched["code"], "EVENT_DELIVERED")
        self.assertEqual(read(watch.with_name("event.json"))["outcome"], "cancelled")

    def test_retry_restart_duplicate_scan_and_lost_ack_receiver_dedup(self):
        result, handle = self.watch(self.watch_payload(self.checkpoint(), callback_mode="fail-first"))
        self.assertEqual(result["code"], "DELIVERY_PENDING")
        event = read(handle.with_name("event.json"))
        delivery = read(handle.with_name("delivery.json"))
        self.assertEqual((delivery["state"],delivery["attempts"]), ("pending",1))
        result, _ = self.watch({"watch":{"path":str(handle)}})
        self.assertEqual(result["code"], "EVENT_DELIVERED")
        result, _ = self.watch({"watch":{"path":str(handle)}})
        self.assertEqual(read(self.base / "receiver.json")["calls"], 2)
        # Emulate a crash after receiver acceptance but before local ack persistence.
        handle.with_name("delivery.json").unlink()
        result, _ = self.watch({"watch":{"path":str(handle)}})
        receiver = read(self.base / "receiver.json")
        self.assertEqual(receiver["calls"], 3)
        self.assertEqual(len(receiver["accepted"]), 1)
        self.assertEqual(read(handle.with_name("event.json"))["event_id"], event["event_id"])
        self.assertEqual(receiver["accepted"][event["event_id"]]["session"], "fake-session")

    def test_stale_run_is_rejected_before_delivery(self):
        result, _ = self.watch(self.watch_payload(self.checkpoint(run_id="old-run")))
        self.assertEqual(result["status"], "ERROR")
        self.assertIn("CHECKPOINT_IDENTITY_MISMATCH", result["summary"]["reason"])
        self.assertFalse((self.base / "receiver.json").exists())
        handle = self.submit()
        terminal = self.terminal(handle)
        terminal["run_id"] = "old-run"
        write(handle.with_name("terminal.json"), terminal)
        result, _ = self.call("COLLECT_JOB", {"job":{"path":str(handle)}})
        self.assertEqual(result["status"], "ERROR")

    def test_background_completion_and_pending_watch_cancellation(self):
        path = self.base / "delayed checkpoint.json"
        result, handle = self.watch({**self.watch_payload(path),"mode":"background"})
        self.assertEqual(result["code"], "WATCH_STARTED")
        self.checkpoint("delayed checkpoint.json")
        wait_until(lambda: handle.with_name("delivery.json").exists() and
                   read(handle.with_name("delivery.json"))["state"] == "acknowledged")
        wait_until(lambda: not read(handle.with_name("monitor.json"))["running"])
        pending = self.base / "absent checkpoint.json"
        result, other = self.watch({**self.watch_payload(pending), "mode":"background", "interval_seconds":30})
        wait_until(other.with_name("monitor.json").exists)
        result, _ = self.call("CANCEL_WATCH", {"watch":{"path":str(other)}})
        wait_until(lambda: not read(other.with_name("monitor.json"))["running"])
        self.assertFalse(other.with_name("event.json").exists())

    def test_fixed_check_argv_and_pending_one_shot(self):
        raw = self.base / "external checkpoint.json"
        write(raw, {"job_id":"fixture-job","run_id":"fixture-run","done":False,"outcome":"failed"})
        payload = {**self.watch_payload(raw),"check":{"argv":[sys.executable,"fixed check.py"],"cwd":"."}}
        result, handle = self.watch(payload)
        self.assertEqual(result["code"], "CHECKPOINT_PENDING")
        self.assertFalse(handle.with_name("event.json").exists())
        write(raw, {"job_id":"fixture-job","run_id":"fixture-run","done":True,"outcome":"failed"})
        result, _ = self.watch({"watch":{"path":str(handle)}})
        self.assertEqual(result["code"], "EVENT_DELIVERED")
        self.assertEqual(read(handle.with_name("event.json"))["outcome"], "failed")
        self.assertNotIn("schema",read(raw))

    def test_callback_timeout_retains_event_for_retry(self):
        sleeper = self.base / "sleep callback.py"
        sleeper.write_text("import time\ntime.sleep(30)\n")
        payload = self.watch_payload(self.checkpoint())
        payload["callback"] = {"argv":[sys.executable,"sleep callback.py"],"timeout_seconds":0.05}
        result, handle = self.watch(payload)
        self.assertEqual(result["code"], "DELIVERY_PENDING")
        self.assertEqual(read(handle.with_name("delivery.json"))["reason"], "timeout")
        self.assertTrue(handle.with_name("event.json").exists())

    def test_check_failure_notifies_without_marking_computation_failed(self):
        checker = self.base / "failing check.py"
        checker.write_text("from pathlib import Path\nimport sys\nPath('check-called').write_text('once')\nsys.exit(4)\n")
        checkpoint = self.checkpoint()
        payload = self.watch_payload(checkpoint,callback_mode="fail-first")
        payload["check"] = {"argv":[sys.executable,"failing check.py"],"cwd":"."}
        result, handle = self.watch(payload)
        self.assertEqual(result["code"], "DELIVERY_PENDING")
        event = read(handle.with_name("event.json"))
        self.assertEqual((event["event_kind"],event["outcome"]), ("watch_error","check_error"))
        self.assertFalse(event["computation_terminal"])
        self.assertEqual(read(checkpoint)["status"], "succeeded")
        before = (self.base / "check-called").stat().st_mtime_ns
        result, _ = self.watch({"watch":{"path":str(handle)}})
        self.assertEqual(result["code"], "EVENT_DELIVERED")
        self.assertEqual((self.base / "check-called").stat().st_mtime_ns,before)

    def test_callback_launch_failure_stays_pending(self):
        payload = self.watch_payload(self.checkpoint())
        payload["callback"] = {"argv":[str(self.base / "absent callback executable")]}
        result, handle = self.watch(payload)
        self.assertEqual(result["code"], "DELIVERY_PENDING")
        self.assertEqual(read(handle.with_name("delivery.json"))["state"], "pending")
        self.assertIsNone(read(handle.with_name("delivery.json"))["returncode"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
