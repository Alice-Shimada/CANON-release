#!/usr/bin/env python3
"""Run existing affected tests against a relocated MethodCardCore implementation.

All scientific fixture calls go through the unchanged default run_step.py entry.
Only the runner, its default manifest, and the three exercised scripts are copied;
fixtures and instruction files are read from the supplied project checkout.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import unittest


EXISTING_TESTS = [
    "test_prepared_basis_router_covers_every_decision_branch",
    "test_initial_evidence_changes_do_not_control_prepared_basis_route",
    "test_prepared_basis_rejects_malformed_and_contradictory_inputs",
    "test_prepared_basis_rejects_canonical_selected_suspicious",
    "test_prepared_basis_rejects_localized_rational_without_expectation",
    "test_prepared_basis_rejects_localized_without_defect_quality",
    "test_prepared_basis_rejects_completed_pool_with_unattempted_candidate",
    "test_structured_repair_contract_rejects_route_pool_and_prefix_contradictions",
    "test_structured_repair_preflight_enforces_mapping_direct_sum_and_parameters",
    "test_structured_repair_preflight_requires_exact_defect_and_canonical_prefix",
    "test_structured_repair_checker_positive_and_adversarial_rejections",
    "test_structured_repair_checker_hashes_package_without_executing_it",
]
UNCHANGED_SOURCES = [
    "run_step.py",
    "components/default.json",
    "methods/route-prepared-basis/run.wls",
    "methods/libra-structured-repair/run.wls",
    "mma/CheckStructuredRepair.wls",
]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, required=True)
    parser.add_argument("--staged-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--wolframscript", default=os.environ.get("CANON_WOLFRAMSCRIPT", "wolframscript"))
    args = parser.parse_args()
    project, staged, output = (p.resolve() for p in (args.project_root, args.staged_root, args.output))
    runtime = shutil.which(args.wolframscript)
    if runtime is None:
        parser.error("configured Wolfram script executable is unavailable")
    output.mkdir(parents=True)
    tree = output / "relocated package with spaces"
    copied = []
    for relative in UNCHANGED_SOURCES:
        source, target = project / relative, tree / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        copied.append({"path": relative, "source": str(source), "sha256": digest(source)})
    core_paths = [Path("mma/lib/MethodCardCore.wl")]
    core_paths += sorted(p.relative_to(staged) for p in (staged / "mma/lib/method-card").glob("*.wl"))
    for relative in core_paths:
        target = tree / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(staged / relative, target)
    for relative in ("methods/route-prepared-basis/SKILL.md", "methods/libra-structured-repair/SKILL.md"):
        (tree / relative).symlink_to(project / relative)

    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location("core_existing_method_card_tests", project / "tests/test_method_cards.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.ROOT = tree
    environment = dict(os.environ, CANON_WOLFRAMSCRIPT=runtime,
                       CANON_TEST_FIXTURE_LIBRA_ENTRY=str(module.FIXTURE_LIBRA_ENTRY),
                       OMP_NUM_THREADS="1", OPENBLAS_NUM_THREADS="1", MKL_NUM_THREADS="1",
                       PYTHONDONTWRITEBYTECODE="1")
    invocations = []
    descriptions = {}

    class RelocatedTests(module.MethodCardIntegrationTest):
        def setUp(self):
            self.run_root = output / "cases" / self._testMethodName
            self.run_root.mkdir(parents=True)

        def tearDown(self):
            pass

        def run_wls(self, script, input_path, output_dir, expected_returncode=0, timeout=60):
            task = json.loads(input_path.read_text())
            command = [sys.executable, str(tree / "run_step.py"), "--defaults", str(input_path), str(output_dir)]
            if task["step"] not in descriptions:
                described = subprocess.run(command + ["--describe"], cwd=tree, env=environment,
                                           capture_output=True, text=True, timeout=10, check=True)
                description = json.loads(described.stdout)
                self.assertEqual(description["components"], [])
                self.assertEqual(description["workflows"], [])
                self.assertEqual(description["command"][2], str(script))
                descriptions[task["step"]] = description
            completed = subprocess.run(command, cwd=tree, env=environment,
                                       capture_output=True, text=True, timeout=timeout)
            result_path = output_dir / "result.json"
            result = json.loads(result_path.read_text()) if result_path.is_file() else None
            record = {"test": self._testMethodName, "step": task["step"],
                      "command": command, "returncode": completed.returncode,
                      "expected_returncode": expected_returncode,
                      "stdout": completed.stdout, "stderr": completed.stderr,
                      "result": result}
            invocations.append(record)
            self.assertEqual(completed.returncode, expected_returncode, record)
            self.assertIsNotNone(result, record)
            return result

    suite = unittest.TestSuite(RelocatedTests(name) for name in EXISTING_TESTS)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    evidence = {
        "pass": result.wasSuccessful(), "tests_run": result.testsRun,
        "tests": EXISTING_TESTS, "skipped": result.skipped,
        "failures": [(str(case), traceback) for case, traceback in result.failures],
        "errors": [(str(case), traceback) for case, traceback in result.errors],
        "kernel_concurrency": 1, "wolframscript": runtime,
        "components": ["--defaults"], "unchanged_source_references": copied,
        "changed_sources": [{"path": str(p), "sha256": digest(staged / p)} for p in core_paths],
        "existing_test_source_sha256": digest(project / "tests/test_method_cards.py"),
        "descriptions": descriptions, "invocations": invocations,
    }
    (output / "existing-tests.json").write_text(json.dumps(evidence, indent=2) + "\n")
    return 0 if result.wasSuccessful() and not result.skipped else 1


if __name__ == "__main__":
    raise SystemExit(main())
