"""Detached single-invocation jobs; collection never launches computation."""

import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import uuid

from support import envelope, identity, lock, now, positive, process_capability
from support import read, reference, resolve, run_owned, same_identity, write


def load_job(request, payload):
    path = resolve(request, payload["job"])
    job = read(path)
    if job["schema"] != "canon-neu/local-job/v1":
        raise ValueError("unsupported job handle")
    return path, job


def checkpoint(path, job):
    terminal = resolve(path, job["checkpoint"])
    if not terminal.exists():
        return terminal, None
    value = read(terminal)
    same_identity(value, job)
    return terminal, value


def submit(canon, request, task, output):
    process_capability()
    payload = task["payload"]
    run_id = payload["run_id"]
    if not isinstance(run_id, str) or not run_id:
        raise ValueError("run_id must be a nonempty caller-declared string")
    source = resolve(request, payload["request"])
    scientific = read(source)
    job_dir = output / "job"
    job_dir.mkdir()
    handle = job_dir / "job.json"
    environment = os.environ.copy()
    overrides = payload.get("environment", {})
    environment.update(overrides)
    command = [sys.executable, str(canon / "run_step.py"), str(source), str(job_dir / "science"), "--describe"]
    if "components" in payload:
        selections = payload["components"]
        if not selections:
            command.append("--defaults")
        for item in selections:
            command += ["--components", str(resolve(request, item))]
    if "method" in payload:
        command += ["--method", payload["method"]]
    described = subprocess.run(command, env=environment, text=True, capture_output=True, check=True)
    invocation = json.loads(described.stdout)
    selected = invocation["components"]
    environment["CANON_PYTHON"] = sys.executable
    if selected:
        environment["CANON_COMPONENTS"] = selected[0] if len(selected) == 1 else json.dumps(selected)
    else:
        environment.pop("CANON_COMPONENTS", None)
    invocation.update(cwd=str(source.parent),
                      environment_overrides=overrides,
                      runtime_environment={name: environment.get(name) for name in
                                           ("CANON_COMPONENTS", "CANON_PYTHON")},
                      note="Resolved execution metadata; not relocated artifact references.")
    write(job_dir / "invocation.json", invocation)
    job = {"schema": "canon-neu/local-job/v1", "job_id": uuid.uuid4().hex,
           "run_id": run_id, "task_id": scientific["task_id"], "step": scientific["step"],
           "submitted_at": now(), "invocation": {"path": "invocation.json"},
           "checkpoint": {"path": "terminal.json"}, "result": {"path": "science/result.json"},
           "cancel_request": {"path": "cancel.json"},
           "cancel_grace_seconds": positive(payload.get("cancel_grace_seconds", 1.0))}
    write(handle, job)
    with (job_dir / "supervisor.log").open("ab") as log:
        supervisor = subprocess.Popen([sys.executable, str(Path(__file__).with_name("local_jobs.py")),
                                       "--supervise", str(handle)], env=environment,
                                      stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                                      start_new_session=True, close_fds=True)
    write(job_dir / "launcher.json", {"supervisor_pid": supervisor.pid, **identity(job),
                                      "pid_use": "informational only; cancellation uses cancel.json"})
    return envelope(task, output, "PROVISIONAL", "JOB_SUBMITTED",
                    {"job": reference(output / "result.json", handle)}, **identity(job))


def supervise(handle):
    job = read(handle)
    directory = handle.parent
    invocation = read(resolve(handle, job["invocation"]))
    environment = os.environ.copy()
    environment.update(invocation["environment_overrides"])
    for key, value in invocation["runtime_environment"].items():
        if value is None:
            environment.pop(key, None)
        else:
            environment[key] = value
    interrupted = False

    def stop(_signum, _frame):
        nonlocal interrupted
        interrupted = True

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    def cancelled():
        path = resolve(handle, job["cancel_request"])
        return interrupted or (path.exists() and identity(read(path)) == identity(job))

    with lock(directory / "supervisor.lock"):
        if resolve(handle, job["checkpoint"]).exists():
            return
        returncode, reason, scientific = None, None, None
        try:
            if cancelled():
                reason = "cancelled"
            else:
                with (directory / "science.log").open("wb") as log:
                    returncode, reason = run_owned(
                        invocation["command"], invocation["cwd"], environment, log,
                        cancelled=cancelled, grace=job["cancel_grace_seconds"],
                        launched=lambda pid: write(directory / "owner.json", {
                            **identity(job), "supervisor_pid": os.getpid(), "child_pid": pid,
                            "process_group": pid, "started_at": now()}))
            result_path = resolve(handle, job["result"])
            if result_path.exists():
                scientific = read(result_path)
                if (scientific["schema"] != "canon-neu/script-result/v1" or
                        scientific["task_id"] != job["task_id"] or scientific["step"] != job["step"]):
                    raise ValueError("scientific result identity mismatch")
            outcome = ("cancelled" if reason == "cancelled" else "succeeded" if
                       returncode == 0 and scientific
                       else "failed")
            detail = {"scientific_status": scientific["status"] if scientific else None,
                      "scientific_code": scientific["code"] if scientific else None}
        except Exception as exc:
            outcome, detail = "failed", {"error": str(exc)}
        terminal = {"schema": "canon-neu/local-checkpoint/v1", **identity(job),
                    "task_id": job["task_id"], "terminal": True, "status": outcome,
                    "returncode": returncode, "finished_at": now(), "reason": reason,
                    "result": job["result"] if scientific else None,
                    "scientific_acceptance": False, **detail}
        write(resolve(handle, job["checkpoint"]), terminal)


def collect(request, task, output):
    handle, job = load_job(request, task["payload"])
    terminal_path, terminal = checkpoint(handle, job)
    artifacts = {"job": reference(output / "result.json", handle)}
    if terminal is None:
        return envelope(task, output, "PROVISIONAL", "JOB_RUNNING", artifacts, **identity(job))
    artifacts["checkpoint"] = reference(output / "result.json", terminal_path)
    if terminal.get("result"):
        artifacts["scientific_result"] = reference(output / "result.json", resolve(terminal_path, terminal["result"]))
    status, code = {"succeeded": ("PROVISIONAL", "JOB_FINISHED"),
                    "failed": ("ERROR", "JOB_FAILED"),
                    "cancelled": ("INCONCLUSIVE", "JOB_CANCELLED")}[terminal["status"]]
    return envelope(task, output, status, code, artifacts, **identity(job),
                    outcome=terminal["status"], returncode=terminal["returncode"],
                    scientific_status=terminal.get("scientific_status"),
                    scientific_code=terminal.get("scientific_code"))


def cancel(request, task, output):
    handle, job = load_job(request, task["payload"])
    _, terminal = checkpoint(handle, job)
    if terminal is None:
        write(resolve(handle, job["cancel_request"]), {
            **identity(job), "requested_at": now(), "reason": task["payload"].get("reason", "caller request")})
    return envelope(task, output, "PROVISIONAL", "JOB_ALREADY_TERMINAL" if terminal else "JOB_CANCEL_REQUESTED",
                    {"job": reference(output / "result.json", handle)}, **identity(job))
