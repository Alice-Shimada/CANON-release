from __future__ import annotations

import json
import os
import stat
import subprocess
import sys
import tempfile
import tomllib
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE_DESIGN = ROOT / "docs" / "state-management" / "跨通用 Agent 的持续研究状态管理基础设施设计方案.md"
INSTALLER = ROOT / "state-management" / "adapters" / "codex" / "install_launcher.py"
LAUNCHER_ARGUMENTS = ["-c", 'exec "$HOME/.codex/statemng/CANON/mcp"']


def architecture_section(text: str) -> str:
    start = text.index("## 四、整体架构")
    end = text.find("## 五、主要组件", start)
    if end == -1:
        end = len(text)
    return text[start:end]


def configured_server(path: Path) -> dict:
    return tomllib.loads(path.read_text(encoding="utf-8"))["mcp_servers"]["statemng"]


class CodexAdapterTests(unittest.TestCase):
    def test_agents_contains_the_exact_base_architecture_section(self) -> None:
        source = BASE_DESIGN.read_text(encoding="utf-8")
        agents = (ROOT / "AGENTS.md").read_text(encoding="utf-8")
        self.assertEqual(
            architecture_section(agents).rstrip("\n"),
            architecture_section(source).rstrip("\n"),
        )

    def test_public_skill_has_the_required_exact_frontmatter(self) -> None:
        skill = (
            ROOT / ".agents" / "skills" / "persistent-scientific-research" / "SKILL.md"
        ).read_text(encoding="utf-8")
        frontmatter, body = skill.split("---\n", 2)[1:]
        self.assertEqual(
            frontmatter,
            "name: persistent-scientific-research\n"
            "description: Use for multi-step scientific research in CANON, including master-integral differential equations, UT bases, canonical forms, and epsilon forms.\n",
        )
        self.assertIn("statemng_task_accept", body)
        self.assertIn("statemng_task_unblock", body)
        self.assertIn("persistent_research_worker", body)
        self.assertIn("install_launcher.py --check", body)
        self.assertIn("new Local session", body)

    def test_main_and_worker_mcp_configs_use_the_stable_launcher(self) -> None:
        main_path = ROOT / ".codex" / "config.toml"
        worker_path = ROOT / ".codex" / "agents" / "persistent-research-worker.toml"
        main_server = configured_server(main_path)
        worker_server = configured_server(worker_path)
        for server in (main_server, worker_server):
            self.assertTrue(server["enabled"])
            self.assertEqual(server["command"], "/bin/sh")
            self.assertEqual(server["args"], LAUNCHER_ARGUMENTS)
            self.assertNotIn("cwd", server)
            self.assertFalse(server["required"])
            self.assertEqual(server["default_tools_approval_mode"], "writes")
        self.assertEqual(
            main_server,
            {key: value for key, value in worker_server.items() if key != "disabled_tools"},
        )

    def test_worker_has_native_tool_restrictions(self) -> None:
        worker = tomllib.loads(
            (ROOT / ".codex" / "agents" / "persistent-research-worker.toml").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(worker["name"], "persistent_research_worker")
        self.assertTrue(worker["description"])
        self.assertTrue(worker["developer_instructions"])
        self.assertIn("Codex Local session", worker["developer_instructions"])
        self.assertIn("statemng tools are unavailable", worker["developer_instructions"])
        self.assertEqual(
            set(worker["mcp_servers"]["statemng"]["disabled_tools"]),
            {"statemng_task_accept", "statemng_task_unblock"},
        )

    def test_installed_launcher_works_from_desktop_root_cwd(self) -> None:
        main_path = ROOT / ".codex" / "config.toml"
        worker_path = ROOT / ".codex" / "agents" / "persistent-research-worker.toml"
        requests = (
            '{"jsonrpc":"2.0","id":1,"method":"initialize",'
            '"params":{"protocolVersion":"2025-11-25","capabilities":{},'
            '"clientInfo":{"name":"codex-adapter-test","version":"1"}}}\n'
            '{"jsonrpc":"2.0","method":"notifications/initialized"}\n'
            '{"jsonrpc":"2.0","id":2,"method":"tools/list"}\n'
            '{"jsonrpc":"2.0","id":3,"method":"tools/call",'
            '"params":{"name":"statemng_project_list","arguments":{}}}\n'
        )
        with tempfile.TemporaryDirectory() as temporary_home:
            environment = os.environ.copy()
            environment["HOME"] = temporary_home
            installed = subprocess.run(
                [sys.executable, str(INSTALLER)],
                env=environment,
                text=True,
                encoding="utf-8",
                capture_output=True,
                check=False,
                timeout=10,
            )
            self.assertEqual(installed.returncode, 0, installed.stderr)
            installed_payload = json.loads(installed.stdout)
            self.assertTrue(installed_payload["ok"], installed_payload)
            launcher = Path(installed_payload["launcher"])
            self.assertTrue(launcher.stat().st_mode & stat.S_IXUSR)

            checked = subprocess.run(
                [sys.executable, str(INSTALLER), "--check"],
                env=environment,
                text=True,
                encoding="utf-8",
                capture_output=True,
                check=False,
                timeout=10,
            )
            self.assertEqual(checked.returncode, 0, checked.stdout + checked.stderr)

            for config_path in (main_path, worker_path):
                with self.subTest(config_path=config_path):
                    server = configured_server(config_path)
                    completed = subprocess.run(
                        [server["command"], *server["args"]],
                        cwd="/",
                        env=environment,
                        input=requests,
                        text=True,
                        encoding="utf-8",
                        capture_output=True,
                        check=False,
                        timeout=10,
                    )
                    self.assertEqual(completed.returncode, 0, completed.stderr)
                    responses = [json.loads(line) for line in completed.stdout.splitlines()]
                    self.assertEqual(
                        responses[0]["result"]["protocolVersion"], "2025-11-25"
                    )
                    self.assertEqual(
                        responses[0]["result"]["serverInfo"]["name"], "statemng"
                    )
                    self.assertEqual(len(responses[1]["result"]["tools"]), 18)
                    project_list = responses[2]["result"]
                    self.assertFalse(project_list["isError"], project_list)
                    self.assertTrue(project_list["structuredContent"]["ok"], project_list)

    def test_readme_documents_codex_setup_and_agent_facing_entry(self) -> None:
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        self.assertNotIn("workflow.py", readme)
        self.assertIn("用户不需要了解或调用状态管理 CLI", readme)
        self.assertIn("install_launcher.py --check", readme)
        self.assertIn("statemng_project_list", readme)
        self.assertIn("Local", readme)
        self.assertIn("MCP tool surface 在会话初始化时确定", readme)
        self.assertIn("跨通用 Agent 的持续研究状态管理基础设施设计方案", readme)
        self.assertIn("持续研究状态管理的 Agent 接入补充方案", readme)


if __name__ == "__main__":
    unittest.main()
