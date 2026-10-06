"""Small file and owned-process helpers for the optional local-jobs package."""

from contextlib import contextmanager
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import signal
import subprocess
import time
import uuid


def now():
    return datetime.now(timezone.utc).isoformat()


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def write(path, value):
    path = Path(path)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    with temporary.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)
    directory = os.open(path.parent, os.O_RDONLY)
    try:
        os.fsync(directory)
    finally:
        os.close(directory)


def resolve(declaring, value):
    return (Path(declaring).parent / (value["path"] if isinstance(value, dict) else value)).resolve()


def reference(declaring, target):
    return {"type": "json", "path": os.path.relpath(target, Path(declaring).parent)}


def identity(value):
    return {key: value[key] for key in ("job_id", "run_id")}


def same_identity(value, expected):
    if identity(value) != identity(expected):
        raise ValueError("CHECKPOINT_IDENTITY_MISMATCH")


def positive(value):
    value = float(value)
    if not 0 < value < float("inf"):
        raise ValueError("intervals and timeouts must be positive finite numbers")
    return value


def process_capability():
    if os.name != "posix" or not all(hasattr(os, name) for name in ("waitid", "WNOWAIT", "killpg")):
        raise ValueError("POSIX_PROCESS_GROUPS_REQUIRED")


@contextmanager
def lock(path):
    import fcntl

    with Path(path).open("a") as stream:
        fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        try:
            yield
        finally:
            fcntl.flock(stream, fcntl.LOCK_UN)


def run_owned(command, cwd, environment, log, cancelled=lambda: False, timeout=None,
              grace=1.0, launched=None):
    """Keep the direct child unreaped until its process group has been closed.

    WNOWAIT retains ownership of the group leader's PID during cancellation,
    including when the leader exits before a same-group descendant.
    Components creating separate process groups must forward cancellation.
    """
    process_capability()
    process = subprocess.Popen(command, cwd=cwd, env=environment, stdin=subprocess.DEVNULL,
                               stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
    started = time.monotonic()
    stopped = None
    reason = None

    def signal_group(sig):
        try:
            os.killpg(process.pid, sig)
        except ProcessLookupError:
            pass

    try:
        if launched:
            launched(process.pid)
        while True:
            elapsed = time.monotonic() - started
            exited = os.waitid(os.P_PID, process.pid, os.WEXITED | os.WNOHANG | os.WNOWAIT)
            if exited is not None:
                # A step owns its same-group children for the duration of its call.
                signal_group(signal.SIGKILL)
                return process.wait(), reason
            if stopped is None and (cancelled() or (timeout is not None and elapsed >= timeout)):
                reason = "cancelled" if cancelled() else "timeout"
                stopped = time.monotonic()
                signal_group(signal.SIGTERM)
            if stopped is not None and time.monotonic() - stopped >= grace:
                signal_group(signal.SIGKILL)
            time.sleep(0.02)
    finally:
        if process.returncode is None:
            signal_group(signal.SIGKILL)
            process.wait()


def envelope(task, output, status, code, artifacts=None, **summary):
    value = {"schema": "canon-neu/script-result/v1", "task_id": task["task_id"],
             "step": task["step"], "status": status, "code": code,
             "artifacts": artifacts or {}, "summary": {"scientific_acceptance": False, **summary}}
    write(output / "result.json", value)
    return 2 if status == "ERROR" else 0
