from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "tests/fixtures/method_cards"
FIXTURES = ROOT / "tests/fixtures/canonicacontrols"
KERNEL = Path(os.environ.get("CANON_WOLFRAM_KERNEL") or shutil.which("WolframKernel") or "WolframKernel").expanduser().resolve()
WRAPPER = os.environ.get("CANON_TEST_WOLFRAM_WRAPPER")
REAL_ENTRY = os.environ.get("CANON_TEST_CANONICA_ENTRY")


@unittest.skipUnless(KERNEL.is_file() or WRAPPER, "requires a configured Wolfram runtime")
class CANONICAControlTest(unittest.TestCase):
    def setUp(self) -> None:
        retained = os.environ.get("CANON_TEST_CONTROL_OUTPUT_ROOT")
        self.temporary = None if retained else tempfile.TemporaryDirectory()
        self.run_root = Path(retained) / self._testMethodName if retained else Path(self.temporary.name)
        self.run_root.mkdir(parents=True, exist_ok=True)
        self.sequence = 0

    def tearDown(self) -> None:
        if self.temporary is not None:
            self.temporary.cleanup()

    def run_script(self, script: Path, input_path: Path, output: Path, *, mode: str = "success", returncode: int = 0) -> dict:
        environment = os.environ.copy()
        environment["CANON_TEST_CAPTURE"] = str(output.with_suffix(".calls.wl"))
        environment["CANON_TEST_CANONICA_MODE"] = mode
        if WRAPPER:
            command = [WRAPPER, str(script), str(input_path), str(output)]
        else:
            command = [sys.executable, str(ROOT / "tests/wolfram_kernel_launcher.py"),
                       str(KERNEL), "-noinit", "-noprompt", "-script", str(script), str(input_path), str(output)]
        completed = subprocess.run(command, cwd=ROOT, env=environment, text=True, capture_output=True, timeout=90)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.with_suffix(".kernel.log").write_text(completed.stdout + completed.stderr, encoding="utf-8")
        result_path = output / "result.json"
        self.assertEqual(completed.returncode, returncode, completed.stdout + completed.stderr)
        self.assertTrue(result_path.is_file(), completed.stdout + completed.stderr)
        return json.loads(result_path.read_text())

    def task(self, *, custom: bool = False, options: dict | None = None,
             ansatz_text: str | None = None, descriptor_updates: dict | None = None,
             entry: str | Path | None = None, cut: Path | None = None,
             basis: Path | None = None) -> tuple[Path, Path]:
        self.sequence += 1
        stem = f"case-{self.sequence:02d}"
        cut = cut or BASE / "sector-cut-de.wl"
        basis = basis or BASE / "sector-basis.wl"
        value = json.loads((BASE / "search-input-canonica.json").read_text())
        for name in ("prepared_family", "sector_basis", "sector_cut_de"):
            value["payload"][name]["path"] = str(BASE / value["payload"][name]["path"])
        value["payload"]["sector_basis"]["path"] = str(basis)
        value["payload"]["sector_cut_de"]["path"] = str(cut)
        value["payload"]["method_options"] = {"package_entry": str(entry or FIXTURES / "ControlledCANONICA.m"), **(options or {})}
        if custom:
            path = self.run_root / f"{stem}-ansatz.wl"
            text = ansatz_text or self.ansatz(cut=cut)
            path.write_text(text)
            descriptor = {"type": "mathematica-expression", "path": path.name,
                          "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
            descriptor.update(descriptor_updates or {})
            value["payload"]["t_ansatz"] = descriptor
        path = self.run_root / f"{stem}.json"
        path.write_text(json.dumps(value, indent=2) + "\n")
        return path, self.run_root / f"{stem}-output"

    def ansatz(self, *, cut: Path | None = None) -> str:
        cut = cut or BASE / "sector-cut-de.wl"
        source_hash = hashlib.sha256(cut.read_bytes()).hexdigest()
        return f'''<|"schema" -> "canon-neu/canonica-rational-ansatz/v1", "kind" -> "T",
  "identity" -> <|"sector" -> <|"id" -> 3, "propagator_count" -> 2|>,
    "family_id" -> "fixture-libra-tutorial-1", "basis_id" -> "fixture-sector-3-basis-v1",
    "source_basis" -> {{j1,j2}}, "regulator" -> eps, "source_de_sha256" -> "{source_hash}"|>,
  "scope" -> <|"block_index" -> 1, "block_bounds" -> {{1,2}}|>,
  "variables" -> {{x}}, "terms" -> {{1,x}}|>\n'''

    def check_core(self, candidate_output: Path, result: dict, *, cut: Path | None = None,
                   basis: Path | None = None) -> None:
        original = json.loads((BASE / "search-input-canonica.json").read_text())
        original["step"] = "CHECK_CORE"
        original["task_id"] = "T-CONTROL-CHECK"
        original["payload"] = {
            "sector_basis": {"type": "mathematica-expression", "path": str(basis or BASE / "sector-basis.wl")},
            "sector_cut_de": {"type": "mathematica-expression", "path": str(cut or BASE / "sector-cut-de.wl")},
            "core_candidates": {"type": "mathematica-expression", "path": str(candidate_output / result["artifacts"]["core_candidates"]["path"])},
        }
        path = candidate_output.with_suffix(".check.json")
        path.write_text(json.dumps(original))
        checked = self.run_script(ROOT / "mma/CheckSectorCore.wls", path, candidate_output.with_name(candidate_output.name + "-check"))
        self.assertEqual((checked["status"], checked["code"]), ("PASS", "CORE_PASS"))

    def test_legacy_recursive_once_and_three_degrees(self) -> None:
        for options in ({}, {"t_delta_numerator_degree": 1, "t_delta_denominator_degree": 2,
                            "d_delta_numerator_degree": 3}):
            with self.subTest(options=options):
                path, output = self.task(options=options)
                result = self.run_script(ROOT / "methods/canonica/run.wls", path, output)
                self.assertEqual(result["code"], "CANDIDATE_TRANSFORMATION")
                calls = output.with_suffix(".calls.wl").read_text().splitlines()
                self.assertEqual(len(calls), 1)
                self.assertIn('"RecursivelyTransformSectors"', calls[0])
                self.assertIn('{1, 2, 3}' if options else '{0, 0, 0}', calls[0])
                self.assertEqual(result["summary"]["ansatz_options"], {
                    key: options.get(key, 0) for key in ("t_delta_numerator_degree",
                        "t_delta_denominator_degree", "d_delta_numerator_degree")})
                self.check_core(output, result)

    def test_custom_t_uses_public_bounded_stages_and_checked_gauge(self) -> None:
        path, output = self.task(custom=True, options={"d_delta_numerator_degree": 3})
        result = self.run_script(ROOT / "methods/canonica/run.wls", path, output)
        self.assertEqual((result["status"], result["code"]), ("PROVISIONAL", "CANDIDATE_TRANSFORMATION"))
        calls = output.with_suffix(".calls.wl").read_text().splitlines()
        self.assertEqual(len(calls), 3)
        self.assertIn('"TransformNextDiagonalBlock"', calls[0])
        self.assertIn('"terms" -> {1, x}', calls[0])
        self.assertIn('"TransformOffDiagonalBlock"', calls[1])
        self.assertIn('"options" -> {3}', calls[1])
        self.assertIn('"TransformDlogToEpsForm"', calls[2])
        evidence = result["summary"]["finite_ansatz"]
        self.assertEqual((evidence["term_count"], evidence["scope"]["block_index"]), (2, 1))
        self.assertEqual(evidence["sha256"], json.loads(path.read_text())["payload"]["t_ansatz"]["sha256"])
        diagnostics = output / result["artifacts"]["method_diagnostics"]["path"]
        self.assertTrue(diagnostics.is_file())
        self.assertIn('"requested_stage" -> "full_basis_rows"', diagnostics.read_text())
        inverse_attempts = [value for value in result["summary"]["attempts"]
                            if value["requested_stage"] == "full_basis_rows"]
        self.assertEqual(len(inverse_attempts), 1)
        self.assertEqual(inverse_attempts[0]["attempted_ansatz"]["mode"], "exact_inverse")
        self.assertFalse(inverse_attempts[0]["timed_out"])
        self.assertIsNone(inverse_attempts[0]["failed_stage"])
        self.check_core(output, result)

    def test_invalid_ansatz_is_rejected_before_scientific_calls(self) -> None:
        original = self.ansatz()
        mutations = {
            "schema": ('canonica-rational-ansatz/v1', 'canonica-rational-ansatz/v99'),
            "kind": ('"kind" -> "T"', '"kind" -> "D"'),
            "family": ('fixture-libra-tutorial-1', 'different-family'),
            "basis": ('"source_basis" -> {j1,j2}', '"source_basis" -> {j2,j1}'),
            "source-hash": ('"source_de_sha256" -> "', '"source_de_sha256" -> "changed-'),
            "block": ('"block_bounds" -> {1,2}', '"block_bounds" -> {1,1}'),
            "variables": ('"variables" -> {x}', '"variables" -> {y}'),
            "undeclared": ('"terms" -> {1,x}', '"terms" -> {1,y}'),
            "regulator-term": ('"terms" -> {1,x}', '"terms" -> {1,eps}'),
            "approximate": ('"terms" -> {1,x}', '"terms" -> {1,0.5 x}'),
            "root": ('"terms" -> {1,x}', '"terms" -> {1,Sqrt[x]}'),
            "transcendental": ('"terms" -> {1,x}', '"terms" -> {1,Log[x]}'),
            "empty": ('"terms" -> {1,x}', '"terms" -> {}'),
        }
        for label, (old, new) in mutations.items():
            with self.subTest(label=label):
                self.assertIn(old, original)
                path, output = self.task(custom=True, ansatz_text=original.replace(old, new))
                result = self.run_script(ROOT / "methods/canonica/run.wls", path, output, returncode=1)
                self.assertEqual((result["status"], result["code"]), ("ERROR", "INVALID_ANSATZ"))
                self.assertFalse(output.with_suffix(".calls.wl").exists())

    def test_hash_descriptor_and_term_budget_rejections(self) -> None:
        for label, updates, options in (
            ("hash", {"sha256": "0" * 64}, {}),
            ("missing-hash", {"sha256": None}, {}),
            ("type", {"type": "json"}, {}),
            ("terms", {}, {"max_ansatz_terms": 1}),
        ):
            with self.subTest(label=label):
                path, output = self.task(custom=True, descriptor_updates=updates, options=options)
                result = self.run_script(ROOT / "methods/canonica/run.wls", path, output, returncode=1)
                self.assertEqual(result["code"], "INVALID_ANSATZ")
                self.assertFalse(output.with_suffix(".calls.wl").exists())

    def test_invalid_control_budgets_do_not_start_search(self) -> None:
        for options in ({"max_wall_seconds": 0}, {"max_wall_seconds": -2},
                        {"max_wall_seconds": True}, {"max_ansatz_terms": 0},
                        {"max_ansatz_terms": 1.5}):
            with self.subTest(options=options):
                path, output = self.task(options=options)
                result = self.run_script(ROOT / "methods/canonica/run.wls", path, output, returncode=1)
                self.assertEqual(result["code"], "INVALID_OPTIONS")
                self.assertFalse(output.with_suffix(".calls.wl").exists())

    def test_failure_messages_classify_stage_block_and_preserve_raw_log(self) -> None:
        expected = {"nonrationalinv": "rational_transformation_obstruction",
                    "trace": "trace_necessary_condition_failed",
                    "finiteansatzfailed": "finite_ansatz_exhausted",
                    "epsnormalization": "epsilon_normalization_failed"}
        for mode, diagnostic_class in expected.items():
            with self.subTest(mode=mode):
                path, output = self.task(custom=True)
                result = self.run_script(ROOT / "methods/canonica/run.wls", path, output, mode=mode)
                self.assertEqual((result["status"], result["code"]), ("INCONCLUSIVE", "METHOD_EXHAUSTED"))
                self.assertEqual(result["summary"]["failed_block"], 1)
                self.assertEqual(result["summary"]["failed_stage"],
                                 "epsilon_normalization" if mode == "epsnormalization" else "diagonal_block")
                self.assertIn(diagnostic_class, result["summary"]["diagnostic_classes"])
                tag = "noepsform" if mode == "trace" else mode
                self.assertTrue(any(tag in value for value in result["summary"]["message_tags"]))
                raw_log = (output / result["artifacts"]["method_messages"]["path"]).read_text()
                self.assertIn(tag, raw_log)
                self.assertNotIn("family", result["summary"]["reason"].lower())

    def test_wall_budget_interrupts_one_attempt_without_retry(self) -> None:
        path, output = self.task(custom=True, options={"max_wall_seconds": 0.05})
        result = self.run_script(ROOT / "methods/canonica/run.wls", path, output, mode="slow")
        self.assertEqual(result["code"], "METHOD_EXHAUSTED")
        self.assertTrue(result["summary"]["timed_out"])
        self.assertIn("time_budget_exhausted", result["summary"]["diagnostic_classes"])
        self.assertEqual(len(output.with_suffix(".calls.wl").read_text().splitlines()), 1)

    def test_wall_budget_bounds_full_basis_inverse_before_publication(self) -> None:
        path, output = self.task(custom=True, options={"max_wall_seconds": 0.5})
        result = self.run_script(ROOT / "methods/canonica/run.wls", path, output, mode="slow-inverse")
        self.assertEqual((result["status"], result["code"]), ("INCONCLUSIVE", "METHOD_EXHAUSTED"))
        self.assertEqual(result["summary"]["failed_stage"], "full_basis_rows")
        self.assertTrue(result["summary"]["timed_out"])
        self.assertIn("time_budget_exhausted", result["summary"]["diagnostic_classes"])
        self.assertEqual(result["summary"]["attempted_ansatz"]["mode"], "exact_inverse")
        self.assertEqual(len(output.with_suffix(".calls.wl").read_text().splitlines()), 3)
        self.assertNotIn("core_candidates", result["artifacts"])
        self.assertFalse((output / "core-candidates.wl").exists())

    def test_existing_receipts_and_message_log_are_not_overwritten(self) -> None:
        for with_result in (True, False):
            with self.subTest(with_result=with_result):
                path, output = self.task(custom=True)
                output.mkdir()
                message_path = output / "canonica-messages.log"
                message_bytes = b"preserved CANONICA messages\n"
                message_path.write_bytes(message_bytes)
                result_path = output / "result.json"
                result_bytes = b'{"status":"PASS","code":"PRESERVED","artifacts":{}}\n'
                if with_result:
                    result_path.write_bytes(result_bytes)
                environment = os.environ.copy()
                environment["CANON_TEST_CAPTURE"] = str(output.with_suffix(".calls.wl"))
                environment["CANON_TEST_CANONICA_MODE"] = "success"
                command = ([WRAPPER, str(ROOT / "methods/canonica/run.wls"), str(path), str(output)]
                           if WRAPPER else [sys.executable, str(ROOT / "tests/wolfram_kernel_launcher.py"),
                             str(KERNEL), "-noinit", "-noprompt", "-script",
                             str(ROOT / "methods/canonica/run.wls"), str(path), str(output)])
                completed = subprocess.run(command, cwd=ROOT, env=environment, text=True,
                                           capture_output=True, timeout=90)
                output.with_suffix(".kernel.log").write_text(completed.stdout + completed.stderr)
                self.assertNotEqual(completed.returncode, 0, completed.stdout + completed.stderr)
                self.assertEqual(message_path.read_bytes(), message_bytes)
                if with_result:
                    self.assertEqual(result_path.read_bytes(), result_bytes)
                else:
                    self.assertFalse(result_path.exists())
                self.assertFalse((output / "core-candidates.wl").exists())
                self.assertFalse((output / "diagnostics.wl").exists())
                self.assertFalse(output.with_suffix(".calls.wl").exists())
                self.assertIn("OUTPUT_ERROR", completed.stdout + completed.stderr)

    def test_legacy_rational_obstruction_localizes_partial_failure(self) -> None:
        path, output = self.task()
        result = self.run_script(ROOT / "methods/canonica/run.wls", path, output, mode="nonrationalinv")
        self.assertEqual(result["summary"]["failed_stage"], "diagonal_block")
        self.assertEqual(result["summary"]["failed_block"], 1)
        self.assertIn("rational_transformation_obstruction", result["summary"]["diagnostic_classes"])

    def test_silent_and_malformed_provider_failures_have_specific_receipts(self) -> None:
        for mode, diagnostic in (("silent", "finite_ansatz_exhausted"),
                                 ("malformed", "invalid_provider_result")):
            with self.subTest(mode=mode):
                path, output = self.task(custom=True)
                result = self.run_script(ROOT / "methods/canonica/run.wls", path, output, mode=mode)
                self.assertEqual(result["code"], "METHOD_EXHAUSTED")
                self.assertEqual(result["summary"]["failed_stage"], "diagonal_block")
                self.assertEqual(result["summary"]["failed_block"], 1)
                self.assertIn(diagnostic, result["summary"]["diagnostic_classes"])

    def test_provider_epsilon_claim_cannot_bypass_source_or_coefficient_checks(self) -> None:
        for mode in ("wrong-source-gauge", "undeclared-coefficient"):
            with self.subTest(mode=mode):
                path, output = self.task(custom=True)
                result = self.run_script(ROOT / "methods/canonica/run.wls", path, output, mode=mode)
                self.assertEqual((result["status"], result["code"]), ("INCONCLUSIVE", "METHOD_EXHAUSTED"))
                self.assertEqual(result["summary"]["failed_stage"], "source_gauge_check")
                self.assertIn("provider_source_gauge_failed", result["summary"]["diagnostic_classes"])
                self.assertNotIn("core_candidates", result["artifacts"])
                self.assertFalse((output / "core-candidates.wl").exists())

    @unittest.skipUnless(REAL_ENTRY, "requires the declared installed CANONICA entry")
    def test_real_custom_t_passes_independent_core_check(self) -> None:
        path, output = self.task(custom=True, entry=REAL_ENTRY)
        result = self.run_script(ROOT / "methods/canonica/run.wls", path, output)
        self.assertEqual(result["code"], "CANDIDATE_TRANSFORMATION")
        self.check_core(output, result)

    @unittest.skipUnless(REAL_ENTRY, "requires the declared installed CANONICA entry")
    def test_real_legacy_recursive_remains_checked(self) -> None:
        path, output = self.task(entry=REAL_ENTRY)
        result = self.run_script(ROOT / "methods/canonica/run.wls", path, output)
        self.assertEqual(result["code"], "CANDIDATE_TRANSFORMATION")
        self.check_core(output, result)

    @unittest.skipUnless(REAL_ENTRY, "requires the declared installed CANONICA entry")
    def test_real_finite_t_exhaustion_is_not_rational_obstruction(self) -> None:
        path, output = self.task(custom=True, entry=REAL_ENTRY,
                                 ansatz_text=self.ansatz().replace('"terms" -> {1,x}', '"terms" -> {1}'))
        result = self.run_script(ROOT / "methods/canonica/run.wls", path, output)
        self.assertEqual((result["status"], result["code"]), ("INCONCLUSIVE", "METHOD_EXHAUSTED"))
        self.assertEqual(result["summary"]["failed_stage"], "diagonal_block")
        self.assertIn("finite_ansatz_exhausted", result["summary"]["diagnostic_classes"])
        self.assertNotIn("rational_transformation_obstruction", result["summary"]["diagnostic_classes"])
        self.assertEqual(result["summary"]["attempted_ansatz"]["term_count"], 1)

    @unittest.skipUnless(REAL_ENTRY, "requires the declared installed CANONICA entry")
    def test_real_targeted_second_block_keeps_complete_source_gauge(self) -> None:
        cut = self.run_root / "three-row-cut.wl"
        cut.write_text('''Module[{t = {{x,0,0},{0,1,x},{0,0,1}}, target, source},
  target = {eps {{1,0,0},{2,3,0},{4,5,6}}/x};
  source = {Map[Together, (D[t,x] + t.target[[1]]).Inverse[t], {2}]};
  <|"schema" -> "canon-neu/sector-cut-de/v1", "sector" -> <|"id" -> 3, "propagator_count" -> 2|>,
    "family_id" -> "fixture-libra-tutorial-1", "basis_id" -> "fixture-sector-3-basis-v1",
    "coefficient_domain" -> "exact-rational-functions", "basis" -> {j1,j2,j3},
    "variables" -> {x}, "regulator" -> eps, "matrices" -> source,
    "sector_boundaries" -> {{1,1},{2,3}}|>]
''')
        basis = self.run_root / "three-row-basis.wl"
        basis.write_text((BASE / "sector-basis.wl").read_text().replace('{j1, j2}', '{j1,j2,j3}'))
        ansatz = (self.ansatz(cut=cut).replace('{j1,j2}', '{j1,j2,j3}')
                  .replace('"block_index" -> 1', '"block_index" -> 2')
                  .replace('"block_bounds" -> {1,2}', '"block_bounds" -> {2,3}'))
        path, output = self.task(custom=True, entry=REAL_ENTRY, cut=cut, basis=basis, ansatz_text=ansatz)
        result = self.run_script(ROOT / "methods/canonica/run.wls", path, output)
        self.assertEqual(result["code"], "CANDIDATE_TRANSFORMATION")
        diagonal = [value for value in result["summary"]["attempts"] if value["requested_stage"] == "diagonal_block"]
        self.assertEqual([value["attempted_ansatz"]["mode"] for value in diagonal],
                         ["package-default", "explicit-finite-T"])
        self.check_core(output, result, cut=cut, basis=basis)

    @unittest.skipUnless(REAL_ENTRY, "requires the declared installed CANONICA entry")
    def test_real_multivariable_raw_cut_checks_every_direction(self) -> None:
        cut = self.run_root / "two-variable-cut.wl"
        cut.write_text('''Module[{t = {{1,x+y},{0,1}}, targets, source},
  targets = {eps {{1,2},{3,4}}/x, eps {{1,2},{3,4}}/y};
  source = MapThread[Map[Together, (D[t,#2] + t.#1).Inverse[t], {2}] &, {targets,{x,y}}];
  <|"schema" -> "canon-neu/sector-cut-de/v1", "sector" -> <|"id" -> 3, "propagator_count" -> 2|>,
    "family_id" -> "fixture-libra-tutorial-1", "basis_id" -> "fixture-sector-3-basis-v1",
    "coefficient_domain" -> "exact-rational-functions", "basis" -> {j1,j2},
    "variables" -> {x,y}, "regulator" -> eps, "matrices" -> source,
    "sector_boundaries" -> {{1,2}}|>]
''')
        ansatz = self.ansatz(cut=cut).replace('"variables" -> {x}', '"variables" -> {x,y}')
        ansatz = ansatz.replace('"terms" -> {1,x}', '"terms" -> {1,x,y}')
        path, output = self.task(custom=True, entry=REAL_ENTRY, cut=cut, ansatz_text=ansatz)
        result = self.run_script(ROOT / "methods/canonica/run.wls", path, output)
        self.assertEqual(result["code"], "CANDIDATE_TRANSFORMATION")
        self.check_core(output, result, cut=cut)

    @unittest.skipUnless(REAL_ENTRY, "requires the declared installed CANONICA entry")
    def test_real_nonrational_transformation_preserves_original_package_message(self) -> None:
        cut = self.run_root / "scalar-root-normalization-cut.wl"
        cut.write_text('''<|"schema" -> "canon-neu/sector-cut-de/v1",
  "sector" -> <|"id" -> 3, "propagator_count" -> 2|>,
  "family_id" -> "fixture-libra-tutorial-1", "basis_id" -> "fixture-sector-3-basis-v1",
  "coefficient_domain" -> "exact-rational-functions", "basis" -> {j1},
  "variables" -> {x}, "regulator" -> eps, "matrices" -> {{{1/(2 x)+eps/x}}},
  "sector_boundaries" -> {{1,1}}|>\n''')
        basis = self.run_root / "scalar-basis.wl"
        basis.write_text((BASE / "sector-basis.wl").read_text().replace('{j1, j2}', '{j1}'))
        path, output = self.task(entry=REAL_ENTRY, cut=cut, basis=basis)
        result = self.run_script(ROOT / "methods/canonica/run.wls", path, output)
        self.assertEqual(result["code"], "METHOD_EXHAUSTED")
        self.assertEqual(result["summary"]["failed_stage"], "diagonal_block")
        self.assertEqual(result["summary"]["failed_block"], 1)
        self.assertIn("rational_transformation_obstruction", result["summary"]["diagnostic_classes"])
        self.assertIn("nonrationalinv", (output / "canonica-messages.log").read_text())


if __name__ == "__main__":
    unittest.main()
