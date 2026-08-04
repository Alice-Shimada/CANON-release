from __future__ import annotations

import subprocess
import tomllib
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE_DESIGN = ROOT / "docs" / "state-management" / "跨通用 Agent 的持续研究状态管理基础设施设计方案.md"


def architecture_section(text: str) -> str:
    start = text.index("## 四、整体架构")
    end = text.find("## 五、主要组件", start)
    if end == -1:
        end = len(text)
    return text[start:end]


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

    def test_main_and_worker_mcp_configs_resolve_to_the_same_server(self) -> None:
        main_path = ROOT / ".codex" / "config.toml"
        worker_path = ROOT / ".codex" / "agents" / "persistent-research-worker.toml"
        main = tomllib.loads(main_path.read_text(encoding="utf-8"))
        worker = tomllib.loads(worker_path.read_text(encoding="utf-8"))
        main_server = main["mcp_servers"]["statemng"]
        worker_server = worker["mcp_servers"]["statemng"]
        for server in (main_server, worker_server):
            self.assertEqual(server["command"], "python3")
            self.assertEqual(server["args"], ["state-management/mcp_server.py"])
            self.assertTrue(server["required"])
            self.assertEqual(server["default_tools_approval_mode"], "writes")
        main_cwd = (main_path.parent / main_server["cwd"]).resolve()
        worker_cwd = (worker_path.parent / worker_server["cwd"]).resolve()
        self.assertEqual(main_cwd, ROOT.resolve())
        self.assertEqual(worker_cwd, ROOT.resolve())
        for cwd, server in ((main_cwd, main_server), (worker_cwd, worker_server)):
            self.assertTrue((cwd / server["args"][0]).is_file())

    def test_worker_has_native_tool_restrictions(self) -> None:
        worker = tomllib.loads(
            (ROOT / ".codex" / "agents" / "persistent-research-worker.toml").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(worker["name"], "persistent_research_worker")
        self.assertTrue(worker["description"])
        self.assertTrue(worker["developer_instructions"])
        self.assertEqual(
            set(worker["mcp_servers"]["statemng"]["disabled_tools"]),
            {"statemng_task_accept", "statemng_task_unblock"},
        )

    def test_configured_server_completes_mcp_initialize(self) -> None:
        config_path = ROOT / ".codex" / "config.toml"
        config = tomllib.loads(config_path.read_text(encoding="utf-8"))
        server = config["mcp_servers"]["statemng"]
        cwd = (config_path.parent / server["cwd"]).resolve()
        request = (
            '{"jsonrpc":"2.0","id":1,"method":"initialize",'
            '"params":{"protocolVersion":"2026-01-26","capabilities":{},'
            '"clientInfo":{"name":"adapter-test","version":"1"}}}\n'
        )
        completed = subprocess.run(
            [server["command"], *server["args"]],
            cwd=cwd,
            input=request,
            text=True,
            encoding="utf-8",
            capture_output=True,
            check=False,
            timeout=10,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertIn('"name":"statemng"', completed.stdout)
        self.assertIn('"tools"', completed.stdout)

    def test_readme_exposes_only_the_agent_facing_entry(self) -> None:
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        self.assertNotIn("workflow.py", readme)
        self.assertIn("用户不需要了解或调用状态管理 CLI", readme)
        self.assertIn("跨通用 Agent 的持续研究状态管理基础设施设计方案", readme)
        self.assertIn("持续研究状态管理的 Agent 接入补充方案", readme)


if __name__ == "__main__":
    unittest.main()
