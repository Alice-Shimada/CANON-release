from __future__ import annotations

import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import unittest
from pathlib import Path
from unittest import mock


STATE_MANAGEMENT = Path(__file__).resolve().parents[1]
SERVER_PATH = STATE_MANAGEMENT / "mcp_server.py"


def load_server_module():
    spec = importlib.util.spec_from_file_location("statemng_mcp_server", SERVER_PATH)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class MCPProcess:
    def __init__(self, server: Path, cwd: Path, environment: dict[str, str] | None = None):
        self.process = subprocess.Popen(
            [sys.executable, str(server)],
            cwd=cwd,
            env=environment,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
        )
        self.request_id = 0

    def notify(self, method: str, params: dict | None = None) -> None:
        assert self.process.stdin is not None
        message = {"jsonrpc": "2.0", "method": method}
        if params is not None:
            message["params"] = params
        self.process.stdin.write(json.dumps(message) + "\n")
        self.process.stdin.flush()

    def request(self, method: str, params: dict | None = None) -> dict:
        assert self.process.stdin is not None
        assert self.process.stdout is not None
        self.request_id += 1
        message = {"jsonrpc": "2.0", "id": self.request_id, "method": method}
        if params is not None:
            message["params"] = params
        self.process.stdin.write(json.dumps(message) + "\n")
        self.process.stdin.flush()
        response = json.loads(self.process.stdout.readline())
        if response.get("id") != self.request_id:
            raise AssertionError(response)
        return response

    def call(
        self, name: str, arguments: dict | None = None, thread_id: str | None = None
    ) -> dict:
        params = {"name": name, "arguments": arguments or {}}
        if thread_id is not None:
            params["_meta"] = {"threadId": thread_id}
        response = self.request(
            "tools/call", params
        )
        if "error" in response:
            raise AssertionError(response)
        return response["result"]

    def close(self) -> None:
        if self.process.stdin is not None:
            self.process.stdin.close()
        try:
            return_code = self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.process.terminate()
            return_code = self.process.wait(timeout=5)
        stderr = self.process.stderr.read() if self.process.stderr is not None else ""
        if self.process.stdout is not None:
            self.process.stdout.close()
        if self.process.stderr is not None:
            self.process.stderr.close()
        if return_code != 0:
            raise AssertionError(f"MCP server exited {return_code}: {stderr}")


class MCPDefinitionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.server = load_server_module()

    def test_complete_tool_surface_and_main_only_descriptions(self) -> None:
        names = [item["name"] for item in self.server.TOOLS]
        self.assertEqual(
            names,
            [
                "statemng_init",
                "statemng_project_list",
                "statemng_project_resume",
                "statemng_task_create",
                "statemng_task_ready",
                "statemng_task_claim",
                "statemng_task_show",
                "statemng_artifact_add",
                "statemng_task_submit",
                "statemng_task_accept",
                "statemng_task_block",
                "statemng_task_unblock",
                "statemng_task_fail",
                "statemng_task_status",
                "statemng_task_list",
                "statemng_artifact_show",
                "statemng_artifact_list",
                "statemng_doctor",
            ],
        )
        for name in ("statemng_task_accept", "statemng_task_unblock"):
            self.assertIn("Main Agent only", self.server.TOOL_BY_NAME[name]["description"])

    def test_schemas_are_closed_and_read_only_annotations_are_accurate(self) -> None:
        read_only = {
            "statemng_project_list",
            "statemng_task_ready",
            "statemng_task_show",
            "statemng_task_status",
            "statemng_task_list",
            "statemng_artifact_show",
            "statemng_artifact_list",
            "statemng_doctor",
        }
        for item in self.server.TOOLS:
            self.assertFalse(item["inputSchema"]["additionalProperties"])
            self.assertEqual(item["annotations"]["readOnlyHint"], item["name"] in read_only)
        retryable = self.server.TOOL_BY_NAME["statemng_task_fail"]["inputSchema"]
        self.assertEqual(retryable["properties"]["retryable"]["type"], "boolean")

    def test_protocol_errors_do_not_reach_the_cli(self) -> None:
        response = self.server.handle(
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "tools/call",
                "params": {"name": "statemng_init", "arguments": {"task_name": "x"}},
            }
        )
        self.assertEqual(response["error"]["code"], -32602)

    def test_initialize_negotiates_only_supported_protocol_versions(self) -> None:
        for version in self.server.SUPPORTED_PROTOCOL_VERSIONS:
            with self.subTest(version=version):
                response = self.server.handle(
                    {
                        "jsonrpc": "2.0",
                        "id": 1,
                        "method": "initialize",
                        "params": {"protocolVersion": version},
                    }
                )
                self.assertEqual(response["result"]["protocolVersion"], version)
        unsupported = self.server.handle(
            {
                "jsonrpc": "2.0",
                "id": 2,
                "method": "initialize",
                "params": {"protocolVersion": "2099-01-01"},
            }
        )
        self.assertEqual(
            unsupported["result"]["protocolVersion"], self.server.PROTOCOL_VERSION
        )

    def test_cli_launch_failure_is_returned_as_a_tool_error(self) -> None:
        original = self.server.PROJECT_ROOT
        try:
            self.server.PROJECT_ROOT = Path("/definitely/missing/project")
            result = self.server.call_tool("statemng_project_list", {})
        finally:
            self.server.PROJECT_ROOT = original
        self.assertTrue(result["isError"])
        self.assertFalse(result["structuredContent"]["ok"])
        self.assertIn("cannot execute statemng", result["structuredContent"]["error"])
        response = self.server.handle(
            {
                "jsonrpc": "2.0",
                "id": 2,
                "method": "tools/call",
                "params": {"name": "missing", "arguments": {}},
            }
        )
        self.assertEqual(response["error"]["code"], -32602)

    def test_codex_guard_rejects_missing_or_invalid_caller_before_cli(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            authority = Path(temporary) / "authority"
            authority.mkdir(mode=0o700)
            environment = {
                "STATEMNG_CODEX_THREAD_GUARD": "1",
                "STATEMNG_CODEX_AUTHORITY_ROOT": str(authority),
            }
            invalid_meta = (
                None,
                [],
                {},
                {"threadId": ""},
                {"threadId": "not-a-uuid"},
                {"threadId": "00000000-0000-4000-8000-00000000000A"},
            )
            with mock.patch.dict(os.environ, environment, clear=False):
                for meta in invalid_meta:
                    with self.subTest(meta=meta), mock.patch.object(
                        self.server.subprocess, "run"
                    ) as run:
                        result = self.server.call_tool(
                            "statemng_project_list", {}, meta
                        )
                        self.assertTrue(result["isError"], result)
                        self.assertFalse(result["structuredContent"]["ok"])
                        run.assert_not_called()

    def test_caller_identity_cannot_be_supplied_as_a_tool_argument(self) -> None:
        response = self.server.handle(
            {
                "jsonrpc": "2.0",
                "id": 7,
                "method": "tools/call",
                "params": {
                    "name": "statemng_project_list",
                    "arguments": {
                        "_meta": {
                            "threadId": "00000000-0000-4000-8000-000000000001"
                        }
                    },
                },
            }
        )
        self.assertEqual(response["error"]["code"], -32602)


class MCPStdioEndToEndTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.project = Path(self.temporary.name) / "project"
        self.project.mkdir()
        shutil.copytree(STATE_MANAGEMENT, self.project / "state-management")
        self.unrelated_cwd = Path(self.temporary.name) / "unrelated"
        self.unrelated_cwd.mkdir()
        self.client = MCPProcess(
            self.project / "state-management" / "mcp_server.py", self.unrelated_cwd
        )

    def tearDown(self) -> None:
        self.client.close()
        self.temporary.cleanup()

    def write(self, relative: str, content: str) -> Path:
        path = self.project / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        return path

    def payload(self, result: dict) -> dict:
        text_payload = json.loads(result["content"][0]["text"])
        self.assertEqual(text_payload, result["structuredContent"])
        return result["structuredContent"]

    def call_ok(self, name: str, arguments: dict | None = None) -> dict:
        result = self.client.call(name, arguments)
        self.assertFalse(result["isError"], result)
        payload = self.payload(result)
        self.assertTrue(payload["ok"], payload)
        return payload

    def test_fresh_nested_checkout_never_uses_ancestor_state(self) -> None:
        goal = self.write("goal.md", "Isolate this checkout's state.\n")
        outer = self.project.parent
        initialized = subprocess.run(
            [sys.executable, str(STATE_MANAGEMENT / "statemng"),
             "init", "outer-sentinel", "--goal-file", str(goal)],
            cwd=outer, capture_output=True, text=True, check=False,
        )
        self.assertEqual(initialized.returncode, 0, initialized.stdout)
        outer_state = outer / ".state-management"
        original = {
            path.relative_to(outer_state): path.read_bytes()
            for path in outer_state.rglob("*") if path.is_file()
        }

        self.assertEqual(self.call_ok("statemng_project_list")["task_names"], [])
        self.assertFalse((self.project / ".state-management").exists())
        missing = self.client.call(
            "statemng_project_resume", {"task_name": "outer-sentinel"}
        )
        self.assertTrue(missing["isError"], missing)
        self.assertIn("was not found", self.payload(missing)["error"])

        (self.project / ".state-management").mkdir()
        self.assertEqual(self.call_ok("statemng_project_list")["task_names"], [])
        absent = self.client.call(
            "statemng_task_list", {"task_name": "outer-sentinel"}
        )
        self.assertTrue(absent["isError"], absent)
        self.assertEqual(self.payload(absent)["error"], "TASK_NOT_FOUND")

        local = self.call_ok(
            "statemng_init", {"task_name": "inner-study", "goal_file": "goal.md"}
        )
        self.assertEqual(
            Path(local["task_root"]), self.project / ".state-management" / "inner-study"
        )
        self.assertEqual(
            self.call_ok("statemng_project_list")["task_names"], ["inner-study"]
        )
        self.call_ok("statemng_project_resume", {"task_name": "inner-study"})
        self.assertEqual(
            original,
            {path.relative_to(outer_state): path.read_bytes()
             for path in outer_state.rglob("*") if path.is_file()},
        )

    def test_real_stdio_protocol_and_complete_research_lifecycle(self) -> None:
        initialized = self.client.request(
            "initialize",
            {
                "protocolVersion": "2025-11-25",
                "capabilities": {},
                "clientInfo": {"name": "test", "version": "1"},
            },
        )["result"]
        self.assertEqual(initialized["protocolVersion"], "2025-11-25")
        self.assertIn("tools", initialized["capabilities"])
        self.client.notify("notifications/initialized")
        listed = self.client.request("tools/list")["result"]["tools"]
        self.assertEqual(len(listed), 18)
        self.assertNotIn("_command", listed[0])

        self.write("goal.md", "# Goal\n\nProduce and verify a result.\n")
        initialized_task = self.call_ok(
            "statemng_init", {"task_name": "study", "goal_file": "goal.md"}
        )
        self.assertEqual(
            Path(initialized_task["task_root"]).resolve(),
            (self.project / ".state-management" / "study").resolve(),
        )
        self.assertEqual(
            self.call_ok("statemng_project_list")["task_names"], ["study"]
        )

        self.write(
            "description.json",
            json.dumps(
                {
                    "objective": "Derive the checked result.",
                    "background": "Use the stated assumptions.",
                    "acceptance_criteria": ["The artifact contains the verified result."],
                }
            ),
        )
        created = self.call_ok(
            "statemng_task_create",
            {
                "task_name": "study",
                "title": "Derive result",
                "description_file": "description.json",
            },
        )
        task_id = created["task_id"]
        ready = self.call_ok("statemng_task_ready", {"task_name": "study"})
        self.assertEqual([item["task_id"] for item in ready["tasks"]], [task_id])
        claimed = self.call_ok(
            "statemng_task_claim", {"task_name": "study", "task_id": task_id}
        )
        run_id = claimed["run_id"]
        shown = self.call_ok(
            "statemng_task_show",
            {"task_name": "study", "task_id": task_id, "run_id": run_id},
        )
        workspace = Path(shown["workspace"])
        self.assertTrue(workspace.is_dir())
        result_file = workspace / "result.md"
        summary_file = workspace / "summary.md"
        result_file.write_text("verified result\n", encoding="utf-8")
        summary_file.write_text("The result was verified.\n", encoding="utf-8")
        artifact = self.call_ok(
            "statemng_artifact_add",
            {
                "task_name": "study",
                "task_id": task_id,
                "run_id": run_id,
                "path": str(result_file),
            },
        )
        artifact_id = artifact["artifact_id"]
        submitted = self.call_ok(
            "statemng_task_submit",
            {
                "task_name": "study",
                "task_id": task_id,
                "run_id": run_id,
                "summary_file": str(summary_file),
                "artifact_id": artifact_id,
            },
        )
        self.assertEqual(submitted["status"], "submitted")
        accepted = self.call_ok(
            "statemng_task_accept",
            {"task_name": "study", "task_id": task_id, "run_id": run_id},
        )
        self.assertEqual(accepted["status"], "completed")
        self.assertEqual(
            self.call_ok(
                "statemng_artifact_show",
                {"task_name": "study", "artifact_id": artifact_id},
            )["sha256"],
            self.call_ok(
                "statemng_artifact_list",
                {"task_name": "study", "task_id": task_id},
            )["artifacts"][0]["sha256"],
        )
        self.assertEqual(
            self.call_ok("statemng_doctor", {"task_name": "study"})["issues"], []
        )
        resumed = self.call_ok("statemng_project_resume", {"task_name": "study"})
        self.assertEqual(resumed["tasks"][0]["status"], "completed")
        self.assertEqual(resumed["incomplete_runs"], [])

    def test_block_unblock_preserves_old_run_and_cli_errors_are_tool_errors(self) -> None:
        self.write("goal.md", "Goal\n")
        self.call_ok("statemng_init", {"task_name": "study", "goal_file": "goal.md"})
        self.write(
            "description.json",
            json.dumps(
                {
                    "objective": "Attempt the task.",
                    "background": "",
                    "acceptance_criteria": ["It works."],
                }
            ),
        )
        task_id = self.call_ok(
            "statemng_task_create",
            {
                "task_name": "study",
                "title": "Blocked task",
                "description_file": "description.json",
            },
        )["task_id"]
        first_run = self.call_ok(
            "statemng_task_claim", {"task_name": "study", "task_id": task_id}
        )["run_id"]
        workspace = (
            self.project / ".state-management" / "study" / "runs" / first_run / "workspace"
        )
        reason = workspace / "reason.md"
        reason.write_text("Required external input is absent.\n", encoding="utf-8")
        blocked = self.call_ok(
            "statemng_task_block",
            {
                "task_name": "study",
                "task_id": task_id,
                "run_id": first_run,
                "reason_file": str(reason),
            },
        )
        self.assertEqual(blocked["status"], "blocked")
        unblocked = self.call_ok(
            "statemng_task_unblock",
            {"task_name": "study", "task_id": task_id, "run_id": first_run},
        )
        self.assertEqual(unblocked["status"], "ready")
        status = self.call_ok(
            "statemng_task_status", {"task_name": "study", "task_id": task_id}
        )
        self.assertNotIn("run_id", status)
        old_run = json.loads(
            (self.project / ".state-management" / "study" / "runs" / first_run / "run.json").read_text(encoding="utf-8")
        )
        self.assertEqual(old_run["status"], "blocked")
        self.assertEqual(old_run["reason"], "Required external input is absent.\n")
        second_run = self.call_ok(
            "statemng_task_claim", {"task_name": "study", "task_id": task_id}
        )["run_id"]
        self.assertNotEqual(second_run, first_run)

        failed_call = self.client.call(
            "statemng_task_unblock",
            {"task_name": "study", "task_id": task_id, "run_id": first_run},
        )
        self.assertTrue(failed_call["isError"])
        self.assertFalse(self.payload(failed_call)["ok"])


class CodexThreadGuardEndToEndTests(unittest.TestCase):
    MAIN = "00000000-0000-4000-8000-000000000001"
    WORKER = "00000000-0000-4000-8000-000000000002"
    OTHER = "00000000-0000-4000-8000-000000000003"

    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.project = Path(self.temporary.name) / "project"
        self.project.mkdir()
        shutil.copytree(STATE_MANAGEMENT, self.project / "state-management")
        self.unrelated_cwd = Path(self.temporary.name) / "unrelated"
        self.unrelated_cwd.mkdir()
        self.authority = Path(self.temporary.name) / "authority"
        self.authority.mkdir(mode=0o700)
        self.environment = os.environ.copy()
        self.environment.update(
            {
                "STATEMNG_CODEX_THREAD_GUARD": "1",
                "STATEMNG_CODEX_AUTHORITY_ROOT": str(self.authority),
            }
        )
        self.clients: list[MCPProcess] = []

    def tearDown(self) -> None:
        for client in self.clients:
            client.close()
        self.temporary.cleanup()

    def client(self, *, guarded: bool = True) -> MCPProcess:
        client = MCPProcess(
            self.project / "state-management" / "mcp_server.py",
            self.unrelated_cwd,
            self.environment if guarded else os.environ.copy(),
        )
        self.clients.append(client)
        return client

    def write(self, relative: str, content: str) -> Path:
        path = self.project / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        return path

    def payload(self, result: dict) -> dict:
        return result["structuredContent"]

    def call_ok(
        self, client: MCPProcess, thread_id: str, name: str, arguments: dict | None = None
    ) -> dict:
        result = client.call(name, arguments, thread_id)
        self.assertFalse(result["isError"], result)
        payload = self.payload(result)
        self.assertTrue(payload["ok"], payload)
        return payload

    def create_task(self, main: MCPProcess, title: str = "Derive result") -> str:
        description = self.write(
            f"{title.replace(' ', '-')}.json",
            json.dumps(
                {
                    "objective": "Derive the checked result.",
                    "background": "Use the stated assumptions.",
                    "acceptance_criteria": ["The artifact contains the result."],
                }
            ),
        )
        return self.call_ok(
            main,
            self.MAIN,
            "statemng_task_create",
            {
                "task_name": "study",
                "title": title,
                "description_file": str(description),
            },
        )["task_id"]

    def snapshot_state(self) -> dict[str, bytes]:
        root = self.project / ".state-management" / "study"
        return {
            str(path.relative_to(root)): path.read_bytes()
            for path in root.rglob("*")
            if path.is_file()
        }

    def test_coordinator_worker_lifecycle_and_process_restart(self) -> None:
        main = self.client()
        worker = self.client()
        self.write("goal.md", "# Goal\n\nProduce a checked result.\n")
        self.call_ok(
            main,
            self.MAIN,
            "statemng_init",
            {"task_name": "study", "goal_file": "goal.md"},
        )
        task_id = self.create_task(main)

        denied_before_claim = worker.call(
            "statemng_task_accept",
            {"task_name": "study", "task_id": task_id, "run_id": "R-999"},
            self.WORKER,
        )
        self.assertTrue(denied_before_claim["isError"])
        self.assertEqual(
            self.payload(denied_before_claim)["error"],
            "CODEX_CALLER_NOT_AUTHORIZED",
        )

        run_id = self.call_ok(
            worker,
            self.WORKER,
            "statemng_task_claim",
            {"task_name": "study", "task_id": task_id},
        )["run_id"]
        shown = self.call_ok(
            worker,
            self.WORKER,
            "statemng_task_show",
            {"task_name": "study", "task_id": task_id, "run_id": run_id},
        )
        authorization = shown["codex_authorization"]
        self.assertTrue(authorization["enforced"])
        self.assertEqual(authorization["caller_role"], "worker")
        self.assertEqual(authorization["task_name"], "study")
        self.assertEqual(len(authorization["allowed_tools"]), 6)

        workspace = Path(shown["workspace"])
        result_file = workspace / "result.md"
        summary_file = workspace / "summary.md"
        result_file.write_text("verified result\n", encoding="utf-8")
        summary_file.write_text("The result was verified.\n", encoding="utf-8")
        artifact_id = self.call_ok(
            worker,
            self.WORKER,
            "statemng_artifact_add",
            {
                "task_name": "study",
                "task_id": task_id,
                "run_id": run_id,
                "path": str(result_file),
            },
        )["artifact_id"]
        shared_file = workspace / "shared-rules.wl"
        shared_file.write_text("shared exact rules\n", encoding="utf-8")
        shared_artifact = self.call_ok(
            worker, self.WORKER, "statemng_artifact_add",
            {
                "task_name": "study", "task_id": task_id, "run_id": run_id,
                "path": str(shared_file),
            },
        )["artifact_id"]
        self.call_ok(
            worker,
            self.WORKER,
            "statemng_task_submit",
            {
                "task_name": "study",
                "task_id": task_id,
                "run_id": run_id,
                "summary_file": str(summary_file),
                "artifact_id": artifact_id,
            },
        )

        before = self.snapshot_state()
        denied = worker.call(
            "statemng_task_accept",
            {"task_name": "study", "task_id": task_id, "run_id": run_id},
            self.WORKER,
        )
        self.assertTrue(denied["isError"])
        self.assertEqual(self.payload(denied)["error"], "CODEX_CALLER_NOT_AUTHORIZED")
        self.assertEqual(self.snapshot_state(), before)

        accepted = self.call_ok(
            main,
            self.MAIN,
            "statemng_task_accept",
            {"task_name": "study", "task_id": task_id, "run_id": run_id},
        )
        self.assertEqual(accepted["status"], "completed")
        consumer = self.call_ok(
            main, self.MAIN, "statemng_task_create",
            {
                "task_name": "study", "title": "Use registered inputs",
                "description_file": str(self.project / "Derive-result.json"),
                "depends_on": task_id,
            },
        )["task_id"]
        consumer_run = self.call_ok(
            worker, self.WORKER, "statemng_task_claim",
            {"task_name": "study", "task_id": consumer},
        )["run_id"]
        handoff = self.call_ok(
            worker, self.WORKER, "statemng_task_show",
            {"task_name": "study", "task_id": consumer, "run_id": consumer_run},
        )
        self.assertEqual(handoff["codex_authorization"]["caller_role"], "worker")
        self.assertEqual(len(handoff["codex_authorization"]["allowed_tools"]), 6)
        records = handoff["dependencies"][0]["artifacts"]
        self.assertEqual({r["artifact_id"] for r in records}, {artifact_id, shared_artifact})
        record = next(r for r in records if r["artifact_id"] == shared_artifact)
        self.assertEqual(
            (Path(handoff["project_root"]) / record["stored_path"]).read_text(),
            shared_file.read_text(),
        )
        self.assertEqual(list(Path(handoff["workspace"]).iterdir()), [])
        denied = worker.call(
            "statemng_artifact_show",
            {"task_name": "study", "artifact_id": shared_artifact}, self.WORKER,
        )
        self.assertTrue(denied["isError"])
        self.assertEqual(self.payload(denied)["error"], "CODEX_CALLER_NOT_AUTHORIZED")
        main.close()
        self.clients.remove(main)
        restarted = self.client()
        self.assertEqual(
            self.call_ok(
                restarted,
                self.MAIN,
                "statemng_project_resume",
                {"task_name": "study"},
            )["tasks"][0]["status"],
            "completed",
        )
        stolen = restarted.call(
            "statemng_project_resume", {"task_name": "study"}, self.OTHER
        )
        self.assertTrue(stolen["isError"])
        self.assertEqual(
            self.payload(stolen)["error"], "CODEX_CALLER_NOT_AUTHORIZED"
        )

    def test_failed_bootstrap_does_not_bind_and_first_bind_is_atomic(self) -> None:
        first = self.client()
        failed = first.call(
            "statemng_project_resume", {"task_name": "missing"}, self.MAIN
        )
        self.assertTrue(failed["isError"])
        self.assertEqual(list(self.authority.glob("*.json")), [])

        unguarded = self.client(guarded=False)
        self.write("goal.md", "Goal\n")
        result = unguarded.call(
            "statemng_init", {"task_name": "study", "goal_file": "goal.md"}
        )
        self.assertFalse(result["isError"], result)

        second = self.client()
        barrier = threading.Barrier(3)
        outcomes: list[dict] = []

        def resume(client: MCPProcess, thread_id: str) -> None:
            barrier.wait()
            outcomes.append(
                client.call(
                    "statemng_project_resume", {"task_name": "study"}, thread_id
                )
            )

        threads = [
            threading.Thread(target=resume, args=(first, self.MAIN)),
            threading.Thread(target=resume, args=(second, self.OTHER)),
        ]
        for thread in threads:
            thread.start()
        barrier.wait()
        for thread in threads:
            thread.join(timeout=10)
            self.assertFalse(thread.is_alive())
        self.assertEqual(sum(not item["isError"] for item in outcomes), 1)
        self.assertEqual(sum(item["isError"] for item in outcomes), 1)

    def test_worker_allowlist_rejects_all_other_task_scoped_tools(self) -> None:
        main = self.client()
        worker = self.client()
        self.write("goal.md", "Goal\n")
        self.call_ok(
            main,
            self.MAIN,
            "statemng_init",
            {"task_name": "study", "goal_file": "goal.md"},
        )
        task_id = self.create_task(main)
        calls = {
            "statemng_project_resume": {"task_name": "study"},
            "statemng_task_create": {
                "task_name": "study",
                "title": "No",
                "description_file": "unused.json",
            },
            "statemng_task_ready": {"task_name": "study"},
            "statemng_task_accept": {
                "task_name": "study",
                "task_id": task_id,
                "run_id": "R-999",
            },
            "statemng_task_unblock": {
                "task_name": "study",
                "task_id": task_id,
                "run_id": "R-999",
            },
            "statemng_task_status": {"task_name": "study", "task_id": task_id},
            "statemng_task_list": {"task_name": "study"},
            "statemng_artifact_show": {
                "task_name": "study",
                "artifact_id": "A-999",
            },
            "statemng_artifact_list": {"task_name": "study"},
            "statemng_doctor": {"task_name": "study"},
        }
        for name, arguments in calls.items():
            with self.subTest(name=name):
                denied = worker.call(name, arguments, self.WORKER)
                self.assertTrue(denied["isError"], denied)
                self.assertEqual(
                    self.payload(denied)["error"], "CODEX_CALLER_NOT_AUTHORIZED"
                )

        listed = self.call_ok(
            worker, self.WORKER, "statemng_project_list"
        )
        self.assertEqual(listed["task_names"], ["study"])


if __name__ == "__main__":
    unittest.main()
