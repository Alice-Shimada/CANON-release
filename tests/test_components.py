import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import run_step


ROOT = Path(__file__).resolve().parents[1]


class ComponentTest(unittest.TestCase):
    def package(self, directory, steps, **extra):
        directory.mkdir(parents=True, exist_ok=True)
        path = directory / "components.json"
        path.write_text(json.dumps({"schema": "canon-neu/components/v1",
                                    "steps": steps, **extra}))
        (directory / "instructions.md").write_text("Component instructions\n")
        return path

    def test_default_package_covers_existing_step_contracts(self):
        entries = run_step.load_components()
        scripts = set(ROOT.glob("mma/*.wls")) | set(ROOT.glob("methods/*/run.wls"))
        scripts.remove(ROOT / "methods/method-card-template/run.wls")
        # The stable INITIAL entry dispatches to this implementation; it is
        # not a second selectable method.
        scripts.remove(ROOT / "methods/initial-core/run.wls")
        self.assertEqual({Path(entry["command"][-1]) for entry in entries.values()},
                         scripts | {ROOT / "prepare_request.py"})
        for key, entry in entries.items():
            self.assertTrue(Path(entry["instructions"]).is_file())
            if key == "PREPARE_REQUEST":
                self.assertEqual(entry["command"], [sys.executable, str(ROOT / "prepare_request.py")])
                continue
            text = Path(entry["command"][-1]).read_text()
            if Path(entry["command"][-1]) == ROOT / "methods/initial/run.wls":
                text += (ROOT / "methods/initial-core/run.wls").read_text()
                text += (ROOT / "examples/initial-official-ladder/run.wls").read_text()
            elif Path(entry["command"][-1]) == ROOT / "mma/CheckUTEvidence.wls":
                text += (ROOT / "examples/initial-official-ladder/check.wls").read_text()
            steps = re.findall(r'ReadTask\[(?:inputPath|requestPath), "([A-Z_]+)"\]', text)
            self.assertIn(key.split("/")[0], steps)

    def test_partial_package_resolves_from_its_own_location(self):
        with tempfile.TemporaryDirectory(prefix="canon components ") as temporary:
            package = Path(temporary) / "components.json"
            package.write_text(json.dumps({
                "schema": "canon-neu/components/v1",
                "steps": {
                    "SOLVE_TAIL": {
                        "command": ["{python}", "{package}/tail.py"],
                        "instructions": "tail.md",
                    },
                    "SEARCH_CORE/custom": {
                        "command": ["{python}", "{package}/core.py"],
                        "instructions": "core.md",
                    },
                },
            }))
            entries = run_step.load_components(package)
            self.assertEqual(entries["SOLVE_TAIL"]["command"], [sys.executable, str(package.parent / "tail.py")])
            self.assertEqual(entries["SEARCH_CORE/custom"]["instructions"], str(package.parent / "core.md"))
            self.assertEqual(entries["CHECK_CANONICAL"], run_step.load_components()["CHECK_CANONICAL"])
            self.assertEqual(entries["SEARCH_CORE/libra"], run_step.load_components()["SEARCH_CORE/libra"])

    def test_describe_selects_method_without_creating_output(self):
        with tempfile.TemporaryDirectory() as temporary:
            input_path = Path(temporary) / "input.json"
            output = Path(temporary) / "output"
            input_path.write_text(json.dumps({"step": "SEARCH_CORE"}))
            command = [sys.executable, str(ROOT / "run_step.py"), str(input_path), str(output)]
            env = os.environ.copy()
            env.pop("CANON_COMPONENTS", None)
            result = subprocess.run(command + ["--describe", "--method", "epsilon-zero"], env=env, text=True, capture_output=True, check=True)
            invocation = json.loads(result.stdout)
            self.assertEqual(invocation["step"], "SEARCH_CORE/epsilon-zero")
            self.assertEqual(invocation["command"][-2:], [str(input_path), str(output)])
            self.assertFalse(output.exists())
            missing = subprocess.run(command + ["--describe"], env=env, text=True, capture_output=True)
            self.assertNotEqual(missing.returncode, 0)
            self.assertIn("--method", missing.stderr)

    def test_invocation_preserves_arguments_and_nested_package_selection(self):
        with tempfile.TemporaryDirectory(prefix="canon invocation ") as temporary:
            base = Path(temporary)
            request = base / "input.json"
            request.write_text(json.dumps({"step": "PREPARE"}))
            package = base / "components.json"
            package.write_text(json.dumps({"schema": "canon-neu/components/v1", "steps": {}}))
            with patch.dict(os.environ, {"CANON_COMPONENTS": str(package), "CANON_WOLFRAMSCRIPT": "/tool path/wolframscript"}), patch("run_step.os.execvpe") as execute:
                run_step.main([str(request), str(base / "output")])
            executable, argv, env = execute.call_args.args
            self.assertEqual(executable, "/tool path/wolframscript")
            self.assertEqual(argv, [executable, "-file", str(ROOT / "mma/PrepareFamily.wls"), str(request), str(base / "output")])
            self.assertEqual(env["CANON_COMPONENTS"], str(package))
            self.assertEqual(env["CANON_PYTHON"], sys.executable)

    def test_composed_packages_keep_origin_and_move_with_relative_includes(self):
        with tempfile.TemporaryDirectory(prefix="canon relocation ") as temporary:
            original = Path(temporary) / "original"
            first = self.package(original / "first", {
                "PREPARE": {"command": ["{python}", "{package}/prepare.py"],
                            "instructions": "instructions.md"}})
            second = self.package(original / "second", {
                "REDUCE_IBP": {"command": ["{python}", "{package}/reduce.py"],
                               "instructions": "instructions.md"}},
                workflow="instructions.md")
            self.package(original / "combined", {},
                         extends=["../first/components.json", "../second/components.json"])
            moved = Path(temporary) / "moved packages"
            shutil.move(str(original), moved)
            entries, workflows = run_step.resolve_components(moved / "combined/components.json")
            self.assertEqual(entries["PREPARE"]["command"][-1], str(moved / "first/prepare.py"))
            self.assertEqual(entries["REDUCE_IBP"]["command"][-1], str(moved / "second/reduce.py"))
            self.assertEqual(workflows[0]["instructions"], str(moved / "second/instructions.md"))
            self.assertEqual(entries["FINAL_CHECK"], run_step.load_components()["FINAL_CHECK"])

    def test_step_boundary_switch_and_nested_calls_keep_the_complete_selection(self):
        with tempfile.TemporaryDirectory(prefix="canon hot plug ") as temporary:
            base = Path(temporary)
            first = self.package(base / "first", {
                "PREPARE": {"command": ["{python}", "{package}/parent.py", "{canon}/run_step.py"],
                            "instructions": "instructions.md"}})
            (first.parent / "parent.py").write_text(
                "import json, pathlib, subprocess, sys\n"
                "runner, request, output = sys.argv[1:]\n"
                "output = pathlib.Path(output); output.mkdir()\n"
                "child = output / 'child.json'\n"
                "child.write_text(json.dumps({'step': 'REDUCE_IBP'}))\n"
                "subprocess.run([sys.executable, runner, str(child), str(output / 'ibp')], check=True)\n")
            second = self.package(base / "second", {
                "REDUCE_IBP": {"command": ["{python}", "{package}/reducer.py", "first-version"],
                               "instructions": "instructions.md"}})
            (second.parent / "reducer.py").write_text(
                "import json, os, pathlib, sys\n"
                "output = pathlib.Path(sys.argv[-1]); output.mkdir()\n"
                "(output / 'result.json').write_text(json.dumps({'version': sys.argv[1],"
                "'components': json.loads(os.environ['CANON_COMPONENTS'])}))\n")
            request = base / "input.json"
            request.write_text(json.dumps({"step": "PREPARE"}))
            invocation = [sys.executable, str(ROOT / "run_step.py"), str(request)]
            selection = ["--components", str(first), "--components", str(second)]
            subprocess.run(invocation + [str(base / "out1"), *selection], check=True)
            first_result = json.loads((base / "out1/ibp/result.json").read_text())
            self.assertEqual(first_result["components"], [str(first), str(second)])
            self.assertEqual(first_result["version"], "first-version")
            manifest = json.loads(second.read_text())
            manifest["steps"]["REDUCE_IBP"]["command"][-1] = "next-version"
            second.write_text(json.dumps(manifest))
            subprocess.run(invocation + [str(base / "out2"), *selection], check=True)
            self.assertEqual(json.loads((base / "out2/ibp/result.json").read_text())["version"], "next-version")

    def test_explicit_selection_wins_and_defaults_unload_even_a_removed_package(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            first = self.package(base / "first", {
                "PREPARE": {"command": ["{python}", "{package}/first.py"],
                            "instructions": "instructions.md"}})
            second = self.package(base / "second", {
                "PREPARE": {"command": ["{python}", "{package}/second.py"],
                            "instructions": "instructions.md"}})
            self.assertEqual(run_step.load_components([first, second])["PREPARE"]["manifest"], str(second))
            request = base / "input.json"
            request.write_text(json.dumps({"step": "PREPARE"}))
            argv = [str(request), str(base / "out")]
            with patch.dict(os.environ, {"CANON_COMPONENTS": json.dumps([str(first), str(second)])}), patch("run_step.os.execvpe") as execute:
                run_step.main(argv + ["--components", str(first)])
                self.assertEqual(execute.call_args.args[2]["CANON_COMPONENTS"], str(first))
                second.unlink()
                run_step.main(argv + ["--defaults"])
                self.assertNotIn("CANON_COMPONENTS", execute.call_args.args[2])
                self.assertEqual(execute.call_args.args[1][-3], str(ROOT / "mma/PrepareFamily.wls"))

    def test_recursive_include_has_a_specific_error(self):
        with tempfile.TemporaryDirectory() as temporary:
            package = self.package(Path(temporary), {}, extends=["components.json"])
            with self.assertRaisesRegex(ValueError, "component include cycle"):
                run_step.load_components(package)

    def test_independent_phase_bindings_and_nested_reduction(self):
        with tempfile.TemporaryDirectory(prefix="canon phase bindings ") as temporary:
            base = Path(temporary)
            phases = {"PREPARE": "chart", "DISCOVER": "first-reducer",
                      "REDUCE_IBP": "second-reducer", "BUILD_CUT_DE": "direct-de"}
            for name in phases.values():
                manifest = self.package(base / name, {
                    step: {"command": ["{python}", "{package}/step.py", name, "{canon}/run_step.py"],
                           "instructions": "instructions.md"}
                    for step in (*phases, "UNSELECTED_OPERATION")}, workflow="instructions.md")
                (manifest.parent / "step.py").write_text(
                    "import json,pathlib,subprocess,sys\n"
                    "provider,runner,source,destination=sys.argv[1:]\n"
                    "source=pathlib.Path(source); destination=pathlib.Path(destination); destination.mkdir()\n"
                    "request=json.loads(source.read_text())\n"
                    "result={'provider':provider,'step':request['step']}\n"
                    "if request['step']=='BUILD_CUT_DE':\n"
                    "    child=destination/'child.json'; child.write_text(json.dumps({'step':'REDUCE_IBP'}))\n"
                    "    subprocess.run([sys.executable,runner,str(child),str(destination/'reduced')],check=True)\n"
                    "    result['reduction']=json.loads((destination/'reduced/result.json').read_text())\n"
                    "(destination/'result.json').write_text(json.dumps(result))\n")
            selected = self.package(base / "selection", {
                step: {"from": f"../{provider}/components.json"} for step, provider in phases.items()})
            entries, workflows = run_step.resolve_components(selected)
            self.assertNotIn("UNSELECTED_OPERATION", entries)
            self.assertEqual(entries["SOLVE_TAIL"], run_step.load_components()["SOLVE_TAIL"])
            self.assertEqual(len(workflows), 4)
            for step, provider in phases.items():
                request = base / f"{step}.json"
                request.write_text(json.dumps({"step": step}))
                output = base / f"out-{step}"
                subprocess.run([sys.executable, str(ROOT / "run_step.py"), str(request), str(output),
                                "--components", str(selected)], check=True)
                result = json.loads((output / "result.json").read_text())
                self.assertEqual(result["provider"], provider)
                self.assertEqual(result["step"], step)
                if step == "BUILD_CUT_DE":
                    self.assertEqual(result["reduction"]["provider"], "second-reducer")

    def test_phase_reference_keeps_origin_and_instruction_override_after_move(self):
        with tempfile.TemporaryDirectory(prefix="canon selected phase ") as temporary:
            original = Path(temporary) / "original"
            self.package(original / "provider", {
                "SEARCH_CORE/custom": {"command": ["{python}", "{package}/core.py"],
                                       "instructions": "instructions.md"}}, workflow="instructions.md")
            self.package(original / "wrapper", {}, extends=["../provider/components.json"],
                         workflow="instructions.md")
            self.package(original / "selected", {
                "SEARCH_CORE": {"from": "../wrapper/components.json", "step": "SEARCH_CORE/custom",
                                "instructions": "instructions.md"}})
            moved = Path(temporary) / "moved tree"
            original.rename(moved)
            entries, workflows = run_step.resolve_components(moved / "selected/components.json")
            selected = entries["SEARCH_CORE"]
            self.assertEqual(selected["command"][-1], str(moved / "provider/core.py"))
            self.assertEqual(selected["instructions"], str(moved / "selected/instructions.md"))
            self.assertEqual(selected["manifest"], str(moved / "provider/components.json"))
            self.assertEqual(selected["binding_manifest"], str(moved / "selected/components.json"))
            self.assertEqual({Path(w["instructions"]).parent.name for w in workflows}, {"provider", "wrapper"})

    def test_phase_reference_cycle_and_missing_operation_are_explicit_errors(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            first = self.package(base / "first", {"DISCOVER": {"from": "../second/components.json"}})
            self.package(base / "second", {"DISCOVER": {"from": "../first/components.json"}})
            with self.assertRaisesRegex(ValueError, "step reference cycle"):
                run_step.load_components(first)
            self.package(base / "second", {})
            with self.assertRaisesRegex(ValueError, "no component for DISCOVER"):
                run_step.load_components(first)


if __name__ == "__main__":
    unittest.main()
