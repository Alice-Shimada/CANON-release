from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/fixtures/libra_normalization"
KERNEL = Path(os.environ.get("CANON_WOLFRAM_KERNEL") or shutil.which("WolframKernel") or "WolframKernel")
WRAPPER = os.environ.get("CANON_TEST_WOLFRAM_WRAPPER")
REAL_ENTRY = os.environ.get("CANON_TEST_LIBRA_ENTRY")
RETAIN = os.environ.get("CANON_TEST_LIBRA_NORMALIZATION_OUTPUT_ROOT")
SECTOR = {"id": 3, "propagator_count": 2}


@unittest.skipUnless(WRAPPER or KERNEL.is_file(), "requires a declared Wolfram runtime")
class LibraNormalizationTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.run_root = Path(self.temporary.name)
        if RETAIN:
            self.run_root = Path(RETAIN).resolve() / self._testMethodName
            self.run_root.mkdir(parents=True, exist_ok=False)
        self.serial = 0

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def run_script(self, script: Path, input_path: Path, output: Path, returncode: int = 0) -> dict:
        command = ([WRAPPER] if WRAPPER else [sys.executable,
            str(ROOT / "tests/wolfram_kernel_launcher.py"), str(KERNEL),
            "-noinit", "-noprompt", "-script"])
        completed = subprocess.run([*command, str(script), str(input_path), str(output)],
            cwd=self.run_root, env=os.environ.copy(), text=True, capture_output=True, timeout=60)
        output.with_suffix(".log").write_text(completed.stdout + completed.stderr)
        result_path = output / "result.json"
        self.assertEqual(completed.returncode, returncode,
            completed.stdout + completed.stderr + (result_path.read_text() if result_path.exists() else ""))
        self.assertTrue(result_path.exists(), completed.stdout + completed.stderr)
        return json.loads(result_path.read_text())

    def wrapped_entry(self, code: str, *, real: bool = False) -> Path:
        self.serial += 1
        path = self.run_root / f"package-{self.serial}.m"
        entry = Path(REAL_ENTRY) if real else FIXTURES / "public-primitives.m"
        path.write_text(f"Get[{json.dumps(str(entry))}]\n{code}\n")
        return path

    def system(self, kind: str = "scalar", replacement: tuple[str, str] | None = None) -> tuple[Path, Path]:
        basis = FIXTURES / f"{kind}-basis.wl"
        cut = FIXTURES / f"{kind}-cut.wl"
        if replacement:
            text = cut.read_text()
            self.assertIn(replacement[0], text)
            self.serial += 1
            cut = self.run_root / f"cut-{self.serial}.wl"
            cut.write_text(text.replace(*replacement))
        return basis, cut

    def provider(self, *, kind: str = "scalar", replacement: tuple[str, str] | None = None,
                 options: dict | None = None, entry: Path | None = None, returncode: int = 0,
                 normalization: str | None = "bounded",
                 hierarchy: Path | None = None) -> tuple[dict, Path, Path, Path]:
        self.serial += 1
        basis, cut = self.system(kind, replacement)
        chosen = {"package_entry": str(entry or FIXTURES / "public-primitives.m")}
        if normalization is not None:
            chosen["normalization_strategy"] = normalization
        chosen.update(options or {})
        task = {"schema": "canon-neu/script-input/v1", "task_id": f"normalization-{self.serial}",
            "step": "SEARCH_CORE", "sector": SECTOR,
            "payload": {"sector_basis": {"type": "mathematica-expression", "path": str(basis)},
                        "sector_cut_de": {"type": "mathematica-expression", "path": str(cut)},
                        "method_options": chosen}}
        if hierarchy is not None:
            task["payload"]["dependent_row_hierarchy"] = {
                "type": "mathematica-expression", "path": str(hierarchy)}
        input_path = self.run_root / f"input-{self.serial}.json"
        input_path.write_text(json.dumps(task))
        output = self.run_root / f"output-{self.serial}"
        result = self.run_script(ROOT / "methods/libra/run.wls", input_path, output, returncode)
        return result, output, basis, cut

    def check_core(self, output: Path, basis: Path, cut: Path) -> dict:
        task = {"schema": "canon-neu/script-input/v1", "task_id": "normalization-check",
            "step": "CHECK_CORE", "sector": SECTOR,
            "payload": {"sector_basis": {"type": "mathematica-expression", "path": str(basis)},
                        "sector_cut_de": {"type": "mathematica-expression", "path": str(cut)},
                        "core_candidates": {"type": "mathematica-expression", "path": str(output / "core-candidates.wl")}}}
        path = self.run_root / f"check-{self.serial}.json"
        path.write_text(json.dumps(task))
        return self.run_script(ROOT / "mma/CheckSectorCore.wls", path, self.run_root / f"checked-{self.serial}")

    def assert_success(self, result: dict, output: Path, basis: Path, cut: Path, transform: str) -> None:
        self.assertEqual((result["status"], result["code"]), ("PROVISIONAL", "CANDIDATE_TRANSFORMATION"))
        evidence = result["summary"]["normalization"]
        self.assertFalse(evidence["timed_out"])
        self.assertEqual(evidence["transformation"], transform)
        self.assertEqual(evidence["steps_used"], 1)
        self.assertEqual(evidence["attempts"][-1]["metric_after"], 0)
        self.assertTrue(evidence["attempts"][-1]["source_gauge"])
        self.assertEqual(self.check_core(output, basis, cut)["code"], "CORE_PASS")

    def test_scalar_missing_normalization_closes_core_loop(self) -> None:
        self.assert_success(*self.provider(), "{{CANON`DEData`x}}")

    def test_coupled_jordan_preserves_generic_regulator_and_closes_core_loop(self) -> None:
        result, output, basis, cut = self.provider(kind="jordan")
        self.assert_success(result, output, basis, cut, "{{CANON`DEData`x, 0}, {0, 1}}")
        trace = result["summary"]["normalization"]
        self.assertEqual(trace["initial_singularities"][-1]["generic_rank"], 1)
        self.assertEqual(trace["initial_singularities"][-1]["epsilon_zero_rank"], 0)
        self.assertEqual(trace["final_singularities"][-1]["generic_rank"], 0)
        self.assertIn("eps/x", (output / "core-candidates.wl").read_text())

    def test_invalid_options_never_load_package(self) -> None:
        marker = self.run_root / "loaded"
        entry = self.wrapped_entry(f'Put[True, {json.dumps(str(marker))}];')
        for options in ({"normalization_strategy": "Rookie"}, {"unknown": 1},
                        {"normalization_strategy": "none", "normalization_max_steps": 1},
                        {"normalization_max_steps": 0}, {"normalization_max_projectors": -1},
                        {"normalization_max_dimension": 1.5}, {"normalization_max_seconds": "2"}):
            with self.subTest(options=options):
                result, _, _, _ = self.provider(options=options, entry=entry, returncode=1)
                self.assertEqual(result["code"], "INVALID_OPTIONS")
                self.assertFalse(marker.exists())

    def test_dimension_budget_precedes_subspaces(self) -> None:
        marker = self.run_root / "subspaces"
        entry = self.wrapped_entry(f'Clear[Libra`GetSubspaces]; Libra`GetSubspaces[___] := (Put[True, {json.dumps(str(marker))}]; {{}});')
        result, _, _, _ = self.provider(kind="jordan", options={"normalization_max_dimension": 1}, entry=entry)
        self.assertEqual(result["summary"]["normalization"]["limit_code"], "DIMENSION_BUDGET")
        self.assertFalse(result["summary"]["normalization"]["timed_out"])
        self.assertFalse(marker.exists())

    def test_step_and_projector_budgets_preserve_partial_transform(self) -> None:
        for field, code in (("normalization_max_steps", "STEP_BUDGET"),
                            ("normalization_max_projectors", "PROJECTOR_BUDGET")):
            with self.subTest(field=field):
                result, output, _, _ = self.provider(replacement=("(1 + eps)/x", "(3 + eps)/x"), options={field: 1})
                evidence = result["summary"]["normalization"]
                self.assertEqual(evidence["limit_code"], code)
                self.assertEqual(evidence["steps_used"], 1)
                self.assertEqual(evidence["transformation"], "{{CANON`DEData`x}}")
                self.assertFalse((output / "core-candidates.wl").exists())

    def test_multiple_balances_publish_complete_cumulative_source_gauge(self) -> None:
        result, output, basis, cut = self.provider(
            replacement=("(1 + eps)/x", "(3 + eps)/x"),
            options={"normalization_max_steps": 3, "normalization_max_projectors": 3})
        self.assertEqual(result["code"], "CANDIDATE_TRANSFORMATION")
        evidence = result["summary"]["normalization"]
        accepted = [attempt for attempt in evidence["attempts"] if attempt.get("accepted")]
        self.assertEqual(evidence["steps_used"], 3)
        self.assertEqual(evidence["projectors_tested"], 3)
        self.assertEqual(evidence["transformation"], "{{CANON`DEData`x^3}}")
        self.assertEqual([(a["metric_before"], a["metric_after"]) for a in accepted],
                         [(6, 4), (4, 2), (2, 0)])
        self.assertTrue(all(a["source_gauge"] for a in accepted))
        self.assertEqual(self.check_core(output, basis, cut)["code"], "CORE_PASS")

    def test_negative_offsets_at_nonzero_finite_pole_close_core_loop(self) -> None:
        result, output, basis, cut = self.provider(
            replacement=("(1 + eps)/x", "(-2 + eps)/(x - 1)"))
        self.assertEqual(result["code"], "CANDIDATE_TRANSFORMATION")
        evidence = result["summary"]["normalization"]
        self.assertEqual(evidence["steps_used"], 2)
        self.assertEqual(evidence["initial_singularities"][0]["point"], "1")
        self.assertEqual(evidence["initial_singularities"][0]["integer_intercepts"], [-2])
        self.assertTrue(all(row["integer_intercepts"] == [0]
                            for row in evidence["final_singularities"]))
        self.assertEqual(self.check_core(output, basis, cut)["code"], "CORE_PASS")

    def test_every_budget_rejects_boolean_before_loading_package(self) -> None:
        marker = self.run_root / "loaded-boolean-budget"
        entry = self.wrapped_entry(f'Put[True, {json.dumps(str(marker))}];')
        for field in ("normalization_max_steps", "normalization_max_projectors",
                      "normalization_max_dimension", "normalization_max_seconds"):
            with self.subTest(field=field):
                result, _, _, _ = self.provider(options={field: True}, entry=entry, returncode=1)
                self.assertEqual(result["code"], "INVALID_OPTIONS")
                self.assertFalse(marker.exists())

    def test_zero_offsets_do_not_construct_unnecessary_subspaces(self) -> None:
        marker = self.run_root / "unnecessary-subspaces"
        entry = self.wrapped_entry(
            f'Clear[Libra`GetSubspaces]; Libra`GetSubspaces[___] := '
            f'(Put[True, {json.dumps(str(marker))}]; $Failed);')
        result, output, basis, cut = self.provider(
            replacement=("(1 + eps)/x", "eps/x"), entry=entry)
        self.assertEqual(result["summary"]["normalization"]["steps_used"], 0)
        self.assertEqual(result["summary"]["normalization"]["projectors_tested"], 0)
        self.assertFalse(marker.exists())
        self.assertEqual(self.check_core(output, basis, cut)["code"], "CORE_PASS")

    def test_malformed_subspaces_stop_without_factorout_or_candidate(self) -> None:
        marker = self.run_root / "factorout-after-invalid-subspaces"
        entry = self.wrapped_entry(
            'Clear[Libra`GetSubspaces, Libra`FactorOut]; '
            'Libra`GetSubspaces[___] := {{{1, 0}}}; '
            f'Libra`FactorOut[___] := (Put[True, {json.dumps(str(marker))}]; {{{{1}}}});')
        result, output, _, _ = self.provider(entry=entry)
        self.assertEqual((result["status"], result["code"]), ("INCONCLUSIVE", "METHOD_EXHAUSTED"))
        self.assertEqual(result["summary"]["normalization"]["limit_code"], "SUBSPACE_RESULT")
        self.assertFalse(marker.exists())
        self.assertFalse((output / "core-candidates.wl").exists())

    def test_seconds_budget_interrupts_public_primitive(self) -> None:
        entry = self.wrapped_entry("Clear[Libra`GetSubspaces]; Libra`GetSubspaces[___] := (Pause[3]; {});")
        result, output, _, _ = self.provider(options={"normalization_max_seconds": 1}, entry=entry)
        self.assertEqual((result["status"], result["code"]), ("INCONCLUSIVE", "METHOD_EXHAUSTED"))
        evidence = result["summary"]["normalization"]
        self.assertEqual(evidence["limit_code"], "SECONDS_BUDGET")
        self.assertTrue(evidence["timed_out"])
        self.assertEqual(evidence["stopped_stage"], "GetSubspaces")
        self.assertEqual(evidence["steps_used"], 0)
        self.assertFalse((output / "core-candidates.wl").exists())

    def test_noninteger_undecidable_and_irregular_scopes_have_specific_limits(self) -> None:
        for source, code in (("(1/2 + eps)/x", "NONINTEGER_INTERCEPT"),
                             ("(a + eps)/x", "UNDECIDABLE_INTEGER_INTERCEPT"),
                             ("(1 + eps)/x^2", "EPSILON_ZERO_IRREGULAR"),
                             ("(1 + eps)/(x^2 + 1)", "NONLINEAR_POLE"),
                             ("(1 + eps)/(x - eps)", "UNDECIDABLE_POLE"),
                             ("(1/eps + eps)/x", "EPSILON_ZERO_UNDEFINED")):
            with self.subTest(source=source):
                result, _, _, _ = self.provider(replacement=("(1 + eps)/x", source))
                self.assertEqual(result["code"], "OUT_OF_SCOPE")
                evidence = result["summary"]["normalization"]
                self.assertEqual(evidence["limit_code"], code)
                self.assertEqual(evidence["projectors_tested"], 0)

    def test_bad_projector_never_reaches_balance(self) -> None:
        marker = self.run_root / "balance-called"
        entry = self.wrapped_entry(f'Clear[Libra`Projector, Libra`Balance]; Libra`Projector[___] := {{{{2}}}}; Libra`Balance[___] := (Put[True, {json.dumps(str(marker))}]; {{{{1}}}});')
        result, output, _, _ = self.provider(entry=entry)
        evidence = result["summary"]["normalization"]
        self.assertEqual(evidence["limit_code"], "NO_PROGRESS_PROJECTOR")
        self.assertEqual(evidence["attempts"][0]["rejection"], "INVALID_PROJECTOR")
        self.assertFalse(marker.exists())
        self.assertFalse((output / "core-candidates.wl").exists())

    def test_source_gauge_and_strict_progress_reject_bad_provider_results(self) -> None:
        for override, rejection in (
            ("Libra`Transform[m_?MatrixQ, t_, variable_, ___] := {{0}};", "GAUGE_IDENTITY"),
            ("Clear[Libra`Balance]; Libra`Balance[___] := {{1}};", "NO_STRICT_PROGRESS"),
            ("Clear[Libra`Balance]; Libra`Balance[___] := {{0}};", "SINGULAR_BALANCE")):
            with self.subTest(rejection=rejection):
                result, _, _, _ = self.provider(entry=self.wrapped_entry(override))
                evidence = result["summary"]["normalization"]
                self.assertEqual(evidence["limit_code"], "NO_PROGRESS_PROJECTOR")
                self.assertEqual(evidence["attempts"][0]["rejection"], rejection)

    def test_gauge_valid_balance_cannot_introduce_irregularity(self) -> None:
        entry = self.wrapped_entry('''Clear[Libra`GetSubspaces];
Libra`GetSubspaces[m_, {variable_, Infinity}, regulator_, Left, ___] := {{{1, 0}}};
Libra`GetSubspaces[m_, {variable_, 0}, regulator_, Right, ___] := {{{1, 0}}};
Libra`GetSubspaces[___] := {};''')
        result, output, _, _ = self.provider(kind="jordan",
            replacement=("(1 + eps)/x, eps}, {0, eps/x", "(1 + eps)/x, 0}, {eps/x, eps/x"), entry=entry)
        evidence = result["summary"]["normalization"]
        self.assertEqual(evidence["limit_code"], "NO_PROGRESS_PROJECTOR")
        self.assertEqual(evidence["attempts"][0]["rejection"], "IRREGULARITY_INCREASE")
        self.assertEqual(evidence["attempts"][0]["singularities_before"][-1]["generic_rank"], 0)
        self.assertEqual(evidence["attempts"][0]["singularities_after"][-1]["generic_rank"], 1)
        self.assertFalse((output / "core-candidates.wl").exists())

    def test_none_keeps_six_symbol_legacy_contract(self) -> None:
        entry = self.wrapped_entry("Clear[Libra`GetSubspaces, Libra`Projector, Libra`Balance]; Remove[Libra`GetSubspaces, Libra`Projector, Libra`Balance];")
        result, output, basis, cut = self.provider(replacement=("(1 + eps)/x", "eps/x"),
            normalization=None, entry=entry)
        self.assertEqual(result["status"], "PROVISIONAL")
        self.assertEqual(result["summary"]["normalization"], {"strategy": "none"})
        self.assertEqual(self.check_core(output, basis, cut)["code"], "CORE_PASS")

    def test_bounded_requires_extra_public_primitives(self) -> None:
        entry = self.wrapped_entry("Clear[Libra`GetSubspaces, Libra`Projector, Libra`Balance]; Remove[Libra`GetSubspaces, Libra`Projector, Libra`Balance];")
        result, _, _, _ = self.provider(entry=entry, returncode=1)
        self.assertEqual(result["code"], "TOOL_ERROR")

    @unittest.skipUnless(REAL_ENTRY and Path(REAL_ENTRY).is_file(), "declare CANON_TEST_LIBRA_ENTRY for real public primitives")
    def test_real_libra_scalar_and_jordan_use_public_primitives_then_check_core(self) -> None:
        for kind, transform in (("scalar", "{{CANON`DEData`x}}"), ("jordan", "{{CANON`DEData`x, 0}, {0, 1}}")):
            with self.subTest(kind=kind):
                self.assert_success(*self.provider(kind=kind, entry=Path(REAL_ENTRY)), transform)

    @unittest.skipUnless(REAL_ENTRY and Path(REAL_ENTRY).is_file(), "declare CANON_TEST_LIBRA_ENTRY for offset signs and cumulative gauges")
    def test_real_libra_multiple_balances_and_negative_finite_offsets(self) -> None:
        for source, steps in (("(3 + eps)/x", 3), ("(-2 + eps)/(x - 1)", 2)):
            with self.subTest(source=source):
                result, output, basis, cut = self.provider(
                    replacement=("(1 + eps)/x", source), entry=Path(REAL_ENTRY))
                self.assertEqual(result["code"], "CANDIDATE_TRANSFORMATION")
                evidence = result["summary"]["normalization"]
                self.assertEqual(evidence["steps_used"], steps)
                accepted = [a for a in evidence["attempts"] if a.get("accepted")]
                self.assertTrue(all(a["source_gauge"] and a["generic_ranks_not_increased"]
                                    and a["metric_after"] < a["metric_before"] for a in accepted))
                self.assertEqual(accepted[-1]["metric_after"], 0)
                self.assertEqual(self.check_core(output, basis, cut)["code"], "CORE_PASS")

    @unittest.skipUnless(REAL_ENTRY and Path(REAL_ENTRY).is_file(), "declare CANON_TEST_LIBRA_ENTRY for real legacy behavior")
    def test_real_libra_legacy_scalar_stays_exhausted_without_opt_in(self) -> None:
        result, _, _, _ = self.provider(options={"normalization_strategy": "none"}, entry=Path(REAL_ENTRY))
        self.assertEqual((result["status"], result["code"]), ("INCONCLUSIVE", "METHOD_EXHAUSTED"))
        self.assertEqual(result["summary"]["normalization"], {"strategy": "none"})

    @unittest.skipUnless(REAL_ENTRY and Path(REAL_ENTRY).is_file(), "declare CANON_TEST_LIBRA_ENTRY for real budget behavior")
    def test_real_libra_budget_stops_before_factorout_with_partial_history(self) -> None:
        result, output, _, _ = self.provider(replacement=("(1 + eps)/x", "(3 + eps)/x"),
            options={"normalization_max_steps": 1}, entry=Path(REAL_ENTRY))
        evidence = result["summary"]["normalization"]
        self.assertEqual(result["code"], "METHOD_EXHAUSTED")
        self.assertEqual(evidence["limit_code"], "STEP_BUDGET")
        self.assertEqual(evidence["transformation"], "{{CANON`DEData`x}}")
        self.assertEqual(evidence["steps_used"], 1)
        self.assertFalse((output / "core-candidates.wl").exists())

    @unittest.skipUnless(REAL_ENTRY and Path(REAL_ENTRY).is_file(), "declare CANON_TEST_LIBRA_ENTRY for combined strategies")
    def test_real_bounded_normalization_composes_with_explicit_residue_hierarchy(self) -> None:
        hierarchy = self.run_root / "normalized-sector-hierarchy.wl"
        text = (ROOT / "tests/fixtures/method_cards/libra-dependent-row-hierarchy.wl").read_text()
        text = text.replace('"fixture-libra-tutorial-1"', '"libra-normalization-jordan"')
        text = text.replace('"fixture-sector-3-basis-v1"', '"jordan-v1"')
        hierarchy.write_text(text)
        result, output, basis, cut = self.provider(kind="jordan", entry=Path(REAL_ENTRY),
            options={"dependent_row_strategy": "sector-de-closure"}, hierarchy=hierarchy)
        self.assertEqual(result["code"], "CANDIDATE_TRANSFORMATION")
        self.assertEqual(result["summary"]["normalization"]["transformation"], "{{CANON`DEData`x, 0}, {0, 1}}")
        dependent_rows = result["summary"]["dependent_rows"]
        self.assertEqual(dependent_rows["dependent_row_strategy"], "sector-de-closure")
        self.assertEqual(dependent_rows["hierarchy_stage"], "post-fuchsify-residue-matrices")
        self.assertEqual(dependent_rows["combined_mask_nonzeros"], 4)
        self.assertEqual(self.check_core(output, basis, cut)["code"], "CORE_PASS")


if __name__ == "__main__":
    unittest.main()
