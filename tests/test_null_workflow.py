from __future__ import annotations

import ast
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / "workflow.py"

PASS_CODES = {
    "PREPARE": "OK",
    "DISCOVER": "SECTORS_READY",
    "BUILD_CUT_DE": "OK",
    "SEARCH_CORE": "CANDIDATE_READY",
    "CHECK_CORE": "CORE_PASS",
    "BUILD_FULL_DE": "OK",
    "SOLVE_TAIL": "TAIL_READY",
    "CHECK_CANONICAL": "CANONICAL_PASS",
    "COMMIT_SECTOR": "OK",
    "FINAL_CHECK": "ALL_PASS",
}


class NullWorkflowTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.family = self.root / "family.json"
        self.family.write_text('{"null_family": true}\n', encoding="utf-8")
        self.project = self.root / "project.json"
        self.project.write_text(
            json.dumps(
                {
                    "schema": "canon-neu/project/v1",
                    "run_id": "null-run",
                    "run_root": "run",
                    "inputs": {
                        "family_spec": {
                            "type": "json",
                            "path": "family.json",
                        }
                    },
                    "options": {
                        "method_options": {},
                        "tail_options": {},
                    },
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        self.state_path = self.root / "run" / "state.json"
        self.report_number = 0
        self.cli("init", str(self.project))

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def cli(
        self, *arguments: str, check: bool = True
    ) -> subprocess.CompletedProcess[str]:
        completed = subprocess.run(
            [sys.executable, str(WORKFLOW), *arguments],
            cwd=ROOT,
            text=True,
            capture_output=True,
        )
        if check and completed.returncode != 0:
            self.fail(
                f"CLI failed ({completed.returncode}): "
                f"{' '.join(arguments)}\n"
                f"stdout:\n{completed.stdout}\n"
                f"stderr:\n{completed.stderr}"
            )
        return completed

    def state(self) -> dict:
        return json.loads(self.state_path.read_text(encoding="utf-8"))

    def task(self) -> dict:
        state = self.state()
        return state["tasks"][state["current_task"]]

    def start_current(self, expected_step: str) -> dict:
        task = self.task()
        self.assertEqual(task["step"], expected_step)
        self.cli(
            "start",
            str(self.state_path),
            task["task_id"],
            "--agent",
            "root",
        )
        return self.task()

    def write_main_result(
        self,
        task: dict,
        status: str = "PASS",
        code: str | None = None,
        summary: dict | None = None,
    ) -> Path:
        self.report_number += 1
        result_dir = self.root / "null-results" / f"r{self.report_number:03d}"
        result_dir.mkdir(parents=True)
        artifacts = {}
        if status == "PASS":
            for name in task["expected_outputs"]:
                artifact_path = result_dir / f"{name}.wl"
                artifact_path.write_text("NULL ARTIFACT\n", encoding="utf-8")
                artifacts[name] = {
                    "type": "null-artifact",
                    "path": artifact_path.name,
                }
        result = {
            "schema": "canon-neu/script-result/v1",
            "task_id": task["task_id"],
            "step": task["step"],
            "status": status,
            "code": code or PASS_CODES[task["step"]],
            "artifacts": artifacts,
            "summary": summary or {},
        }
        path = result_dir / "result.json"
        path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        return path

    def satisfy_delegation(self, task: dict, result_path: Path) -> None:
        if not task["delegation"]["required_roles"]:
            return
        subagent = f"sub-{task['task_id'].lower()}"
        role = task["delegation"]["required_roles"][0]
        script = task["scripts"][0]
        self.cli(
            "delegate",
            str(self.state_path),
            task["task_id"],
            "--agent",
            "root",
            "--subagent",
            subagent,
            "--role",
            role,
            "--script",
            script,
        )
        self.cli(
            "subreport",
            str(self.state_path),
            task["task_id"],
            str(result_path),
            "--subagent",
            subagent,
        )

    def complete(
        self,
        expected_step: str,
        status: str = "PASS",
        code: str | None = None,
        summary: dict | None = None,
    ) -> None:
        task = self.start_current(expected_step)
        result = self.write_main_result(task, status, code, summary)
        self.satisfy_delegation(task, result)
        self.cli(
            "report",
            str(self.state_path),
            task["task_id"],
            str(result),
        )

    def test_end_to_end_with_gates_and_recovery_loops(self) -> None:
        status = json.loads(
            self.cli("status", str(self.state_path), "--json").stdout
        )
        self.assertEqual(status["phase"], "PREPARE")
        packet = json.loads(
            self.cli("next", str(self.state_path), "--json").stdout
        )
        self.assertEqual(packet["task_id"], self.task()["task_id"])
        self.assertEqual(packet["commands"][0][0:2], ["wolframscript", "-file"])

        self.complete("PREPARE")
        self.complete(
            "DISCOVER",
            summary={
                "sectors": [
                    {"id": 9, "propagator_count": 3},
                    {"id": 2, "propagator_count": 2},
                ]
            },
        )

        state = self.state()
        self.assertEqual(
            state["sectors"],
            [
                {"id": 2, "propagator_count": 2},
                {"id": 9, "propagator_count": 3},
            ],
        )
        self.assertEqual(self.task()["sector"]["id"], 2)

        self.complete("BUILD_CUT_DE")

        search = self.start_current("SEARCH_CORE")
        blocked_report = self.write_main_result(search)
        rejected = self.cli(
            "report",
            str(self.state_path),
            search["task_id"],
            str(blocked_report),
            check=False,
        )
        self.assertEqual(rejected.returncode, 2)
        self.assertIn("required subagent reports are missing", rejected.stderr)
        self.assertEqual(self.task()["status"], "RUNNING")

        self.satisfy_delegation(search, blocked_report)
        self.cli(
            "report",
            str(self.state_path),
            search["task_id"],
            str(blocked_report),
        )

        self.complete("CHECK_CORE", status="FAIL", code="CORE_FAIL")
        retry_search = self.task()
        self.assertEqual(retry_search["step"], "SEARCH_CORE")
        self.assertEqual(retry_search["sector"]["id"], 2)
        self.assertEqual(retry_search["attempt"], 2)

        self.complete("SEARCH_CORE")
        self.complete("CHECK_CORE")
        self.complete("BUILD_FULL_DE")
        self.complete("SOLVE_TAIL")
        self.complete("CHECK_CANONICAL", status="FAIL", code="TAIL_FAIL")
        retry_tail = self.task()
        self.assertEqual(retry_tail["step"], "SOLVE_TAIL")
        self.assertEqual(retry_tail["sector"]["id"], 2)
        self.assertEqual(retry_tail["attempt"], 2)

        self.complete("SOLVE_TAIL")
        self.complete("CHECK_CANONICAL")
        self.complete("COMMIT_SECTOR")
        self.assertEqual(self.task()["step"], "BUILD_CUT_DE")
        self.assertEqual(self.task()["sector"]["id"], 9)

        self.complete("BUILD_CUT_DE")
        self.complete("SEARCH_CORE")
        self.complete("CHECK_CORE")
        self.complete("BUILD_FULL_DE")
        self.complete("SOLVE_TAIL")
        self.complete("CHECK_CANONICAL")
        self.complete("COMMIT_SECTOR")

        final_task = self.task()
        self.assertEqual(final_task["step"], "FINAL_CHECK")
        self.assertIsNone(final_task["sector"])
        self.complete("FINAL_CHECK")

        state = self.state()
        self.assertEqual(state["status"], "DONE")
        self.assertEqual(state["phase"], "DONE")
        self.assertIsNone(state["current_task"])
        self.assertEqual(
            [item["id"] for item in state["accepted"]], [2, 9]
        )
        self.assertTrue(
            all(task["status"] == "DONE" for task in state["tasks"].values())
        )
        self.assertIn("canonical_basis", state["artifacts"])
        self.assertIn("canonical_de", state["artifacts"])

    def test_sort_uses_propagator_count_then_sector_id(self) -> None:
        spec = importlib.util.spec_from_file_location("canon_neu_workflow", WORKFLOW)
        self.assertIsNotNone(spec)
        module = importlib.util.module_from_spec(spec)
        assert spec.loader is not None
        spec.loader.exec_module(module)
        sectors = module.sorted_sectors(
            {
                "sectors": [
                    {"id": 8, "propagator_count": 3},
                    {"id": 9, "propagator_count": 2},
                    {"id": 2, "propagator_count": 2},
                ]
            }
        )
        self.assertEqual([item["id"] for item in sectors], [2, 9, 8])

    def test_unknown_pass_code_blocks_instead_of_advancing(self) -> None:
        task = self.start_current("PREPARE")
        result = self.write_main_result(task, code="NOT_THE_INTERFACE_CODE")
        self.cli(
            "report",
            str(self.state_path),
            task["task_id"],
            str(result),
        )
        state = self.state()
        self.assertEqual(state["status"], "BLOCKED")
        self.assertEqual(self.task()["status"], "BLOCKED")

    def test_python_does_not_launch_scientific_processes(self) -> None:
        tree = ast.parse(WORKFLOW.read_text(encoding="utf-8"))
        imported = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                imported.update(alias.name.split(".")[0] for alias in node.names)
            elif isinstance(node, ast.ImportFrom) and node.module:
                imported.add(node.module.split(".")[0])
        self.assertNotIn("subprocess", imported)

    def test_wls_files_are_comment_only_interfaces(self) -> None:
        scripts = sorted((ROOT / "mma").glob("*.wls"))
        scripts.extend(sorted((ROOT / "methods").glob("*/run.wls")))
        self.assertEqual(len(scripts), 12)
        for script in scripts:
            text = script.read_text(encoding="utf-8").strip()
            self.assertTrue(text.startswith("(*"), script)
            self.assertTrue(text.endswith("*)"), script)
            self.assertIn(
                "Scientific implementation is intentionally absent.", text
            )


if __name__ == "__main__":
    unittest.main()
