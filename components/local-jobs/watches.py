"""Checkpoint-only file outbox with an at-least-once command callback."""

import hashlib
import os
from pathlib import Path
import subprocess
import sys
import time
import uuid

from support import envelope, identity, lock, now, positive, read, reference, resolve
from support import run_owned, same_identity, write


def load_watch(request, payload):
    path = resolve(request, payload["watch"])
    value = read(path)
    if value["schema"] != "canon-neu/local-watch/v1":
        raise ValueError("unsupported watch handle")
    return path, value


def command_spec(request, handle, spec):
    argv = spec["argv"]
    if not isinstance(argv, list) or not argv or not all(isinstance(arg, str) for arg in argv):
        raise ValueError("command argv must be a nonempty string array")
    return {"argv": argv, "cwd": reference(handle, resolve(request, spec.get("cwd", "."))),
            "timeout_seconds": positive(spec.get("timeout_seconds", 30))}


def create(request, payload, output):
    directory = output / "watch"
    directory.mkdir()
    handle = directory / "watch.json"
    target = payload["target"]
    for key in ("host", "session", "message"):
        if not isinstance(target[key], str) or not target[key]:
            raise ValueError(f"target.{key} must be a nonempty fixed string")
    value = {"schema": "canon-neu/local-watch/v1", "watch_id": uuid.uuid4().hex,
             **identity(payload), "created_at": now(),
             "checkpoint": reference(handle, resolve(request, payload["checkpoint"])),
             "target": target, "callback": command_spec(request, handle, payload["callback"]),
             "interval_seconds": positive(payload.get("interval_seconds", 5)),
             "check": command_spec(request, handle, payload["check"]) if payload.get("check") else None}
    write(handle, value)
    return handle, value


def is_cancelled(handle, watch):
    path = handle.with_name("cancel.json")
    return path.exists() and read(path)["watch_id"] == watch["watch_id"]


def run_command(handle, watch, spec, argument, name):
    log_path = handle.with_name(name + ".log")
    with log_path.open("wb") as log:
        returncode, reason = run_owned([*spec["argv"], str(argument)],
                                      resolve(handle, spec["cwd"]), os.environ.copy(), log,
                                      cancelled=lambda: is_cancelled(handle, watch),
                                      timeout=spec["timeout_seconds"], grace=0.1)
    return returncode, reason, log_path


def scan(handle, watch):
    with lock(handle.with_name("scan.lock")):
        if is_cancelled(handle, watch):
            return "PROVISIONAL", "WATCH_CANCELLED"
        event_path, delivery_path = handle.with_name("event.json"), handle.with_name("delivery.json")
        if delivery_path.exists() and read(delivery_path)["state"] == "acknowledged":
            return "PROVISIONAL", "EVENT_DELIVERED"
        if not event_path.exists():
            checkpoint_path = resolve(handle, watch["checkpoint"])
            check_error = None
            if watch["check"]:
                try:
                    returncode, reason, log_path = run_command(handle, watch, watch["check"], checkpoint_path, "check")
                    if returncode != 0:
                        check_error = {"returncode": returncode, "reason": reason, "at": now()}
                    else:
                        checkpoint = read(log_path)
                except (OSError, ValueError) as exc:
                    check_error = {"reason": str(exc), "at": now()}
                if is_cancelled(handle, watch):
                    return "PROVISIONAL", "WATCH_CANCELLED"
            elif checkpoint_path.exists():
                checkpoint = read(checkpoint_path)
            else:
                return "PROVISIONAL", "CHECKPOINT_PENDING"
            if check_error is None:
                same_identity(checkpoint, watch)
                if checkpoint["schema"] != "canon-neu/local-checkpoint/v1":
                    raise ValueError("unsupported checkpoint schema")
                if checkpoint["terminal"] is not True:
                    return "PROVISIONAL", "CHECKPOINT_PENDING"
                if checkpoint["status"] not in ("succeeded", "failed", "cancelled"):
                    raise ValueError("unsupported terminal checkpoint status")
            if watch["check"] and check_error is None:
                # A check command's normalized output is retained separately;
                # the original checkpoint is never rewritten by this monitor.
                checked_path = handle.with_name("checked-checkpoint.json")
                if checkpoint.get("result"):
                    checkpoint["result"] = reference(checked_path, resolve(checkpoint_path, checkpoint["result"]))
                write(checked_path, checkpoint)
                checkpoint_path = checked_path
            event = {"schema": "canon-neu/completion-event/v1",
                     "event_id": hashlib.sha256(watch["watch_id"].encode()).hexdigest(),
                     "watch_id": watch["watch_id"], **identity(watch), "created_at": now(),
                     "target": watch["target"], "outcome": "check_error" if check_error else checkpoint["status"],
                     "event_kind": "watch_error" if check_error else "terminal",
                     "computation_terminal": check_error is None,
                     "checkpoint": reference(event_path, checkpoint_path),
                     "scientific_acceptance": False}
            if check_error:
                error_path = handle.with_name("check-error.json")
                write(error_path, check_error)
                event["check_error"] = reference(event_path, error_path)
            elif checkpoint.get("result"):
                event["scientific_result"] = reference(event_path, resolve(checkpoint_path, checkpoint["result"]))
            if check_error is None:
                for key in ("scientific_status", "scientific_code"):
                    if key in checkpoint:
                        event[key] = checkpoint[key]
            write(event_path, event)
        delivery = read(delivery_path) if delivery_path.exists() else {
            "event_id": read(event_path)["event_id"], "state": "pending", "attempts": 0}
        delivery.update(attempts=delivery["attempts"] + 1, state="pending", last_attempt_at=now())
        write(delivery_path, delivery)
        try:
            returncode, reason, _ = run_command(handle, watch, watch["callback"], event_path, "callback")
        except OSError as exc:
            returncode, reason = None, str(exc)
        delivery.update(returncode=returncode, reason=reason)
        if returncode == 0:
            delivery.update(state="acknowledged", acknowledged_at=now())
        write(delivery_path, delivery)
        return ("PROVISIONAL", "EVENT_DELIVERED") if returncode == 0 else ("INCONCLUSIVE", "DELIVERY_PENDING")


def report(task, output, handle, status, code):
    artifacts = {"watch": reference(output / "result.json", handle)}
    for name in ("event", "delivery", "check-error"):
        path = handle.with_name(name + ".json")
        if path.exists():
            artifacts[name] = reference(output / "result.json", path)
    return envelope(task, output, status, code, artifacts,
                    delivery_semantics="at-least-once; receiver deduplicates event_id",
                    acknowledgment_scope="callback accepted delivery; no model-turn or scientific acceptance claim")


def watch(request, task, output):
    payload = task["payload"]
    handle, value = load_watch(request, payload) if "watch" in payload else create(request, payload, output)
    if payload.get("mode", "once") == "background":
        with handle.with_name("monitor.log").open("ab") as log:
            subprocess.Popen([sys.executable, str(Path(__file__).with_name("local_jobs.py")),
                              "--monitor", str(handle)], stdin=subprocess.DEVNULL,
                             stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        return report(task, output, handle, "PROVISIONAL", "WATCH_STARTED")
    if payload.get("mode", "once") != "once":
        raise ValueError("watch mode must be once or background")
    try:
        status, code = scan(handle, value)
    except BlockingIOError:
        status, code = "PROVISIONAL", "WATCH_BUSY"
    return report(task, output, handle, status, code)


def monitor(handle):
    value = read(handle)
    try:
        with lock(handle.with_name("monitor.lock")):
            write(handle.with_name("monitor.json"), {"watch_id": value["watch_id"], "pid": os.getpid(), "running": True})
            try:
                while True:
                    try:
                        status, code = scan(handle, value)
                    except BlockingIOError:
                        status, code = "PROVISIONAL", "WATCH_BUSY"
                    except (OSError, ValueError, KeyError) as exc:
                        status, code = "ERROR", str(exc)
                    write(handle.with_name("scan.json"), {"status": status, "code": code, "at": now()})
                    if code in ("EVENT_DELIVERED", "WATCH_CANCELLED") or status == "ERROR":
                        return
                    deadline = time.monotonic() + value["interval_seconds"]
                    while time.monotonic() < deadline and not is_cancelled(handle, value):
                        time.sleep(min(0.05, max(0, deadline - time.monotonic())))
            finally:
                write(handle.with_name("monitor.json"), {"watch_id": value["watch_id"], "pid": os.getpid(), "running": False})
    except BlockingIOError:
        return


def cancel(request, task, output):
    handle, value = load_watch(request, task["payload"])
    write(handle.with_name("cancel.json"), {"watch_id": value["watch_id"], "requested_at": now()})
    return report(task, output, handle, "PROVISIONAL", "WATCH_CANCEL_REQUESTED")
