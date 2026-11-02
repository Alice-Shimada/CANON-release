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
FIXTURES = ROOT / "tests/fixtures/libra_multivariable"
KERNEL = Path(os.environ.get("CANON_WOLFRAM_KERNEL") or shutil.which("WolframKernel") or "WolframKernel").resolve()
REAL_ENTRY = os.environ.get("CANON_TEST_LIBRA_ENTRY")
RETAIN = os.environ.get("CANON_TEST_LIBRA_MULTIVARIABLE_OUTPUT_ROOT")
SECTOR = {"id": 6, "propagator_count": 2}


@unittest.skipUnless(KERNEL.is_file(), "requires a declared WolframKernel")
class LibraMultivariableTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.run_root = Path(RETAIN).resolve() / self._testMethodName if RETAIN else Path(self.temporary.name)
        self.run_root.mkdir(parents=True, exist_ok=not bool(RETAIN))
        self.serial = 0

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def wl(self, name: str, text: str) -> Path:
        self.serial += 1
        path = self.run_root / f"{self.serial}-{name}.wl"
        path.write_text(text)
        return path

    def package(self, code: str) -> Path:
        return self.wl("package", f"Get[{json.dumps(str(FIXTURES / 'public-primitives.m'))}]\n{code}\n")

    def invoke(self, step: str, payload: dict, *, method: str | None = None, returncode: int = 0) -> tuple[dict, Path]:
        self.serial += 1
        input_path = self.run_root / f"input-{self.serial}.json"
        output = self.run_root / f"output-{self.serial}"
        input_path.write_text(json.dumps({"schema": "canon-neu/script-input/v1", "task_id": f"multi-{self.serial}",
            "step": step, "sector": SECTOR, "payload": payload}))
        scripts = {"SEARCH_CORE": "methods/libra/run.wls", "CHECK_CORE": "mma/CheckSectorCore.wls",
            "BUILD_FULL_DE": "mma/BuildFullSectorDE.wls", "SOLVE_TAIL": "mma/SolveTail.wls",
            "CHECK_CANONICAL": "mma/CheckCanonical.wls", "COMMIT_SECTOR": "mma/CommitSector.wls",
            "FINAL_CHECK": "mma/CheckFullSystem.wls"}
        environment = os.environ.copy()
        for key in ("OMP_NUM_THREADS", "MKL_NUM_THREADS", "OPENBLAS_NUM_THREADS", "VECLIB_MAXIMUM_THREADS"):
            environment[key] = "1"
        if method:
            environment["CANON_WOLFRAMSCRIPT"] = os.environ.get("CANON_WOLFRAMSCRIPT") or shutil.which("wolframscript") or "wolframscript"
            command = [sys.executable, str(ROOT / "run_step.py"), str(input_path), str(output), "--method", method]
        else:
            command = [sys.executable, str(ROOT / "tests/wolfram_kernel_launcher.py"), str(KERNEL),
                "-noinit", "-noprompt", "-script", str(ROOT / scripts[step]), str(input_path), str(output)]
        completed = subprocess.run(command, cwd=ROOT, env=environment, text=True, capture_output=True, timeout=120)
        output.with_suffix(".log").write_text(completed.stdout + completed.stderr)
        path = output / "result.json"
        self.assertEqual(completed.returncode, returncode, completed.stdout + completed.stderr)
        self.assertTrue(path.is_file(), completed.stdout + completed.stderr)
        return json.loads(path.read_text()), output

    @staticmethod
    def ref(path: Path) -> dict:
        return {"type": "mathematica-expression", "path": str(path)}

    def artifact(self, run: tuple[dict, Path], key: str) -> dict:
        return self.ref(run[1] / run[0]["artifacts"][key]["path"])

    def provider(self, *, cut: Path | None = None, basis: Path | None = None,
                 entry: Path | None = None, sequence: list | None = None, options: dict | None = None,
                 hierarchy: Path | None = None, returncode: int = 0, via_cli: bool = False) -> tuple[dict, Path]:
        chosen = {"package_entry": str(entry or FIXTURES / "public-primitives.m"),
            "direction_sequence": sequence if sequence is not None else []}
        chosen.update(options or {})
        payload = {"sector_basis": self.ref(basis or FIXTURES / "sector-basis.wl"),
            "sector_cut_de": self.ref(cut or FIXTURES / "fuchsian-cut.wl"), "method_options": chosen}
        if hierarchy:
            payload["dependent_row_hierarchy"] = self.ref(hierarchy)
        return self.invoke("SEARCH_CORE", payload, returncode=returncode, method="libra" if via_cli else None)

    def check(self, provider: tuple[dict, Path], cut: Path, basis: Path | None = None) -> tuple[dict, Path]:
        return self.invoke("CHECK_CORE", {"sector_basis": self.ref(basis or FIXTURES / "sector-basis.wl"),
            "sector_cut_de": self.ref(cut), "core_candidates": self.artifact(provider, "core_candidates")})

    def exhausted(self, run: tuple[dict, Path], code: str) -> None:
        result, output = run
        self.assertEqual((result["status"], result["code"]), ("INCONCLUSIVE", "METHOD_EXHAUSTED"))
        self.assertEqual(result["summary"]["multivariable"]["limit_code"], code)
        self.assertTrue((output / result["artifacts"]["libra_diagnostic"]["path"]).is_file())
        self.assertFalse((output / "core-candidates.wl").exists())

    def test_empty_sequence_never_calls_fuchsify_and_hands_off(self) -> None:
        entry = self.package('Clear[Libra`Fuchsify]; Libra`Fuchsify[___] := Abort[];')
        run = self.provider(entry=entry)
        self.assertEqual(run[0]["summary"]["multivariable"]["completed_directions"], 0)
        self.assertEqual(self.check(run, FIXTURES / "fuchsian-cut.wl")[0]["code"], "CORE_PASS")

    def test_partial_repeated_sequence_is_executed_exactly(self) -> None:
        capture = self.run_root / "directions.wl"
        entry = self.package(f'Clear[Libra`Fuchsify]; calls={{}}; Libra`Fuchsify[ds_,v_] := '
            f'(AppendTo[calls,v]; Put[calls,{json.dumps(str(capture))}]; IdentityMatrix[2]);')
        run = self.provider(entry=entry, sequence=[2, 2])
        self.assertEqual(run[0]["summary"]["multivariable"]["completed_directions"], 2)
        self.assertIn('y,', capture.read_text())
        self.assertEqual(self.check(run, FIXTURES / "fuchsian-cut.wl")[0]["code"], "CORE_PASS")

    def test_invalid_options_do_not_load_package(self) -> None:
        marker = self.run_root / "loaded"
        entry = self.package(f'Put[True,{json.dumps(str(marker))}];')
        for options in ({"direction_sequence": [0]}, {"direction_sequence": [3]},
                {"direction_sequence": [True]}, {"direction_sequence": [1.5]},
                {"direction_sequence": "x"}, {"factorization_max_equations": 0},
                {"factorization_max_equations": True}, {"max_wall_seconds": 0},
                {"max_wall_seconds": True}, {"unknown": 1}):
            with self.subTest(options=options):
                run = self.provider(entry=entry, options=options, returncode=1)
                self.assertEqual(run[0]["code"], "INVALID_OPTIONS")
                self.assertFalse(marker.exists())

    def test_factor_options_reject_inexact_reference_and_invalid_search(self) -> None:
        marker = self.run_root / "loaded"
        entry = self.package(f'Put[True,{json.dumps(str(marker))}];')
        for options in ({"reference_regulator": 0.5}, {"reference_regulator": True},
                {"reference_regulator": {"numerator": 1, "denominator": 0}},
                {"reference_regulator": {"numerator": 1, "denominator": 2, "extra": 0}},
                {"free_parameter_strategy": "random"}, {"free_parameter_max_trials": 2},
                {"free_parameter_strategy": "bounded-rational-search", "free_parameter_max_trials": True}):
            with self.subTest(options=options):
                run = self.provider(entry=entry, options=options, returncode=1)
                self.assertEqual(run[0]["code"], "INVALID_OPTIONS")
                self.assertFalse(marker.exists())

    @unittest.skipUnless(REAL_ENTRY, "requires real Libra exact factorization")
    def test_exact_reference_and_bounded_points_recover_invertible_shared_factor(self) -> None:
        original = (FIXTURES / "fuchsian-cut.wl").read_text()
        for singular_reference in (False, True):
            with self.subTest(singular_reference=singular_reference):
                k = "(2*eps-1)" if singular_reference else "1"
                cut = self.wl("factor-cut", original.replace(
                    '{{{eps/x, 0}, {0, eps/x}}, {{eps/y, 0}, {0, eps/y}}}',
                    '{{{0,eps*'+k+'/x},{eps/('+k+'*x),0}},{{0,eps*'+k+'/y},{eps/('+k+'*y),0}}}'))
                default = self.provider(cut=cut, entry=Path(REAL_ENTRY))
                self.exhausted(default, "REFERENCE_EPSILON_SINGULAR" if singular_reference else "FACTORIZATION_TRANSFORMATION")
                options = {"reference_regulator": 1 if singular_reference else {"numerator": 1, "denominator": 2},
                    "free_parameter_strategy": "bounded-rational-search", "free_parameter_max_trials": 1}
                limited = self.provider(cut=cut, entry=Path(REAL_ENTRY), options=options)
                self.exhausted(limited, "FREE_PARAMETER_BUDGET")
                self.assertEqual(limited[0]["summary"]["multivariable"]["free_parameter_trial_count"], 1)
                options["free_parameter_max_trials"] = 4
                recovered = self.provider(cut=cut, entry=Path(REAL_ENTRY), options=options)
                summary = recovered[0]["summary"]["multivariable"]
                self.assertEqual(summary["free_parameter_selected_index"], 3)
                self.assertEqual(summary["free_parameter_trial_count"], 3)
                self.assertEqual(self.check(recovered, cut)[0]["code"], "CORE_PASS")

    @unittest.skipUnless(REAL_ENTRY, "requires real Libra single-variable plumbing")
    def test_single_variable_reference_forwarding_and_bounded_specialization(self) -> None:
        capture = self.run_root / "reference.wl"
        entry = self.wl("single-package", f'Get[{json.dumps(REAL_ENTRY)}];'
            'Clear[Libra`FactorOut]; Libra`FactorOut[ds_,v_,e_,mu_,___] := '
            f'(Put[mu,{json.dumps(str(capture))}]; {{{{C[1],C[2]}},{{C[2],C[1]}}}});')
        cut = self.wl("single-cut", (FIXTURES / "fuchsian-cut.wl").read_text().replace(
            '"variables" -> {x, y}', '"variables" -> {x}').replace(
            '{{{eps/x, 0}, {0, eps/x}}, {{eps/y, 0}, {0, eps/y}}}', '{{{0,eps/x},{eps/x,0}}}'))
        payload = {"sector_basis": self.ref(FIXTURES / "sector-basis.wl"), "sector_cut_de": self.ref(cut),
            "method_options": {"package_entry": str(entry), "reference_regulator": {"numerator": 2, "denominator": 3}}}
        default = self.invoke("SEARCH_CORE", payload)
        self.assertEqual(default[0]["summary"]["limit_code"], "FACTORIZATION_TRANSFORMATION")
        payload["method_options"].update(free_parameter_strategy="bounded-rational-search", free_parameter_max_trials=3)
        recovered = self.invoke("SEARCH_CORE", payload)
        self.assertEqual(recovered[0]["summary"]["dependent_rows"]["free_parameter_selected_index"], 3)
        self.assertEqual(capture.read_text().strip(), "2/3")
        self.assertEqual(self.check(recovered, cut)[0]["code"], "CORE_PASS")

    def test_multivariable_normalization_is_explicitly_out_of_scope(self) -> None:
        run = self.provider(entry=self.run_root / "must-not-load.m", options={"normalization_strategy": "bounded"})
        self.assertEqual((run[0]["status"], run[0]["code"]), ("INCONCLUSIVE", "OUT_OF_SCOPE"))

    def test_nonflat_and_invalid_variables_are_input_errors(self) -> None:
        original = (FIXTURES / "fuchsian-cut.wl").read_text()
        for value in (original.replace('"variables" -> {x, y}', '"variables" -> {x, x}'),
                original.replace('"variables" -> {x, y}', '"variables" -> {x, eps}'),
                original.replace('eps/y', 'eps*x')):
            with self.subTest(value=value):
                run = self.provider(cut=self.wl("invalid-cut", value), entry=self.run_root / "must-not-load.m", returncode=1)
                self.assertEqual(run[0]["code"], "INVALID_DIFFERENTIAL_SYSTEM")

    def test_all_directions_are_checked_even_when_not_traversed(self) -> None:
        entry = self.package('Clear[Libra`FuchsianQ]; Libra`FuchsianQ[m_,v_] := (SymbolName[v] =!= "y");')
        self.exhausted(self.provider(entry=entry, sequence=[1]), "NOT_JOINTLY_FUCHSIAN")

    def test_equation_budget_never_truncates_or_calls_solver(self) -> None:
        marker = self.run_root / "solved"
        entry = self.package('Clear[Libra`FactorDependence,Libra`GaussSolve]; '
            'Libra`FactorDependence[m_,e_,mu_,___] := Module[{t=Unique["t"],u=Unique["u"],x=CANON`DEData`x},'
            '{{t*(1+x)},DiagonalMatrix[{t,u}],{t,u}}]; '
            f'Libra`GaussSolve[___] := (Put[True,{json.dumps(str(marker))}]; {{}});')
        run = self.provider(entry=entry, options={"factorization_max_equations": 1})
        self.exhausted(run, "EQUATION_BUDGET")
        self.assertFalse(marker.exists())
        self.assertEqual(run[0]["summary"]["multivariable"]["factorization_equation_count"], 2)
        self.assertIsNone(run[0]["summary"]["multivariable"]["factorization_solver_equation_count"])

    def test_numeric_proportions_reduce_solver_input_and_preserve_raw_count(self) -> None:
        capture = self.run_root / "solver-count.wl"
        entry = self.package('Clear[Libra`FactorDependence,Libra`GaussSolve]; '
            'Libra`FactorDependence[___] := Module[{t=Unique["t"],u=Unique["u"],e=CANON`DEData`eps},'
            '{{2*(t-u),-6*(t-u),3/5*(t-u),e*(t-u)},DiagonalMatrix[{t,u}],{t,u}}]; '
            f'Libra`GaussSolve[eqs_,vars_,___] := (Put[Length[eqs],{json.dumps(str(capture))}]; '
            '{First[vars]->Last[vars]});')
        run = self.provider(entry=entry, via_cli=True)
        summary = run[0]["summary"]["multivariable"]
        self.assertEqual(summary["factorization_equation_count"], 4)
        self.assertEqual(summary["factorization_solver_equation_count"], 2)
        self.assertEqual(capture.read_text().strip(), "2")
        self.assertEqual(self.check(run, FIXTURES / "fuchsian-cut.wl")[0]["code"], "CORE_PASS")

    def test_invalid_coefficient_equations_stop_before_solver(self) -> None:
        for expression, code in (("1/t", "INVALID_LINEAR_EQUATIONS"),
                ("Sin[CANON`DEData`x]*t", "NONPOLYNOMIAL_EQUATIONS")):
            with self.subTest(expression=expression):
                marker = self.run_root / f"solved-{code}"
                entry = self.package('Clear[Libra`FactorDependence,Libra`GaussSolve]; '
                    'Libra`FactorDependence[___] := Module[{t=Unique["t"],u=Unique["u"]},'
                    f'{{{{{expression}}},DiagonalMatrix[{{t,u}}],{{t,u}}}}]; '
                    f'Libra`GaussSolve[___] := (Put[True,{json.dumps(str(marker))}]; {{}});')
                self.exhausted(self.provider(entry=entry), code)
                self.assertFalse(marker.exists())

    def test_kinematic_factor_and_invalid_template_are_rejected(self) -> None:
        for code, override in (
            ("FACTORIZATION_TRANSFORMATION", 'Clear[Libra`GaussSolve]; '
                'Libra`GaussSolve[eqs_,vars_,___] := {First[vars] -> CANON`DEData`x};'),
            ("FACTOR_TEMPLATE", 'Clear[Libra`FactorDependence]; Libra`FactorDependence[___] := '
                'Module[{t=Unique["t"]},{{},DiagonalMatrix[{t,t}],{t}}];')):
            with self.subTest(code=code):
                self.exhausted(self.provider(entry=self.package(override)), code)

    def hierarchy(self, *, budget: int = 4, basis_id: str = "raw/6") -> Path:
        return self.wl("hierarchy", '<|"schema"->"canon-neu/libra-dependent-row-hierarchy/v1",'
            '"hierarchy_id"->"multi-hierarchy","sector"-><|"id"->6,"propagator_count"->2|>,'
            f'"family_id"->"fixture-libra-multivariable","basis_id"->{json.dumps(basis_id)},'
            '"basis"->{j1,j2},"master_sector_labels"->{{1,0},{1,1}},'
            f'"sector_hierarchy"->IdentityMatrix[2],"max_mask_nonzeros"->{budget},'
            '"provenance"-><|"producer"->"test","tool"->"test","tool_revision"->"test",'
            '"mapped_sectors"->False,"source_artifact"->"source.wl","source_sha256"->'
            f'{json.dumps("0" * 64)}|>|>')

    def test_hierarchy_uses_untraversed_directions_and_keeps_provenance(self) -> None:
        capture = self.run_root / "public-mask.wl"
        entry = self.package('Clear[Libra`FactorDependence]; '
            'Libra`FactorDependence[m_,e_,mu_,opts___Rule] := Module[{t=Unique["t"],u=Unique["u"]},'
            f'Put[Libra`DependentRowIndices /. {{opts}},{json.dumps(str(capture))}];'
            '{{},DiagonalMatrix[{t,u}],{t,u}}];')
        cut = self.wl("hierarchy-cut", (FIXTURES / "fuchsian-cut.wl").read_text().replace(
            '{{eps/y, 0}, {0, eps/y}}', '{{0, eps/y}, {0, 0}}'))
        run = self.provider(cut=cut, entry=entry, sequence=[1], hierarchy=self.hierarchy(),
            options={"dependent_row_strategy": "sector-de-closure"})
        rows = run[0]["summary"]["dependent_rows"]
        self.assertEqual(rows["combined_mask"], [[1, 1], [0, 1]])
        self.assertEqual(rows["hde_nonzeros"], 3)
        self.assertEqual(rows["hierarchy_id"], "multi-hierarchy")
        self.assertEqual(len(rows["hierarchy_artifact_sha256"]), 64)
        self.assertEqual(rows["hierarchy_source_artifact"], "source.wl")
        self.assertEqual(rows["hierarchy_source_sha256"], "0" * 64)
        self.assertIn("{{1, 1}, {0, 1}}", capture.read_text())
        self.assertEqual(self.check(run, cut)[0]["code"], "CORE_PASS")

    def test_hierarchy_budget_and_identity_fail_before_factorization(self) -> None:
        marker = self.run_root / "factor-called"
        entry = self.package('Clear[Libra`FactorDependence]; Libra`FactorDependence[___] := '
            f'(Put[True,{json.dumps(str(marker))}];$Failed);')
        run = self.provider(entry=entry, hierarchy=self.hierarchy(budget=1),
            options={"dependent_row_strategy": "sector-de-closure"})
        self.exhausted(run, "MASK_BUDGET")
        self.assertFalse(marker.exists())
        run = self.provider(entry=entry, hierarchy=self.hierarchy(basis_id="mismatch"),
            options={"dependent_row_strategy": "sector-de-closure"}, returncode=1)
        self.assertEqual(run[0]["code"], "INVALID_DIFFERENTIAL_SYSTEM")
        self.assertFalse(marker.exists())

    def test_singular_fixed_reference_does_not_create_candidate(self) -> None:
        cut = self.wl("reference-singular-cut", (FIXTURES / "fuchsian-cut.wl").read_text().replace(
            'eps/', 'eps/(2*eps-1)/'))
        self.exhausted(self.provider(cut=cut), "REFERENCE_EPSILON_SINGULAR")

    def test_abort_timeout_silent_failure_and_malformed_readback(self) -> None:
        for code, override, options in (
            ("ABORTED", 'Clear[Libra`Fuchsify]; Libra`Fuchsify[___] := Abort[];', {}),
            ("TIME_BUDGET", 'Clear[Libra`Fuchsify]; Libra`Fuchsify[___] := (Pause[3];IdentityMatrix[2]);', {"max_wall_seconds": 0.2}),
            ("APPLY_DIRECTION", 'Clear[Libra`Transform]; Libra`Transform[___] := $Failed;', {}),
            ("APPLY_DIRECTION", 'Clear[Libra`Transform]; Libra`Transform[ds_,___] := (ds[CANON`DEData`x]={{1}};Null);', {})):
            with self.subTest(code=code):
                run = self.provider(entry=self.package(override), sequence=[1], options=options)
                self.exhausted(run, code)
                self.assertEqual(run[0]["summary"]["multivariable"]["timed_out"], code == "TIME_BUDGET")

    def test_timeout_retains_complete_previous_gauge_snapshot(self) -> None:
        entry = self.package('Clear[Libra`Fuchsify,Libra`Transform]; calls=0; '
            'Libra`Fuchsify[ds_,v_] := If[SymbolName[v]=="x",DiagonalMatrix[{v,1}],IdentityMatrix[2]]; '
            'Libra`Transform[ds_,t_,___] := (calls++; Do['
            'ds[v]=Map[Together,Inverse[t].(ds[v].t-D[t,v]),{2}],{v,ds["variables"]}];'
            'If[calls==2,ds[First[ds["variables"]]]=ConstantArray[0,{2,2}];Pause[3]];Null);')
        run = self.provider(entry=entry, sequence=[1, 2], options={"max_wall_seconds": 0.8})
        self.exhausted(run, "TIME_BUDGET")
        self.assertEqual(run[0]["summary"]["multivariable"]["completed_directions"], 1)
        diagnostic = run[1] / run[0]["artifacts"]["libra_diagnostic"]["path"]
        script = self.wl("verify-retained", f'Get[{json.dumps(str(ROOT / "mma/lib/MethodCardCore.wl"))}];'
            f'd=CanonMethodCard`ReadWLData[{json.dumps(str(diagnostic))}];'
            f'c=CanonMethodCard`ReadWLData[{json.dumps(str(FIXTURES / "fuchsian-cut.wl"))}];'
            't=d["transformation"]; b=d["transformed_matrices"];'
            'ok=And@@MapThread[CanonMethodCard`ZeroMatrixQ[#1.t-D[t,#2]-t.#3]&,'
            '{c["matrices"],c["variables"],b}];Quit[If[TrueQ[ok]&&t=!=IdentityMatrix[2],0,1]];')
        completed = subprocess.run([sys.executable, str(ROOT / "tests/wolfram_kernel_launcher.py"),
            str(KERNEL), "-noinit", "-noprompt", "-script", str(script)],
            cwd=ROOT, env=os.environ.copy(), text=True, capture_output=True, timeout=120)
        script.with_suffix(".log").write_text(completed.stdout + completed.stderr)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)

    def test_unsatisfied_coefficients_and_singular_specialization_are_rejected(self) -> None:
        for code, equation, template in (("LINEAR_EQUATIONS_UNSATISFIED", "t", "DiagonalMatrix[{t,u}]"),
                ("FACTORIZATION_TRANSFORMATION", "0", "{{t,u},{v,w}}")):
            with self.subTest(code=code):
                entry = self.package('Clear[Libra`FactorDependence]; Libra`FactorDependence[___] := '
                    f'Module[{{t=Unique["t"],u=Unique["u"],v=Unique["v"],w=Unique["w"]}},'
                    f'{{{{{equation}}},{template},' + ('{t,u}' if code.startswith('LINEAR') else '{t,u,v,w}') + '}];')
                self.exhausted(self.provider(entry=entry), code)

    def test_provider_flag_cannot_replace_independent_gauge_check(self) -> None:
        entry = self.package('Clear[Libra`Transform]; Libra`Transform[ds_,t_,___] := '
            '(Do[ds[v]=2*ds[v],{v,ds["variables"]}];Null);')
        run = self.provider(entry=entry)
        self.assertEqual(run[0]["code"], "CANDIDATE_TRANSFORMATION")
        checked = self.check(run, FIXTURES / "fuchsian-cut.wl")
        self.assertEqual(checked[0]["status"], "FAIL")

    @unittest.skipUnless(REAL_ENTRY, "set CANON_TEST_LIBRA_ENTRY for real multivariable Libra")
    def test_real_mixed_poles_and_epsilon_singular_nilpotent_core(self) -> None:
        for name, basis in (("mixed-cut.wl", "sector-basis.wl"), ("nilpotent-cut.wl", "nilpotent-basis.wl")):
            with self.subTest(name=name):
                cut = FIXTURES / name
                run = self.provider(cut=cut, basis=FIXTURES / basis, entry=Path(REAL_ENTRY))
                self.assertEqual(run[0]["code"], "CANDIDATE_TRANSFORMATION")
                self.assertTrue(all(run[0]["summary"]["multivariable"]["directional_fuchsian"]))
                self.assertEqual(self.check(run, cut, FIXTURES / basis)[0]["code"], "CORE_PASS")

    @unittest.skipUnless(REAL_ENTRY, "set CANON_TEST_LIBRA_ENTRY for moving regulator poles")
    def test_real_moving_regulator_pole_is_not_accepted_as_epsilon_form(self) -> None:
        cut = self.wl("moving-pole-cut", (FIXTURES / "fuchsian-cut.wl").read_text().replace(
            'eps/x', 'eps/(x-eps)'))
        run = self.provider(cut=cut, entry=Path(REAL_ENTRY))
        self.assertEqual((run[0]["status"], run[0]["code"]), ("INCONCLUSIVE", "METHOD_EXHAUSTED"))
        self.assertFalse((run[1] / "core-candidates.wl").exists())

    @unittest.skipUnless(REAL_ENTRY, "set CANON_TEST_LIBRA_ENTRY for real joint hierarchy")
    def test_real_joint_hierarchy_and_shared_factor_pass_independent_check(self) -> None:
        cut = FIXTURES / "mixed-cut.wl"
        run = self.provider(cut=cut, entry=Path(REAL_ENTRY), hierarchy=self.hierarchy(),
            options={"dependent_row_strategy": "sector-de-closure"})
        self.assertEqual(run[0]["summary"]["dependent_rows"]["combined_mask"], [[1, 1], [0, 1]])
        self.assertEqual(self.check(run, cut)[0]["code"], "CORE_PASS")

    @unittest.skipUnless(REAL_ENTRY, "set CANON_TEST_LIBRA_ENTRY for the real full workflow")
    def test_real_coupled_directions_complete_existing_workflow(self) -> None:
        cut = FIXTURES / "coupled-cut.wl"
        provider = self.provider(cut=cut, entry=Path(REAL_ENTRY), sequence=[1, 2], via_cli=True)
        self.assertEqual(provider[0]["code"], "CANDIDATE_TRANSFORMATION")
        core = self.check(provider, cut)
        self.assertEqual(core[0]["code"], "CORE_PASS")
        ordered = self.wl("ordered", cut.read_text().replace('canon-neu/sector-cut-de/v1', 'canon-neu/ordered-master-de/v1'))
        full = self.invoke("BUILD_FULL_DE", {"ordered_master_de": self.ref(ordered), "sector_cut_de": self.ref(cut),
            "core_candidates": self.artifact(provider, "core_candidates"), "core_transform": self.artifact(core, "core_transform"),
            "declared_alphabet": None, "accepted_prefix": None})
        tail = self.invoke("SOLVE_TAIL", {"full_sector_de": self.artifact(full, "full_sector_de"),
            "core_transform": self.artifact(core, "core_transform")})
        canonical = self.invoke("CHECK_CANONICAL", {"full_sector_de": self.artifact(full, "full_sector_de"),
            "sector_transform": self.artifact(tail, "sector_transform")})
        self.assertEqual(canonical[0]["status"], "PASS")
        committed = self.invoke("COMMIT_SECTOR", {"previous_accepted_prefix": None,
            "sector_basis": self.ref(FIXTURES / "sector-basis.wl"),
            "sector_transform": self.artifact(tail, "sector_transform"),
            "canonical_sector_de": self.artifact(canonical, "canonical_sector_de")})
        prepared = self.wl("prepared", '<|"family_ref"->"fixture-libra-multivariable","basis_ref"->"raw/6","variables"->{x,y},"regulator"->eps|>')
        masters = self.wl("masters", '<|"family_ref"->"fixture-libra-multivariable","basis_ref"->"raw/6","masters"->{j1,j2}|>')
        manifest = self.wl("manifest", '<|"sectors"->{<|"id"->6,"propagator_count"->2|>}|>')
        final = self.invoke("FINAL_CHECK", {"prepared_family": self.ref(prepared), "master_basis": self.ref(masters),
            "sector_manifest": self.ref(manifest), "ordered_master_de": self.ref(ordered),
            "accepted_prefix": self.artifact(committed, "accepted_prefix")})
        self.assertEqual((final[0]["status"], final[0]["code"]), ("PASS", "ALL_PASS"))


if __name__ == "__main__":
    unittest.main()
