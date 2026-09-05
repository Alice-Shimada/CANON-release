"""Codex-specific caller guard for the statemng MCP facade.

The guard is enabled only by the installed Codex launcher.  It relies on the
Codex host replacing ``params._meta.threadId`` on every tool call; it is a
workflow isolation boundary, not protection from another local process.
"""

from __future__ import annotations

import fcntl
import hashlib
import json
import os
import stat
import tempfile
import uuid
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterator


GUARD_VERSION = 1
ENABLED_ENV = "STATEMNG_CODEX_THREAD_GUARD"
AUTHORITY_ROOT_ENV = "STATEMNG_CODEX_AUTHORITY_ROOT"
WORKER_TOOLS = frozenset(
    {
        "statemng_task_claim",
        "statemng_task_show",
        "statemng_artifact_add",
        "statemng_task_submit",
        "statemng_task_block",
        "statemng_task_fail",
    }
)
BOOTSTRAP_TOOLS = frozenset({"statemng_init", "statemng_project_resume"})
PUBLIC_TOOLS = frozenset({"statemng_project_list"})


class GuardError(Exception):
    """A stable authorization failure returned before the CLI is started."""

    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message

    def payload(self) -> dict[str, Any]:
        return {"ok": False, "error": self.code, "message": self.message}


def canonical_thread_id(meta: Any) -> str:
    if not isinstance(meta, dict):
        raise GuardError("CODEX_CALLER_ID_REQUIRED", "params._meta must be an object")
    raw = meta.get("threadId")
    if not isinstance(raw, str) or not raw:
        raise GuardError(
            "CODEX_CALLER_ID_REQUIRED", "params._meta.threadId is required"
        )
    try:
        parsed = uuid.UUID(raw)
    except (ValueError, AttributeError) as exc:
        raise GuardError(
            "CODEX_CALLER_ID_INVALID", "params._meta.threadId must be a UUID"
        ) from exc
    canonical = str(parsed)
    if raw != canonical:
        raise GuardError(
            "CODEX_CALLER_ID_INVALID",
            "params._meta.threadId must use canonical lowercase UUID form",
        )
    return canonical


def validate_task_name(task_name: Any) -> str:
    if (
        not isinstance(task_name, str)
        or not task_name
        or task_name in {".", ".."}
        or "/" in task_name
        or "\\" in task_name
        or "\x00" in task_name
    ):
        raise GuardError("CODEX_TASK_SCOPE_INVALID", "task_name is invalid")
    return task_name


def authority_directory(home: Path, project_root: Path) -> Path:
    checkout = str(project_root.resolve()).encode("utf-8")
    checkout_hash = hashlib.sha256(checkout).hexdigest()
    return home / ".codex" / "statemng" / "CANON" / "authorization" / checkout_hash


def ensure_private_directory(path: Path) -> None:
    if path.is_symlink():
        raise GuardError("CODEX_AUTHORITY_INVALID", "authority root is a symbolic link")
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    path.chmod(0o700)
    mode = stat.S_IMODE(path.stat().st_mode)
    if not path.is_dir() or mode != 0o700:
        raise GuardError(
            "CODEX_AUTHORITY_INVALID", "authority root must be a 0700 directory"
        )


def _record_key(task_name: str) -> str:
    return hashlib.sha256(task_name.encode("utf-8")).hexdigest()


@dataclass
class Authorization:
    role: str
    thread_id: str
    task_name: str | None
    bind_on_success: bool = False
    succeeded: bool = False

    def complete(self, succeeded: bool) -> None:
        self.succeeded = succeeded

    def metadata(self) -> dict[str, Any]:
        allowed: list[str] | str
        if self.role == "worker":
            allowed = sorted(WORKER_TOOLS)
        elif self.role == "bootstrap":
            allowed = sorted(PUBLIC_TOOLS)
        else:
            allowed = "all"
        return {
            "enforced": True,
            "guard": "codex-thread-coordinator",
            "version": GUARD_VERSION,
            "caller_role": self.role,
            "task_name": self.task_name,
            "allowed_tools": allowed,
            "main_only_tools": ["statemng_task_accept", "statemng_task_unblock"],
        }


class CodexThreadGuard:
    def __init__(self, authority_root: Path, project_root: Path):
        self.authority_root = authority_root
        self.project_root = project_root.resolve()
        self._validate_root()

    @classmethod
    def from_environment(cls, project_root: Path) -> CodexThreadGuard | None:
        enabled = os.environ.get(ENABLED_ENV)
        if enabled is None:
            return None
        if enabled != "1":
            raise GuardError(
                "CODEX_GUARD_CONFIGURATION_INVALID",
                f"{ENABLED_ENV} must equal 1 when set",
            )
        raw_root = os.environ.get(AUTHORITY_ROOT_ENV)
        if not raw_root:
            raise GuardError(
                "CODEX_GUARD_CONFIGURATION_INVALID",
                f"{AUTHORITY_ROOT_ENV} is required",
            )
        root = Path(raw_root)
        if not root.is_absolute():
            raise GuardError(
                "CODEX_GUARD_CONFIGURATION_INVALID", "authority root must be absolute"
            )
        return cls(root, project_root)

    def _validate_root(self) -> None:
        if self.authority_root.is_symlink() or not self.authority_root.is_dir():
            raise GuardError(
                "CODEX_AUTHORITY_INVALID", "authority root must be an existing directory"
            )
        if stat.S_IMODE(self.authority_root.stat().st_mode) != 0o700:
            raise GuardError(
                "CODEX_AUTHORITY_INVALID", "authority root must use mode 0700"
            )

    def _paths(self, task_name: str) -> tuple[Path, Path]:
        key = _record_key(task_name)
        return self.authority_root / f"{key}.json", self.authority_root / f"{key}.lock"

    @contextmanager
    def _task_lock(self, task_name: str) -> Iterator[None]:
        _, lock_path = self._paths(task_name)
        flags = os.O_RDWR | os.O_CREAT
        if hasattr(os, "O_NOFOLLOW"):
            flags |= os.O_NOFOLLOW
        try:
            descriptor = os.open(lock_path, flags, 0o600)
        except OSError as exc:
            raise GuardError(
                "CODEX_AUTHORITY_INVALID", "cannot open authority lock"
            ) from exc
        with os.fdopen(descriptor, "a+b") as handle:
            if stat.S_IMODE(os.fstat(handle.fileno()).st_mode) & 0o077:
                raise GuardError(
                    "CODEX_AUTHORITY_INVALID", "authority lock must use mode 0600"
                )
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
            try:
                yield
            finally:
                fcntl.flock(handle.fileno(), fcntl.LOCK_UN)

    def _read(self, task_name: str) -> dict[str, Any] | None:
        record_path, _ = self._paths(task_name)
        if record_path.is_symlink():
            raise GuardError(
                "CODEX_AUTHORITY_INVALID", "coordinator record is a symbolic link"
            )
        if not record_path.exists():
            return None
        if not record_path.is_file():
            raise GuardError(
                "CODEX_AUTHORITY_INVALID", "coordinator record is not a file"
            )
        if stat.S_IMODE(record_path.stat().st_mode) & 0o077:
            raise GuardError(
                "CODEX_AUTHORITY_INVALID", "coordinator record must use mode 0600"
            )
        try:
            record = json.loads(record_path.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise GuardError(
                "CODEX_AUTHORITY_INVALID", "cannot read coordinator record"
            ) from exc
        expected = {
            "version": GUARD_VERSION,
            "project_root": str(self.project_root),
            "task_name": task_name,
        }
        if not isinstance(record, dict) or any(
            record.get(key) != value for key, value in expected.items()
        ):
            raise GuardError(
                "CODEX_AUTHORITY_INVALID", "coordinator record scope does not match"
            )
        canonical_thread_id({"threadId": record.get("thread_id")})
        return record

    @contextmanager
    def _audit_lock(self) -> Iterator[None]:
        lock_path = self.authority_root / ".audit.lock"
        flags = os.O_RDWR | os.O_CREAT
        if hasattr(os, "O_NOFOLLOW"):
            flags |= os.O_NOFOLLOW
        try:
            descriptor = os.open(lock_path, flags, 0o600)
        except OSError as exc:
            raise GuardError(
                "CODEX_AUTHORITY_INVALID", "cannot open audit lock"
            ) from exc
        with os.fdopen(descriptor, "a+b") as handle:
            if stat.S_IMODE(os.fstat(handle.fileno()).st_mode) & 0o077:
                raise GuardError(
                    "CODEX_AUTHORITY_INVALID", "audit lock must use mode 0600"
                )
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
            try:
                yield
            finally:
                fcntl.flock(handle.fileno(), fcntl.LOCK_UN)

    def _append_audit(self, entry: dict[str, Any]) -> None:
        audit_path = self.authority_root / "audit.jsonl"
        if audit_path.is_symlink():
            raise GuardError("CODEX_AUTHORITY_INVALID", "audit path is a symbolic link")
        flags = os.O_WRONLY | os.O_APPEND | os.O_CREAT
        if hasattr(os, "O_NOFOLLOW"):
            flags |= os.O_NOFOLLOW
        try:
            descriptor = os.open(audit_path, flags, 0o600)
        except OSError as exc:
            raise GuardError(
                "CODEX_AUTHORITY_INVALID", "cannot open audit log"
            ) from exc
        with os.fdopen(descriptor, "a", encoding="utf-8") as stream:
            if stat.S_IMODE(os.fstat(stream.fileno()).st_mode) & 0o077:
                raise GuardError(
                    "CODEX_AUTHORITY_INVALID", "audit log must use mode 0600"
                )
            stream.write(json.dumps(entry, ensure_ascii=False) + "\n")
            stream.flush()
            os.fsync(stream.fileno())

    def _write(self, task_name: str, thread_id: str) -> None:
        record_path, _ = self._paths(task_name)
        record = {
            "version": GUARD_VERSION,
            "project_root": str(self.project_root),
            "task_name": task_name,
            "thread_id": thread_id,
            "bound_at": datetime.now(timezone.utc).isoformat(),
        }
        data = (json.dumps(record, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
        temporary: Path | None = None
        try:
            descriptor, raw_path = tempfile.mkstemp(
                prefix=".coordinator-", dir=self.authority_root
            )
            temporary = Path(raw_path)
            with os.fdopen(descriptor, "wb") as stream:
                os.fchmod(stream.fileno(), 0o600)
                stream.write(data)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temporary, record_path)
            directory_descriptor = os.open(self.authority_root, os.O_RDONLY)
            try:
                os.fsync(directory_descriptor)
            finally:
                os.close(directory_descriptor)
        finally:
            if temporary is not None and temporary.exists():
                temporary.unlink()

    @contextmanager
    def authorize(
        self, tool_name: str, arguments: dict[str, Any], meta: Any
    ) -> Iterator[Authorization]:
        thread_id = canonical_thread_id(meta)
        if tool_name in PUBLIC_TOOLS:
            authorization = Authorization("bootstrap", thread_id, None)
            yield authorization
            return

        task_name = validate_task_name(arguments.get("task_name"))
        with self._task_lock(task_name):
            record = self._read(task_name)
            if record is None:
                if tool_name not in BOOTSTRAP_TOOLS:
                    raise GuardError(
                        "CODEX_COORDINATOR_NOT_BOUND",
                        "main Agent must initialize or resume the task before workers start",
                    )
                authorization = Authorization(
                    "coordinator", thread_id, task_name, bind_on_success=True
                )
            elif record["thread_id"] == thread_id:
                authorization = Authorization("coordinator", thread_id, task_name)
            elif tool_name in WORKER_TOOLS:
                authorization = Authorization("worker", thread_id, task_name)
            else:
                raise GuardError(
                    "CODEX_CALLER_NOT_AUTHORIZED",
                    f"{tool_name} is not available to this Codex worker",
                )

            if authorization.role == "worker":
                yield authorization
                return
            yield authorization
            if authorization.bind_on_success and authorization.succeeded:
                if self._read(task_name) is not None:
                    raise GuardError(
                        "CODEX_COORDINATOR_ALREADY_BOUND",
                        "another Codex thread bound the task coordinator",
                    )
                self._write(task_name, thread_id)

    def show(self, task_name: str) -> dict[str, Any] | None:
        task_name = validate_task_name(task_name)
        with self._task_lock(task_name):
            record = self._read(task_name)
            return dict(record) if record is not None else None

    def reset(self, task_name: str, expected_thread_id: str) -> dict[str, Any]:
        task_name = validate_task_name(task_name)
        expected_thread_id = canonical_thread_id({"threadId": expected_thread_id})
        with self._task_lock(task_name):
            record = self._read(task_name)
            if record is None:
                raise GuardError(
                    "CODEX_COORDINATOR_NOT_BOUND", "coordinator record does not exist"
                )
            if record["thread_id"] != expected_thread_id:
                raise GuardError(
                    "CODEX_COORDINATOR_MISMATCH",
                    "expected thread ID does not match the coordinator record",
                )
            operation_id = str(uuid.uuid4())
            audit = {
                "version": GUARD_VERSION,
                "action": "reset",
                "operation_id": operation_id,
                "project_root": str(self.project_root),
                "task_name": task_name,
                "thread_id": expected_thread_id,
            }
            with self._audit_lock():
                intent = {
                    **audit,
                    "phase": "intent",
                    "recorded_at": datetime.now(timezone.utc).isoformat(),
                }
                self._append_audit(intent)
                record_path, _ = self._paths(task_name)
                try:
                    record_path.unlink()
                    directory_descriptor = os.open(self.authority_root, os.O_RDONLY)
                    try:
                        os.fsync(directory_descriptor)
                    finally:
                        os.close(directory_descriptor)
                except OSError as exc:
                    raise GuardError(
                        "CODEX_AUTHORITY_RESET_FAILED",
                        "coordinator record could not be removed; reset is incomplete",
                    ) from exc
                completed = {
                    **audit,
                    "phase": "completed",
                    "recorded_at": datetime.now(timezone.utc).isoformat(),
                }
                self._append_audit(completed)
                return completed
