from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests" / "fixtures" / "method_cards"
KERNEL = Path(
    os.environ.get("CANON_WOLFRAM_KERNEL") or shutil.which("WolframKernel") or "WolframKernel"
).expanduser().resolve()
KERNEL_LAUNCHER = ROOT / "tests" / "wolfram_kernel_launcher.py"


def optional_entry(name: str) -> Path | None:
    value = os.environ.get(name)
    return Path(value).resolve() if value else None


CANONICA_ENTRY = optional_entry("CANON_TEST_CANONICA_ENTRY")
LIBRA_ENTRY = optional_entry("CANON_TEST_LIBRA_ENTRY")
INITIAL_TEST_CONFIG = optional_entry("CANON_TEST_INITIAL_CONFIG")
INITIAL_COMPONENT_KEYS = (
    "package_entry", "finite_flow_package_file", "finite_flow_library", "reference_directory"
)
STRUCTURED_OUTPUT_ROOT = optional_entry("CANON_TEST_STRUCTURED_OUTPUT_ROOT")
DLOGBASIS_REFINE_ENTRY = optional_entry("CANON_TEST_DLOGBASIS_REFINE_ENTRY")
FINITEFLOW_ENTRY = optional_entry("CANON_TEST_FINITEFLOW_ENTRY")
FIXTURE_LIBRA_ENTRY = FIXTURES / "structured-repair-tool.m"
FIXTURE_LIBRA_SHA256 = hashlib.sha256(FIXTURE_LIBRA_ENTRY.read_bytes()).hexdigest()
FIXTURE_ENTRY_EXPRESSION = 'Environment["CANON_TEST_FIXTURE_LIBRA_ENTRY"]'
FIXTURE_HASH_EXPRESSION = f'FileHash[{FIXTURE_ENTRY_EXPRESSION}, "SHA256", "HexString"]'


@unittest.skipUnless(
    KERNEL.is_file(),
    "requires a WolframKernel; external method packages are injected per provider test",
)
class MethodCardIntegrationTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.run_root = Path(self.temporary.name)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def run_wls(
        self,
        script: Path,
        input_path: Path,
        output_dir: Path,
        expected_returncode: int = 0,
        timeout: int = 60,
    ) -> dict:
        environment = os.environ.copy()
        environment["CANON_TEST_FIXTURE_LIBRA_ENTRY"] = str(FIXTURE_LIBRA_ENTRY)
        environment["OMP_NUM_THREADS"] = "1"
        environment["MKL_NUM_THREADS"] = "1"
        environment["NUMEXPR_NUM_THREADS"] = "1"
        environment["OPENBLAS_NUM_THREADS"] = "1"
        environment["USE_OPENMP"] = "1"
        environment["VECLIB_MAXIMUM_THREADS"] = "1"
        completed = subprocess.run(
            [
                sys.executable,
                str(KERNEL_LAUNCHER),
                str(KERNEL),
                "-noinit",
                "-noprompt",
                "-script",
                str(script),
                str(input_path),
                str(output_dir),
            ],
            cwd=ROOT,
            env=environment,
            text=True,
            capture_output=True,
            timeout=timeout,
        )
        # WolframKernel's OpenMP runtime can release its shared-memory object
        # slightly after process exit. Keep sequential test invocations from
        # racing that cleanup; this does not retry or mask a failed run.
        time.sleep(2.0)
        result_path = output_dir / "result.json"
        result_debug = (
            result_path.read_text(encoding="utf-8")
            if result_path.is_file()
            else "<result.json was not written>"
        )
        self.assertEqual(
            completed.returncode,
            expected_returncode,
            f"stdout:\n{completed.stdout}\nstderr:\n{completed.stderr}"
            f"\nresult.json:\n{result_debug}",
        )
        self.assertTrue(result_path.is_file(), completed.stdout)
        return json.loads(result_path.read_text(encoding="utf-8"))

    def check_input(
        self,
        task_id: str,
        candidate_path: Path,
        *,
        sector: dict[str, int] | None = None,
        sector_basis: Path | None = None,
        sector_cut_de: Path | None = None,
    ) -> Path:
        sector = sector or {"id": 3, "propagator_count": 2}
        sector_basis = sector_basis or FIXTURES / "sector-basis.wl"
        sector_cut_de = sector_cut_de or FIXTURES / "sector-cut-de.wl"
        value = {
            "schema": "canon-neu/script-input/v1",
            "task_id": task_id,
            "step": "CHECK_CORE",
            "sector": sector,
            "payload": {
                "sector_basis": {
                    "type": "mathematica-expression",
                    "path": str(sector_basis),
                },
                "sector_cut_de": {
                    "type": "mathematica-expression",
                    "path": str(sector_cut_de),
                },
                "core_candidates": {
                    "type": "mathematica-expression",
                    "path": str(candidate_path),
                },
            },
        }
        path = self.run_root / f"{task_id}.json"
        path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
        return path

    def provider_input(
        self,
        method: str,
        package_entry: Path | None = None,
        *,
        relative_entry: bool = True,
        method_options: dict | None = None,
        sector_basis: Path | None = None,
        sector_cut_de: Path | None = None,
        dependent_row_hierarchy: Path | None = None,
    ) -> Path:
        value = json.loads(
            (FIXTURES / f"search-input-{method}.json").read_text(encoding="utf-8")
        )
        for artifact_name in (
            "prepared_family",
            "sector_basis",
            "sector_cut_de",
        ):
            descriptor = value["payload"][artifact_name]
            descriptor["path"] = str((FIXTURES / descriptor["path"]).resolve())
        if sector_basis is not None:
            value["payload"]["sector_basis"]["path"] = str(
                sector_basis.resolve()
            )
        if sector_cut_de is not None:
            value["payload"]["sector_cut_de"]["path"] = str(
                sector_cut_de.resolve()
            )
        if dependent_row_hierarchy is not None:
            value["payload"]["dependent_row_hierarchy"] = {
                "type": "mathematica-expression",
                "path": str(dependent_row_hierarchy.resolve()),
            }
        if method_options is not None:
            value["payload"]["method_options"] = method_options
        else:
            assert package_entry is not None
            entry_value = (
                os.path.relpath(package_entry, self.run_root)
                if relative_entry
                else str(package_entry)
            )
            value["payload"]["method_options"] = {
                "package_entry": entry_value
            }
        path = self.run_root / f"search-input-{method}.json"
        path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
        return path

    def route_input(
        self,
        task_id: str,
        replacements: tuple[tuple[str, str], ...] = (),
    ) -> Path:
        artifact_text = (FIXTURES / "prepared-basis-refine.wl").read_text(
            encoding="utf-8"
        )
        for old, new in replacements:
            self.assertIn(old, artifact_text)
            artifact_text = artifact_text.replace(old, new)
        artifact_path = self.run_root / f"{task_id}-prepared-basis.wl"
        artifact_path.write_text(artifact_text, encoding="utf-8")
        value = {
            "schema": "canon-neu/script-input/v1",
            "task_id": task_id,
            "step": "ROUTE_PREPARED_BASIS",
            "payload": {
                "prepared_basis": {
                    "type": "mathematica-expression",
                    "path": str(artifact_path),
                }
            },
        }
        input_path = self.run_root / f"{task_id}.json"
        input_path.write_text(
            json.dumps(value, indent=2) + "\n", encoding="utf-8"
        )
        return input_path

    def assert_prepared_basis_invalid(
        self,
        task_id: str,
        replacements: tuple[tuple[str, str], ...],
        expected_field: str,
    ) -> None:
        output = self.run_root / f"{task_id}-output"
        result = self.run_wls(
            ROOT / "methods" / "route-prepared-basis" / "run.wls",
            self.route_input(task_id, replacements),
            output,
            expected_returncode=1,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("ERROR", "INVALID_PREPARED_BASIS"),
        )
        self.assertEqual(result["summary"]["field"], expected_field)

    def fake_libra_entry(self) -> Path:
        path = self.run_root / "FakeLibra.m"
        path.write_text(
            """BeginPackage[\"Libra`\"];
$LibraVersion = \"1.2\";
NewDSystem[___] := Null;
Fuchsify[___] := $Failed;
Transform[___] := Null;
FactorOut[___] := $Failed;
OverallTransformation[___] := $Failed;
EFormQ[___] := False;
TClosure[m_] := m;
LeadingSeriesCoefficient[___] := $Failed;
PolesInfo[___] := {};
EndPackage[];
""",
            encoding="utf-8",
        )
        return path

    def successful_fake_libra_entry(self, capture_path: Path) -> Path:
        path = self.run_root / f"SuccessfulFakeLibra-{capture_path.stem}.m"
        capture = str(capture_path).replace("\\", "\\\\").replace('"', '\\"')
        path.write_text(
            f'''BeginPackage["Libra`"];
$LibraVersion = "1.2";
$LibraUseFermat = False;
DependentRowIndices;
SetAttributes[NewDSystem, HoldFirst];
NewDSystem[ds_Symbol, rule_Rule] := (
  ds[Global`x] = Last[rule];
  ds["overall"] = IdentityMatrix[Length[Last[rule]]];
  Null
);
Fuchsify[ds_Symbol, Global`x] := IdentityMatrix[Length[ds[Global`x]]];
Transform[ds_Symbol, transformation_] := (
  ds[Global`x] = Together[
    Inverse[transformation].(
      ds[Global`x].transformation - D[transformation, Global`x]
    )
  ];
  ds["overall"] = Together[ds["overall"].transformation];
  Null
);
Options[FactorOut] = {{DependentRowIndices -> Automatic}};
FactorOut[ds_Symbol, Global`x, Global`eps, 1/2, OptionsPattern[]] := (
  Put[OptionValue[DependentRowIndices], "{capture}"];
  {{{{1, Global`x}}, {{0, 1}}}}
);
PolesInfo[___] := {{{{0, 0}}}};
LeadingSeriesCoefficient[___] := IdentityMatrix[2];
TClosure[m_?MatrixQ] := FixedPoint[
  Map[Boole[# =!= 0] &, # + #.#, {{2}}] &,
  m
];
OverallTransformation[ds_Symbol][_] := ds["overall"];
EFormQ[m_, fakeRegulator_] := FreeQ[Together[m/fakeRegulator], fakeRegulator];
EndPackage[];
''',
            encoding="utf-8",
        )
        return path

    def fake_canonica_entry(self) -> Path:
        path = self.run_root / "FakeCANONICA.m"
        path.write_text(
            """BeginPackage[\"CANONICA`\"];
SectorBoundariesFromDE[___] := {1};
RecursivelyTransformSectors[___] := $Failed;
ExtractIrreducibles[___] := {};
CheckEpsForm[___] := False;
CheckIntegrability[___] := True;
EndPackage[];
""",
            encoding="utf-8",
        )
        return path

    def search_preflight_package(
        self,
        method: str,
        load_marker: Path,
        scientific_call_marker: Path,
    ) -> Path:
        path = self.run_root / (
            "PreflightSentinelLibra.m"
            if method == "libra"
            else "PreflightCountingCANONICA.m"
        )
        load_path = json.dumps(str(load_marker))
        call_path = json.dumps(str(scientific_call_marker))
        if method == "libra":
            source = f'Put["LOADED", {load_path}]; Abort[];\n'
        else:
            source = f'''BeginPackage["CANONICA`"];\nPut["LOADED", {load_path}];
SectorBoundariesFromDE[___] := (Put["SectorBoundariesFromDE", {call_path}]; {{1}});
RecursivelyTransformSectors[___] := (Put["RecursivelyTransformSectors", {call_path}]; $Failed);
ExtractIrreducibles[___] := {{}};
CheckEpsForm[___] := False;
CheckIntegrability[___] := (Put["CheckIntegrability", {call_path}]; True);
EndPackage[];
'''
        path.write_text(source, encoding="utf-8")
        return path

    def tail_screen_input(
        self,
        task_id: str,
        full_prefix_candidates: Path,
        candidate_budget: int,
    ) -> Path:
        value = {
            "schema": "canon-neu/script-input/v1",
            "task_id": task_id,
            "step": "SCREEN_TAIL",
            "sector": {"id": 5, "propagator_count": 2},
            "payload": {
                "sector_basis": {
                    "type": "mathematica-expression",
                    "path": str(FIXTURES / "tail-sector-basis.wl"),
                },
                "sector_cut_de": {
                    "type": "mathematica-expression",
                    "path": str(FIXTURES / "tail-sector-cut-de.wl"),
                },
                "core_candidates": {
                    "type": "mathematica-expression",
                    "path": str(FIXTURES / "tail-core-candidates.wl"),
                },
                "accepted_prefix": {
                    "type": "mathematica-expression",
                    "path": str(FIXTURES / "tail-accepted-prefix.wl"),
                },
                "full_prefix_candidates": {
                    "type": "mathematica-expression",
                    "path": str(full_prefix_candidates),
                },
                "screen_options": {"candidate_budget": candidate_budget},
            },
        }
        path = self.run_root / f"{task_id}.json"
        path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
        return path

    def mutated_wl(
        self,
        source: Path,
        name: str,
        replacements: tuple[tuple[str, str], ...],
    ) -> Path:
        text = source.read_text(encoding="utf-8")
        for old, new in replacements:
            self.assertIn(old, text)
            text = text.replace(old, new)
        path = self.run_root / f"{name}.wl"
        path.write_text(text, encoding="utf-8")
        return path

    def structured_repair_provider_input(
        self,
        task_id: str,
        *,
        prepared_basis: Path | None = None,
        route_decision: Path | None = None,
        repair_request: Path | None = None,
        package_entry: Path | None = None,
    ) -> Path:
        value = {
            "schema": "canon-neu/script-input/v1",
            "task_id": task_id,
            "step": "REPAIR_WITH_LIBRA",
            "payload": {
                "prepared_basis": {
                    "type": "mathematica-expression",
                    "path": str(
                        prepared_basis
                        or FIXTURES / "structured-repair-prepared-basis.wl"
                    ),
                },
                "route_decision": {
                    "type": "mathematica-expression",
                    "path": str(
                        route_decision
                        or FIXTURES / "structured-repair-route-decision.wl"
                    ),
                },
                "repair_request": {
                    "type": "mathematica-expression",
                    "path": str(
                        repair_request
                        or FIXTURES / "structured-repair-input.wl"
                    ),
                },
                "method_options": {
                    "package_entry": str(
                        package_entry or self.run_root / "must-not-load-Libra.m"
                    )
                },
            },
        }
        path = self.run_root / f"{task_id}.json"
        path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
        return path

    def structured_repair_checker_input(
        self,
        task_id: str,
        repair_candidate: Path,
        *,
        prepared_basis: Path | None = None,
        route_decision: Path | None = None,
        repair_request: Path | None = None,
        checker_entry: Path = FIXTURE_LIBRA_ENTRY,
        checker_sha256: str = FIXTURE_LIBRA_SHA256,
    ) -> Path:
        expected_tool_identity = self.libra_tool_identity(repair_candidate)
        value = {
            "schema": "canon-neu/script-input/v1",
            "task_id": task_id,
            "step": "CHECK_STRUCTURED_REPAIR",
            "payload": {
                "prepared_basis": {
                    "type": "mathematica-expression",
                    "path": str(
                        prepared_basis
                        or FIXTURES / "structured-repair-prepared-basis.wl"
                    ),
                },
                "route_decision": {
                    "type": "mathematica-expression",
                    "path": str(
                        route_decision
                        or FIXTURES / "structured-repair-route-decision.wl"
                    ),
                },
                "repair_request": {
                    "type": "mathematica-expression",
                    "path": str(
                        repair_request
                        or FIXTURES / "structured-repair-input.wl"
                    ),
                },
                "repair_candidate": {
                    "type": "mathematica-expression",
                    "path": str(repair_candidate),
                },
                "checker_options": {
                    "package_entry": str(checker_entry),
                    "expected_tool_identity": expected_tool_identity,
                    "expected_entry_sha256": checker_sha256,
                },
            },
        }
        path = self.run_root / f"{task_id}.json"
        path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
        return path

    def libra_tool_identity(self, candidate: Path) -> str:
        match = re.search(
            r'"tool_identity"\s*->\s*"([^"]+)"',
            candidate.read_text(encoding="utf-8"),
        )
        if match is None:
            self.fail(f"Libra candidate does not record tool_identity: {candidate}")
        return match.group(1)

    def initial_candidate(self) -> dict:
        value = json.loads(
            (FIXTURES / "initial-evidence-input.json").read_text(encoding="utf-8")
        )
        return value["payload"]["candidate"]

    def initial_provider_input(
        self,
        task_id: str,
        *,
        components: dict | None = None,
        candidate_updates: dict | None = None,
        identity_updates: dict | None = None,
    ) -> Path:
        value = json.loads(
            (FIXTURES / "initial-evidence-input.json").read_text(encoding="utf-8")
        )
        value["task_id"] = task_id
        if candidate_updates:
            value["payload"]["candidate"].update(candidate_updates)
        options = {}
        if components is not None:
            options = {
                "initial_identity": (
                    "INITIAL 2.1; 63d8f813ac415f82f7ef945ee7e3f78a242fae49"
                ),
                "finiteflow_identity": (
                    "FiniteFlow; 278344c169010b74e791af8c5604c8cb9cd8df11"
                ),
                **components,
            }
        if identity_updates:
            options.update(identity_updates)
        value["payload"]["method_options"] = options
        path = self.run_root / f"{task_id}.json"
        path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
        return path

    def initial_checker_input(
        self,
        task_id: str,
        provider_task_id: str,
        evidence_path: Path,
        components: dict,
    ) -> Path:
        value = {
            "schema": "canon-neu/script-input/v1",
            "task_id": task_id,
            "step": "CHECK_UT_EVIDENCE",
            "payload": {
                "candidate": self.initial_candidate(),
                "provider_task_id": provider_task_id,
                "ut_evidence": {
                    "type": "mathematica-expression",
                    "path": str(evidence_path),
                },
                "checker_options": components,
            },
        }
        path = self.run_root / f"{task_id}.json"
        path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
        return path

    def assert_provider_closes_exact_core_loop(
        self,
        method: str,
        package_entry: Path,
        expected_transformation_fragment: str,
        *,
        relative_entry: bool,
    ) -> Path:
        provider_output = self.run_root / f"{method}-provider"
        provider_result = self.run_wls(
            ROOT / "methods" / method / "run.wls",
            self.provider_input(
                method, package_entry, relative_entry=relative_entry
            ),
            provider_output,
        )
        self.assertEqual(
            (provider_result["status"], provider_result["code"]),
            ("PROVISIONAL", "CANDIDATE_TRANSFORMATION"),
        )
        self.assertNotIn(provider_result["status"], {"PASS", "FAIL"})
        candidate_path = provider_output / provider_result["artifacts"][
            "core_candidates"
        ]["path"]
        candidate_text = " ".join(
            candidate_path.read_text(encoding="utf-8").split()
        )
        self.assertIn(expected_transformation_fragment, candidate_text)

        check_output = self.run_root / f"{method}-check"
        check_result = self.run_wls(
            ROOT / "mma" / "CheckSectorCore.wls",
            self.check_input(f"T-CHECK-{method.upper()}", candidate_path),
            check_output,
        )
        self.assertEqual(
            (check_result["status"], check_result["code"]),
            ("PASS", "CORE_PASS"),
        )
        summary = check_result["summary"]
        self.assertEqual(summary["candidate_index"], 1)
        self.assertEqual(len(summary["attempted_candidate_ids"]), 1)
        self.assertFalse(summary["repair_eligible"])
        for field in (
            "invertible", "exact_gauge", "flat_connection", "epsilon_factorized"
        ):
            self.assertTrue(summary["attempts"][0][field], field)
        return candidate_path

    def test_prepared_basis_router_covers_every_decision_branch(self) -> None:
        localized_absent = (
            '"present" -> True,\n'
            '      "block" -> "lower-to-current",\n'
            '      "signature" -> <|"kind" -> "epsilon-factorization", '
            '"row" -> 1, "column" -> 2|>',
            '"present" -> False,\n'
            '      "block" -> Null,\n'
            '      "signature" -> <||>',
        )
        common_complete = (
            ('"pool_exhausted" -> False', '"pool_exhausted" -> True'),
            ('"alternatives_remaining" -> 1', '"alternatives_remaining" -> 0'),
            (
                '"attempted_candidate_ids" -> {"fixture-candidate-a"}',
                '"attempted_candidate_ids" -> {"fixture-candidate-a", "fixture-candidate-b"}',
            ),
            (
                '"candidate_selection_complete" -> False',
                '"candidate_selection_complete" -> True',
            ),
        )
        cases = {
            "verify": (
                (
                    ('"suspicious" -> True', '"suspicious" -> False'),
                    ('"off_diagonal" -> "DEFECT"', '"off_diagonal" -> "CANONICAL"'),
                    localized_absent,
                    *common_complete,
                    (
                        '"classification" -> "LOCALIZED_RATIONAL_DEFECT"',
                        '"classification" -> "NONE"',
                    ),
                    (
                        '"rational_transformation_expected" -> True',
                        '"rational_transformation_expected" -> False',
                    ),
                ),
                "VERIFY_CANONICAL_DE",
            ),
            "refine": ((), "REFINE_SECTOR_UT_CANDIDATES"),
            "plateau-refine": (
                (( '"plateau" -> False', '"plateau" -> True'),),
                "REFINE_SECTOR_UT_CANDIDATES",
            ),
            "tail": (
                common_complete,
                "SOLVE_TAIL",
            ),
            "canonica-before-pool-exhaustion": (
                (localized_absent,
                 ('"suspicious" -> True', '"suspicious" -> False'),
                 ('"classification" -> "LOCALIZED_RATIONAL_DEFECT"',
                  '"classification" -> "GLOBAL_RATIONAL_DEFECT"')),
                "FIND_RATIONAL_CANONICAL_WITH_CANONICA",
            ),
            "canonica": (
                (
                    ('"suspicious" -> True', '"suspicious" -> False'),
                    localized_absent,
                    *common_complete,
                    (
                        '"classification" -> "LOCALIZED_RATIONAL_DEFECT"',
                        '"classification" -> "GLOBAL_RATIONAL_DEFECT"',
                    ),
                ),
                "FIND_RATIONAL_CANONICAL_WITH_CANONICA",
            ),
            "diagnose": (
                (
                    ('"suspicious" -> True', '"suspicious" -> False'),
                    localized_absent,
                    *common_complete,
                    (
                        '"classification" -> "LOCALIZED_RATIONAL_DEFECT"',
                        '"classification" -> "UNKNOWN_OR_NONRATIONAL"',
                    ),
                    (
                        '"rational_transformation_expected" -> True',
                        '"rational_transformation_expected" -> False',
                    ),
                ),
                "DIAGNOSE_OR_CHANGE_VARIABLES",
            ),
        }
        for name, (replacements, expected_decision) in cases.items():
            with self.subTest(name=name):
                output = self.run_root / f"route-{name}"
                result = self.run_wls(
                    ROOT / "methods" / "route-prepared-basis" / "run.wls",
                    self.route_input(f"T-ROUTE-{name.upper()}", replacements),
                    output,
                )
                self.assertEqual(
                    (result["status"], result["code"]),
                    ("PROVISIONAL", "ROUTE_DECISION"),
                )
                self.assertEqual(result["summary"]["decision"], expected_decision)
                if name == "repair":
                    self.assertEqual(
                        result["summary"]["reason"],
                        "LOCALIZED_POOL_EXHAUSTED",
                    )
                self.assertFalse(
                    result["summary"]["initial_evidence_controls_route"]
                )
                artifact = output / result["artifacts"]["route_decision"]["path"]
                self.assertIn(
                    f'"decision" -> "{expected_decision}"',
                    artifact.read_text(encoding="utf-8"),
                )

    def test_initial_evidence_changes_do_not_control_prepared_basis_route(self) -> None:
        decisions = []
        for name, replacements in (
            ("original", ()),
            (
                "changed",
                (
                    (
                        '"verification_status" -> "AWAITING_INDEPENDENT_VERIFICATION"',
                        '"verification_status" -> "REPLACED_INITIAL_EVIDENCE"',
                    ),
                ),
            ),
        ):
            output = self.run_root / f"route-initial-{name}"
            result = self.run_wls(
                ROOT / "methods" / "route-prepared-basis" / "run.wls",
                self.route_input(f"T-ROUTE-INITIAL-{name.upper()}", replacements),
                output,
            )
            decisions.append((result["status"], result["summary"]["decision"]))
        self.assertEqual(
            decisions,
            [
                ("PROVISIONAL", "REFINE_SECTOR_UT_CANDIDATES"),
                ("PROVISIONAL", "REFINE_SECTOR_UT_CANDIDATES"),
            ],
        )

    def test_prepared_basis_rejects_malformed_and_contradictory_inputs(self) -> None:
        cases = {
            "malformed": (
                (
                    '      "normalization" -> "leading-singularity-normalized",\n',
                    "",
                ),
                "candidates",
            ),
            "contradictory": (
                ('"pool_exhausted" -> False', '"pool_exhausted" -> True'),
                "search_history",
            ),
        }
        for name, (replacement, expected_field) in cases.items():
            with self.subTest(name=name):
                summaries = []
                for repeat in range(2):
                    output = self.run_root / f"route-{name}-{repeat}"
                    result = self.run_wls(
                        ROOT / "methods" / "route-prepared-basis" / "run.wls",
                        self.route_input(
                            f"T-ROUTE-{name.upper()}-{repeat}", (replacement,)
                        ),
                        output,
                        expected_returncode=1,
                    )
                    self.assertEqual(
                        (result["status"], result["code"]),
                        ("ERROR", "INVALID_PREPARED_BASIS"),
                    )
                    summaries.append(result["summary"])
                self.assertEqual(summaries[0], summaries[1])
                self.assertEqual(summaries[0]["field"], expected_field)

    def test_prepared_basis_rejects_canonical_selected_suspicious(self) -> None:
        localized_absent = (
            '"present" -> True,\n'
            '      "block" -> "lower-to-current",\n'
            '      "signature" -> <|"kind" -> "epsilon-factorization", '
            '"row" -> 1, "column" -> 2|>',
            '"present" -> False,\n'
            '      "block" -> Null,\n'
            '      "signature" -> <||>',
        )
        self.assert_prepared_basis_invalid(
            "T-ROUTE-REJECT-CANONICAL-SUSPICIOUS",
            (
                ('"off_diagonal" -> "DEFECT"', '"off_diagonal" -> "CANONICAL"'),
                localized_absent,
                ('"pool_exhausted" -> False', '"pool_exhausted" -> True'),
                ('"alternatives_remaining" -> 1', '"alternatives_remaining" -> 0'),
                (
                    '"attempted_candidate_ids" -> {"fixture-candidate-a"}',
                    '"attempted_candidate_ids" -> {"fixture-candidate-a", "fixture-candidate-b"}',
                ),
                (
                    '"classification" -> "LOCALIZED_RATIONAL_DEFECT"',
                    '"classification" -> "NONE"',
                ),
                (
                    '"candidate_selection_complete" -> False',
                    '"candidate_selection_complete" -> True',
                ),
                (
                    '"rational_transformation_expected" -> True',
                    '"rational_transformation_expected" -> False',
                ),
            ),
            "candidates.selected",
        )

    def test_prepared_basis_rejects_localized_rational_without_expectation(self) -> None:
        self.assert_prepared_basis_invalid(
            "T-ROUTE-REJECT-LOCALIZED-NONRATIONAL",
            (
                (
                    '"rational_transformation_expected" -> True',
                    '"rational_transformation_expected" -> False',
                ),
            ),
            "remaining_problem.rational_transformation_expected",
        )

    def test_prepared_basis_rejects_localized_without_defect_quality(self) -> None:
        self.assert_prepared_basis_invalid(
            "T-ROUTE-REJECT-LOCALIZED-NO-DEFECT-QUALITY",
            (('"off_diagonal" -> "DEFECT"', '"off_diagonal" -> "UNKNOWN"'),),
            "quality.localized_defect",
        )

    def test_prepared_basis_rejects_completed_pool_with_unattempted_candidate(self) -> None:
        self.assert_prepared_basis_invalid(
            "T-ROUTE-REJECT-UNATTEMPTED-CANDIDATE",
            (
                ('"pool_exhausted" -> False', '"pool_exhausted" -> True'),
                ('"alternatives_remaining" -> 1', '"alternatives_remaining" -> 0'),
                (
                    '"candidate_selection_complete" -> False',
                    '"candidate_selection_complete" -> True',
                ),
            ),
            "search_history.alternatives_remaining",
        )

    def test_libra_multivariable_scope_is_inconclusive_without_tool_action(self) -> None:
        sector_basis = self.mutated_wl(
            FIXTURES / "sector-basis.wl",
            "flat-multivariable-sector-basis",
            (
                (( '"id" -> 3', '"id" -> 6')),
                (( '"family_id" -> "fixture-libra-tutorial-1"',
                   '"family_id" -> "fixture-flat-multivariable"')),
                (( '"basis_id" -> "fixture-sector-3-basis-v1"',
                   '"basis_id" -> "fixture-sector-6-basis-v1"')),
            ),
        )
        input_path = self.provider_input(
            "libra",
            self.run_root / "must-not-load-Libra.m",
            sector_basis=sector_basis,
            sector_cut_de=FIXTURES / "flat-multivariable-sector-cut-de.wl",
        )
        input_value = json.loads(input_path.read_text(encoding="utf-8"))
        input_value["sector"] = {"id": 6, "propagator_count": 2}
        input_path.write_text(
            json.dumps(input_value, indent=2) + "\n", encoding="utf-8"
        )
        output = self.run_root / "libra-multivariable-out-of-scope"
        result = self.run_wls(
            ROOT / "methods" / "libra" / "run.wls",
            input_path,
            output,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("INCONCLUSIVE", "OUT_OF_SCOPE"),
        )
        self.assertNotIn(result["status"], {"PASS", "FAIL"})

    def test_canonica_nonflat_system_is_input_error(self) -> None:
        output = self.run_root / "canonica-nonflat-input"
        result = self.run_wls(
            ROOT / "methods" / "canonica" / "run.wls",
            self.provider_input(
                "canonica",
                self.fake_canonica_entry(),
                sector_cut_de=FIXTURES / "nonflat-sector-cut-de.wl",
            ),
            output,
            expected_returncode=1,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("ERROR", "INVALID_DIFFERENTIAL_SYSTEM"),
        )

    def test_search_core_identity_preflight_order_and_exact_bindings(self) -> None:
        sector_basis = FIXTURES / "sector-basis.wl"
        cut = FIXTURES / "sector-cut-de.wl"
        cases = {
            "invalid-sector-basis": (
                self.mutated_wl(
                    sector_basis,
                    "invalid-search-sector-basis",
                    (("canon-neu/sector-basis/v1", "canon-neu/sector-basis/invalid"),),
                ),
                cut,
                None,
            ),
            "task-sector": (sector_basis, cut, {"id": 99, "propagator_count": 2}),
            "sector-basis-sector": (
                self.mutated_wl(
                    sector_basis,
                    "wrong-search-sector-basis-sector",
                    (( '"id" -> 3', '"id" -> 99'),),
                ),
                cut,
                None,
            ),
            "cut-sector": (
                sector_basis,
                self.mutated_wl(
                    cut,
                    "wrong-search-cut-sector",
                    (( '"id" -> 3', '"id" -> 99'),),
                ),
                None,
            ),
            "family": (
                self.mutated_wl(
                    sector_basis,
                    "wrong-search-family",
                    (( '"family_id" -> "fixture-libra-tutorial-1"',
                       '"family_id" -> "wrong-family"'),),
                ),
                cut,
                None,
            ),
            "basis-id": (
                self.mutated_wl(
                    sector_basis,
                    "wrong-search-basis-id",
                    (( '"basis_id" -> "fixture-sector-3-basis-v1"',
                       '"basis_id" -> "wrong-basis"'),),
                ),
                cut,
                None,
            ),
            "full-order": (
                self.mutated_wl(
                    sector_basis,
                    "wrong-search-full-order",
                    (( '"basis" -> {j1, j2}', '"basis" -> {j2, j1}'),),
                ),
                cut,
                None,
            ),
        }
        for method in ("libra", "canonica"):
            for name, (case_basis, case_cut, task_sector) in cases.items():
                with self.subTest(method=method, mismatch=name):
                    load_marker = self.run_root / f"{method}-{name}-loaded.wl"
                    call_marker = self.run_root / f"{method}-{name}-scientific-call.wl"
                    package = self.search_preflight_package(
                        method, load_marker, call_marker
                    )
                    input_path = self.provider_input(
                        method,
                        package,
                        relative_entry=False,
                        sector_basis=case_basis,
                        sector_cut_de=case_cut,
                    )
                    if task_sector is not None:
                        value = json.loads(input_path.read_text(encoding="utf-8"))
                        value["sector"] = task_sector
                        input_path.write_text(
                            json.dumps(value, indent=2) + "\n", encoding="utf-8"
                        )
                    result = self.run_wls(
                        ROOT / "methods" / method / "run.wls",
                        input_path,
                        self.run_root / f"{method}-{name}-preflight-output",
                        expected_returncode=1,
                    )
                    self.assertEqual(
                        (result["status"], result["code"]),
                        ("ERROR", "INVALID_DIFFERENTIAL_SYSTEM"),
                    )
                    if method == "libra":
                        self.assertFalse(load_marker.exists())
                    else:
                        self.assertTrue(load_marker.is_file())
                    self.assertFalse(call_marker.exists())

    def test_provider_method_exhaustion_is_inconclusive(self) -> None:
        for method, entry in (
            ("libra", self.fake_libra_entry()),
            ("canonica", self.fake_canonica_entry()),
        ):
            with self.subTest(method=method):
                output = self.run_root / f"{method}-method-exhausted"
                result = self.run_wls(
                    ROOT / "methods" / method / "run.wls",
                    self.provider_input(method, entry),
                    output,
                )
                self.assertEqual(
                    (result["status"], result["code"]),
                    ("INCONCLUSIVE", "METHOD_EXHAUSTED"),
                )
                self.assertNotIn(result["status"], {"PASS", "FAIL"})

    def test_libra_default_keeps_automatic_factorout_boundary(self) -> None:
        capture = self.run_root / "default-dependent-rows.wl"
        entry = self.successful_fake_libra_entry(capture)
        output = self.run_root / "libra-default-automatic"
        result = self.run_wls(
            ROOT / "methods" / "libra" / "run.wls",
            self.provider_input("libra", entry),
            output,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("PROVISIONAL", "CANDIDATE_TRANSFORMATION"),
        )
        self.assertEqual(capture.read_text(encoding="utf-8").strip(), "Automatic")
        self.assertEqual(
            result["summary"]["dependent_rows"]["dependent_row_strategy"],
            "automatic",
        )

    def test_libra_explicit_hierarchy_forwards_exact_full_mask(self) -> None:
        capture = self.run_root / "explicit-dependent-rows.wl"
        entry = self.successful_fake_libra_entry(capture)
        output = self.run_root / "libra-explicit-mask"
        result = self.run_wls(
            ROOT / "methods" / "libra" / "run.wls",
            self.provider_input(
                "libra",
                method_options={
                    "package_entry": str(entry),
                    "dependent_row_strategy": "sector-de-closure",
                },
                dependent_row_hierarchy=(
                    FIXTURES / "libra-dependent-row-hierarchy.wl"
                ),
            ),
            output,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("PROVISIONAL", "CANDIDATE_TRANSFORMATION"),
        )
        self.assertEqual(
            "".join(capture.read_text(encoding="utf-8").split()),
            "{{1,1},{1,1}}",
        )
        evidence = result["summary"]["dependent_rows"]
        self.assertEqual(
            (
                evidence["dependent_row_strategy"],
                evidence["hsector_nonzeros"],
                evidence["hde_nonzeros"],
                evidence["combined_mask_nonzeros"],
                evidence["max_mask_nonzeros"],
            ),
            ("sector-de-closure", 4, 2, 4, 4),
        )
        self.assertFalse(evidence["mapped_sectors"])

    def test_libra_explicit_hierarchy_rejects_invalid_contract_before_search(self) -> None:
        fixture = FIXTURES / "libra-dependent-row-hierarchy.wl"
        cases = {
            "identity": (( '"family_id" -> "fixture-libra-tutorial-1"',
                           '"family_id" -> "wrong-family"'),),
            "order": (( '"basis" -> {j1, j2}', '"basis" -> {j2, j1}'),),
            "shape": (( '"sector_hierarchy" -> {{1, 1}, {1, 1}}',
                        '"sector_hierarchy" -> {{1, 1}}'),),
            "nonbinary": (( '"sector_hierarchy" -> {{1, 1}, {1, 1}}',
                            '"sector_hierarchy" -> {{1, 2}, {1, 1}}'),),
            "diagonal": (( '"sector_hierarchy" -> {{1, 1}, {1, 1}}',
                           '"sector_hierarchy" -> {{0, 1}, {1, 1}}'),),
            "provenance": (( '"mapped_sectors" -> False',
                             '"mapped_sectors" -> True'),),
            "budget": (( '"max_mask_nonzeros" -> 4',
                         '"max_mask_nonzeros" -> 0'),),
        }
        for name, replacements in cases.items():
            with self.subTest(name=name):
                hierarchy = self.mutated_wl(
                    fixture, f"invalid-hierarchy-{name}", replacements
                )
                result = self.run_wls(
                    ROOT / "methods" / "libra" / "run.wls",
                    self.provider_input(
                        "libra",
                        method_options={
                            "package_entry": str(self.run_root / "must-not-load.m"),
                            "dependent_row_strategy": "sector-de-closure",
                        },
                        dependent_row_hierarchy=hierarchy,
                    ),
                    self.run_root / f"invalid-hierarchy-{name}-output",
                    expected_returncode=1,
                )
                self.assertEqual(
                    (result["status"], result["code"]),
                    ("ERROR", "INVALID_DIFFERENTIAL_SYSTEM"),
                )

    def test_libra_explicit_hierarchy_overflow_never_calls_factorout(self) -> None:
        hierarchy = self.mutated_wl(
            FIXTURES / "libra-dependent-row-hierarchy.wl",
            "overflow-hierarchy",
            (( '"max_mask_nonzeros" -> 4', '"max_mask_nonzeros" -> 3'),),
        )
        capture = self.run_root / "overflow-must-not-exist.wl"
        entry = self.successful_fake_libra_entry(capture)
        result = self.run_wls(
            ROOT / "methods" / "libra" / "run.wls",
            self.provider_input(
                "libra",
                method_options={
                    "package_entry": str(entry),
                    "dependent_row_strategy": "sector-de-closure",
                },
                dependent_row_hierarchy=hierarchy,
            ),
            self.run_root / "overflow-hierarchy-output",
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("INCONCLUSIVE", "METHOD_EXHAUSTED"),
        )
        self.assertFalse(capture.exists())
        self.assertEqual(
            result["summary"]["combined_mask_nonzeros"], 4
        )

    def test_libra_rejects_unknown_dependent_row_strategy_before_search(self) -> None:
        result = self.run_wls(
            ROOT / "methods" / "libra" / "run.wls",
            self.provider_input(
                "libra",
                method_options={
                    "package_entry": str(self.run_root / "must-not-load.m"),
                    "dependent_row_strategy": "retry-all",
                },
            ),
            self.run_root / "invalid-dependent-row-strategy",
            expected_returncode=1,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("ERROR", "INVALID_OPTIONS"),
        )

    @unittest.skipUnless(
        LIBRA_ENTRY is not None and LIBRA_ENTRY.is_file(),
        "set CANON_TEST_LIBRA_ENTRY to test Libra Automatic hierarchy parity",
    )
    def test_real_libra_post_residue_hierarchy_matches_automatic_semantics(self) -> None:
        assert LIBRA_ENTRY is not None
        script = self.run_root / "check-libra-hierarchy-parity.wls"
        result_path = self.run_root / "libra-hierarchy-parity.wl"
        script.write_text(
            '''$HistoryLength = 0;
position = FirstPosition[$CommandLine, "-script"];
args = Drop[$CommandLine, First[position] + 1];
{entry, cutPath, outputPath} = args;
cut = Get[cutPath];
Get[entry];
Libra`$LibraUseFermat = False;
x = First[cut["variables"]];
eps = cut["regulator"];
m = First[cut["matrices"]];
NewDSystem[ds, x -> m];
tf = Fuchsify[ds, x];
Transform[ds, tf];
post = ds[x];
residues = LeadingSeriesCoefficient[post/eps, {x, #1, 0}] & @@@ PolesInfo[post, x];
vectors = Transpose[residues, {3, 1, 2}];
derived = TClosure[Map[Boole[!MatchQ[#, {0 ..}]] &, vectors, {2}]];
automaticData = FactorDependence[
  residues, eps, 1/2,
  DependentRowIndices -> Automatic, Sort -> False, Solve -> False
];
automatic = Map[Boole[# =!= 0] &, automaticData[[2]], {2}];
Put[<|"equal" -> (derived === automatic), "derived" -> derived,
  "automatic" -> automatic|>, outputPath];
Quit[If[derived === automatic, 0, 1]];
''',
            encoding="utf-8",
        )
        environment = os.environ.copy()
        environment["OMP_NUM_THREADS"] = "1"
        completed = subprocess.run(
            [
                sys.executable,
                str(KERNEL_LAUNCHER),
                str(KERNEL),
                "-noinit",
                "-noprompt",
                "-script",
                str(script),
                str(LIBRA_ENTRY),
                str(FIXTURES / "sector-cut-de.wl"),
                str(result_path),
            ],
            cwd=ROOT,
            env=environment,
            text=True,
            capture_output=True,
            timeout=60,
        )
        self.assertEqual(
            completed.returncode,
            0,
            f"stdout:\n{completed.stdout}\nstderr:\n{completed.stderr}",
        )
        self.assertIn('"equal" -> True', result_path.read_text(encoding="utf-8"))

    @unittest.skipUnless(
        CANONICA_ENTRY is not None and CANONICA_ENTRY.is_file(),
        "set CANON_TEST_CANONICA_ENTRY to run the real CANONICA provider test",
    )
    def test_canonica_provider_and_independent_checker(self) -> None:
        assert CANONICA_ENTRY is not None
        self.assert_provider_closes_exact_core_loop(
            "canonica",
            CANONICA_ENTRY,
            '"transformation" -> {{1, x}, {0, 1}}',
            relative_entry=False,
        )

    @unittest.skipUnless(
        LIBRA_ENTRY is not None and LIBRA_ENTRY.is_file(),
        "set CANON_TEST_LIBRA_ENTRY to run the real Libra provider test",
    )
    def test_libra_provider_and_independent_checker(self) -> None:
        assert LIBRA_ENTRY is not None
        candidate = self.assert_provider_closes_exact_core_loop(
            "libra",
            LIBRA_ENTRY,
            '"transformation" -> {{1, x}, {0, 1}}',
            relative_entry=False,
        )
        self.assertEqual(self.libra_tool_identity(candidate), "1.23")

    @unittest.skipUnless(
        LIBRA_ENTRY is not None and LIBRA_ENTRY.is_file(),
        "set CANON_TEST_LIBRA_ENTRY to run the real structured-repair test",
    )
    def test_real_libra_structured_repair_and_independent_checker(self) -> None:
        assert LIBRA_ENTRY is not None
        structured_root = STRUCTURED_OUTPUT_ROOT or self.run_root
        provider_output = structured_root / "structured-real-provider"
        provider = self.run_wls(
            ROOT / "methods" / "libra-structured-repair" / "run.wls",
            self.structured_repair_provider_input(
                "T-STRUCTURED-REAL-PROVIDER", package_entry=LIBRA_ENTRY
            ),
            provider_output,
        )
        self.assertEqual(
            (provider["status"], provider["code"]),
            ("PROVISIONAL", "CANDIDATE_TRANSFORMATION"),
        )
        candidate = provider_output / provider["artifacts"]["repair_candidate"]["path"]
        candidate_text = " ".join(candidate.read_text(encoding="utf-8").split())
        provider_identity = self.libra_tool_identity(candidate)
        provider_sha256 = hashlib.sha256(LIBRA_ENTRY.read_bytes()).hexdigest()
        self.assertEqual(provider_identity, "1.23")
        self.assertIn(
            '"transformation" -> {{1, 0, 0}, {0, 1, x}, {0, 0, 1}}',
            candidate_text,
        )
        checker_output = structured_root / "structured-real-checker"
        checked = self.run_wls(
            ROOT / "mma" / "CheckStructuredRepair.wls",
            self.structured_repair_checker_input(
                "T-STRUCTURED-REAL-CHECKER", candidate,
                checker_entry=LIBRA_ENTRY,
                checker_sha256=provider_sha256,
            ),
            checker_output,
        )
        self.assertEqual(
            (checked["status"], checked["code"]),
            ("PASS", "VERIFIED_STRUCTURED_REPAIR"),
        )
        for field in (
            "identity_and_order",
            "authenticated_libra_provenance",
            "invertible",
            "frozen_prefix_identity",
            "forbidden_mixing_zero",
            "exact_full_gauge",
            "flat_connection",
            "epsilon_factorized",
            "no_residual_regulator_dependence",
            "declared_dlog_alphabet",
            "target_defect_eliminated",
            "accepted_blocks_nonregressed",
        ):
            self.assertTrue(checked["summary"][field], field)
        verified_path = checker_output / checked["artifacts"][
            "verified_structured_repair"
        ]["path"]
        verified_text = verified_path.read_text(encoding="utf-8")
        self.assertIn('"authenticated_provenance"', verified_text)
        self.assertIn(provider_identity, verified_text)
        self.assertIn(provider_sha256, verified_text)

    def test_structured_repair_contract_rejects_route_pool_and_prefix_contradictions(self) -> None:
        base_prepared = FIXTURES / "structured-repair-prepared-basis.wl"
        base_route = FIXTURES / "structured-repair-route-decision.wl"
        base_request = FIXTURES / "structured-repair-input.wl"
        pool_remaining_prepared = self.mutated_wl(
            base_prepared,
            "structured-pool-remaining-prepared",
            (
                ('"pool_exhausted" -> True', '"pool_exhausted" -> False'),
                ('"alternatives_remaining" -> 0', '"alternatives_remaining" -> 1'),
                (
                    '"fixture-structured-candidate-a", "fixture-structured-candidate-b"',
                    '"fixture-structured-candidate-a"',
                ),
            ),
        )
        pool_remaining_request = self.mutated_wl(
            base_request,
            "structured-pool-remaining-request",
            (
                ('"pool_exhausted" -> True', '"pool_exhausted" -> False'),
                ('"alternatives_remaining" -> 0', '"alternatives_remaining" -> 1'),
                (
                    '"fixture-structured-candidate-a", "fixture-structured-candidate-b"',
                    '"fixture-structured-candidate-a"',
                ),
            ),
        )
        cases = {
            "wrong-route": {
                "route_decision": self.mutated_wl(
                    base_route,
                    "structured-wrong-route",
                    (( '"REPAIR_WITH_LIBRA"', '"FIND_RATIONAL_CANONICAL_WITH_CANONICA"'),),
                ),
            },
            "pool-not-exhausted": {
                "prepared_basis": pool_remaining_prepared,
                "repair_request": pool_remaining_request,
            },
            "request-omits-attempted-candidate": {
                "repair_request": self.mutated_wl(
                    base_request,
                    "structured-unattempted-request",
                    ((
                        '"fixture-structured-candidate-a", "fixture-structured-candidate-b"',
                        '"fixture-structured-candidate-a"',
                    ),),
                ),
            },
            "prefix-order": {
                "repair_request": self.mutated_wl(
                    base_request,
                    "structured-wrong-prefix-order",
                    (( '"order" -> {1}', '"order" -> {2}'),),
                ),
            },
            "prefix-identity": {
                "repair_request": self.mutated_wl(
                    base_request,
                    "structured-wrong-prefix-id",
                    (( '"fixture-libra-accepted-prefix-v1"', '"wrong-prefix-id"'),),
                ),
            },
            "selected-candidate-identity": {
                "repair_request": self.mutated_wl(
                    base_request,
                    "structured-wrong-selected-candidate",
                    (( '"selected_candidate_id" -> "fixture-structured-candidate-a"',
                       '"selected_candidate_id" -> "fixture-structured-candidate-b"'),),
                ),
            },
            "coefficient-domain": {
                "repair_request": self.mutated_wl(
                    base_request,
                    "structured-wrong-domain",
                    (( '"coefficient_domain" -> "exact-rational-functions"',
                       '"coefficient_domain" -> "machine-real"'),),
                ),
            },
            "convention": {
                "repair_request": self.mutated_wl(
                    base_request,
                    "structured-wrong-convention",
                    (( '"old_basis = transformation . new_basis"',
                       '"new_basis = transformation . old_basis"'),),
                ),
            },
            "block-dimension": {
                "repair_request": self.mutated_wl(
                    base_request,
                    "structured-wrong-prefix-dimension",
                    (( '"dimension" -> 1', '"dimension" -> 2'),),
                ),
            },
        }
        for name, updates in cases.items():
            with self.subTest(name=name):
                output = self.run_root / f"structured-contract-{name}"
                result = self.run_wls(
                    ROOT / "methods" / "libra-structured-repair" / "run.wls",
                    self.structured_repair_provider_input(
                        f"T-STRUCTURED-CONTRACT-{name.upper()}", **updates
                    ),
                    output,
                    expected_returncode=1,
                )
                self.assertEqual(
                    (result["status"], result["code"]),
                    ("ERROR", "INVALID_REPAIR_INPUT"),
                )

    def test_structured_repair_preflight_enforces_mapping_direct_sum_and_parameters(self) -> None:
        base_request = FIXTURES / "structured-repair-input.wl"
        cases = {
            "mismapped-target": (
                (( '"full_entry" -> {2, 3}', '"full_entry" -> {3, 2}'),),
                "INVALID_REPAIR_INPUT",
                "localized_target.full_entry",
            ),
            "undeclared-symbol": (
                ((
                    '1 - eps + eps/(1 - x) - x eps/(1 + x)',
                    '1 - eps + eps/(1 - x) - x eps/(1 + x) + z',
                ),),
                "INVALID_DIFFERENTIAL_SYSTEM",
                "original_matrices",
            ),
            "undeclared-parameter": (
                (( '"parameters" -> {}', '"parameters" -> {z}'),),
                "INVALID_REPAIR_INPUT",
                "differential_system",
            ),
            "nonzero-cross-block": (
                ((
                    '{0, 0, -eps/(1 + x)}',
                    '{eps/x, 0, -eps/(1 + x)}',
                ),),
                "INVALID_REPAIR_INPUT",
                "frozen_prefix.source_blocks",
            ),
            "broader-scope-claim": (
                ((
                    '"DIRECT_SUM_1X1_PREFIX_PLUS_2X2_TAIL_INTERNAL"',
                    '"GENERIC_LOCALIZED_FULL_PREFIX"',
                ),),
                "INVALID_REPAIR_INPUT",
                "frozen_prefix",
            ),
        }
        for name, (replacements, expected_code, expected_field) in cases.items():
            with self.subTest(name=name):
                request = self.mutated_wl(
                    base_request, f"structured-preflight-{name}", replacements
                )
                output = self.run_root / f"structured-preflight-{name}-output"
                result = self.run_wls(
                    ROOT / "methods" / "libra-structured-repair" / "run.wls",
                    self.structured_repair_provider_input(
                        f"T-STRUCTURED-PREFLIGHT-{name.upper()}",
                        repair_request=request,
                    ),
                    output,
                    expected_returncode=1,
                )
                self.assertEqual((result["status"], result["code"]), ("ERROR", expected_code))
                self.assertEqual(result["summary"]["field"], expected_field)
                self.assertNotEqual(result["code"], "TOOL_UNAVAILABLE")

    def test_structured_repair_preflight_requires_exact_defect_and_canonical_prefix(self) -> None:
        base_prepared = FIXTURES / "structured-repair-prepared-basis.wl"
        base_request = FIXTURES / "structured-repair-input.wl"

        other_kind_prepared = self.mutated_wl(
            base_prepared,
            "structured-other-kind-prepared",
            (( '"kind" -> "epsilon-factorization"', '"kind" -> "another-defect-kind"'),),
        )
        other_kind_request = self.mutated_wl(
            base_request,
            "structured-other-kind-request",
            (( '"kind" -> "epsilon-factorization"', '"kind" -> "another-defect-kind"'),),
        )
        noncanonical_prefix = self.mutated_wl(
            base_request,
            "structured-noncanonical-prefix",
            (
                ("{eps/x, 0, 0}", "{1/x, 0, 0}"),
                ('"accepted_matrices" -> {{{eps/x}}}', '"accepted_matrices" -> {{{1/x}}}'),
            ),
        )

        cases = {
            "other-defect-kind": (
                other_kind_prepared,
                other_kind_request,
                "localized_target.prepared_signature",
            ),
            "noncanonical-prefix": (
                base_prepared,
                noncanonical_prefix,
                "frozen_prefix.accepted_matrices",
            ),
        }
        for name, (prepared, request, expected_field) in cases.items():
            with self.subTest(name=name):
                output = self.run_root / f"structured-v1-preflight-{name}"
                result = self.run_wls(
                    ROOT / "methods" / "libra-structured-repair" / "run.wls",
                    self.structured_repair_provider_input(
                        f"T-STRUCTURED-V1-PREFLIGHT-{name.upper()}",
                        prepared_basis=prepared,
                        repair_request=request,
                    ),
                    output,
                    expected_returncode=1,
                )
                self.assertEqual(
                    (result["status"], result["code"]),
                    ("ERROR", "INVALID_REPAIR_INPUT"),
                )
                self.assertEqual(result["summary"]["field"], expected_field)
                self.assertNotEqual(result["code"], "TOOL_UNAVAILABLE")

    def test_structured_repair_scope_invalid_system_and_method_exhaustion(self) -> None:
        base_prepared = FIXTURES / "structured-repair-prepared-basis.wl"
        multivariable_prepared = self.mutated_wl(
            base_prepared,
            "structured-multivariable-prepared",
            (( '"variables" -> {x}', '"variables" -> {x, y}'),),
        )
        flat_request = FIXTURES / "structured-repair-input-multivariable-flat.wl"

        out = self.run_root / "structured-multivariable"
        result = self.run_wls(
            ROOT / "methods" / "libra-structured-repair" / "run.wls",
            self.structured_repair_provider_input(
                "T-STRUCTURED-MULTIVARIABLE",
                prepared_basis=multivariable_prepared,
                repair_request=flat_request,
            ),
            out,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("INCONCLUSIVE", "OUT_OF_SCOPE"),
        )

        global_request = self.mutated_wl(
            FIXTURES / "structured-repair-input.wl",
            "structured-global-request",
            (( '"scope" -> "LOCALIZED_BLOCK"', '"scope" -> "GLOBAL"'),),
        )
        out = self.run_root / "structured-global"
        result = self.run_wls(
            ROOT / "methods" / "libra-structured-repair" / "run.wls",
            self.structured_repair_provider_input(
                "T-STRUCTURED-GLOBAL", repair_request=global_request
            ),
            out,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("INCONCLUSIVE", "OUT_OF_SCOPE"),
        )

        nonflat_request = self.mutated_wl(
            flat_request,
            "structured-multivariable-nonflat",
            (( 'ConstantArray[0, {3, 3}]', '{{x, 0, 0}, {0, 0, 0}, {0, 0, 0}}'),),
        )
        out = self.run_root / "structured-nonflat"
        result = self.run_wls(
            ROOT / "methods" / "libra-structured-repair" / "run.wls",
            self.structured_repair_provider_input(
                "T-STRUCTURED-NONFLAT",
                prepared_basis=multivariable_prepared,
                repair_request=nonflat_request,
            ),
            out,
            expected_returncode=1,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("ERROR", "INVALID_DIFFERENTIAL_SYSTEM"),
        )
        self.assertEqual(result["summary"]["field"], "original_matrices.flatness")

        out = self.run_root / "structured-exhausted"
        result = self.run_wls(
            ROOT / "methods" / "libra-structured-repair" / "run.wls",
            self.structured_repair_provider_input(
                "T-STRUCTURED-EXHAUSTED", package_entry=self.fake_libra_entry()
            ),
            out,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("INCONCLUSIVE", "METHOD_EXHAUSTED"),
        )

    def test_structured_repair_checker_positive_and_adversarial_rejections(self) -> None:
        base = FIXTURES / "structured-repair-candidate.wl"
        positive_output = self.run_root / "structured-static-positive"
        positive = self.run_wls(
            ROOT / "mma" / "CheckStructuredRepair.wls",
            self.structured_repair_checker_input("T-STRUCTURED-STATIC-POSITIVE", base),
            positive_output,
        )
        self.assertEqual(
            (positive["status"], positive["code"]),
            ("PASS", "VERIFIED_STRUCTURED_REPAIR"),
        )

        cases = {
            "prefix-modified": (
                ((
                    '"transformation" -> {{1, 0, 0}, {0, 1, x}, {0, 0, 1}}',
                    '"transformation" -> {{2, 0, 0}, {0, 1, x}, {0, 0, 1}}',
                ),),
                "frozen_prefix_modified",
            ),
            "forbidden-mixing": (
                ((
                    '"transformation" -> {{1, 0, 0}, {0, 1, x}, {0, 0, 1}}',
                    '"transformation" -> {{1, x, 0}, {0, 1, x}, {0, 0, 1}}',
                ),),
                "forbidden_prefix_mixing",
            ),
            "wrong-gauge": (
                (( '{0, eps/x, eps/(1 - x)}', '{0, eps/x, 2 eps/(1 - x)}'),),
                "wrong_gauge_residual",
            ),
            "unresolved-target": (
                (
                    (
                        '"transformation" -> {{1, 0, 0}, {0, 1, x}, {0, 0, 1}}',
                        '"transformation" -> IdentityMatrix[3]',
                    ),
                    (
                        '{0, eps/x, eps/(1 - x)}',
                        '{0, eps/x, 1 - eps + eps/(1 - x) - x eps/(1 + x)}',
                    ),
                ),
                "unresolved_target_defect",
            ),
            "accepted-block-regression": (
                ((
                    '"transformation" -> {{1, 0, 0}, {0, 1, x}, {0, 0, 1}}',
                    '"transformation" -> {{1, 0, 0}, {x, 1, x}, {0, 0, 1}}',
                ),),
                "accepted_tail_from_prefix_regression",
            ),
            "wrong-order": (
                (( '"basis" -> {l1, j1, j2}', '"basis" -> {j1, l1, j2}'),),
                "identity_or_order_mismatch",
            ),
            "forged-provider-pass": (
                ((
                    '"provider_status" -> "PROVISIONAL/CANDIDATE_TRANSFORMATION"',
                    '"provider_status" -> "PASS/VERIFIED_STRUCTURED_REPAIR"',
                ),),
                "forged_provider_status",
            ),
            "undeclared-z": (
                ((
                    '"transformation" -> {{1, 0, 0}, {0, 1, x}, {0, 0, 1}}',
                    '"transformation" -> {{1, 0, 0}, {0, z, x z}, {0, 0, z}}',
                ),),
                "coefficient_domain_invalid",
            ),
            "forged-libra-provenance": (
                (
                    (
                        f'"entry" -> {FIXTURE_ENTRY_EXPRESSION}',
                        '"entry" -> "/nonexistent/forged-Libra.m"',
                    ),
                    (
                        FIXTURE_HASH_EXPRESSION,
                        '"0000000000000000000000000000000000000000000000000000000000000000"',
                    ),
                    (
                        '"package_source" -> "method_options.package_entry"',
                        '"package_source" -> "forged"',
                    ),
                    (
                        '"factor_out_mu" -> 1/2',
                        '"factor_out_mu" -> 99',
                    ),
                ),
                "libra_provenance_mismatch",
            ),
        }
        for name, (replacements, expected_reason) in cases.items():
            with self.subTest(name=name):
                candidate = self.mutated_wl(base, f"structured-{name}", replacements)
                output = self.run_root / f"structured-negative-{name}"
                result = self.run_wls(
                    ROOT / "mma" / "CheckStructuredRepair.wls",
                    self.structured_repair_checker_input(
                        f"T-STRUCTURED-NEGATIVE-{name.upper()}", candidate
                    ),
                    output,
                )
                self.assertEqual(
                    (result["status"], result["code"]),
                    ("FAIL", "STRUCTURED_REPAIR_REJECTED"),
                )
                self.assertIn(expected_reason, result["summary"]["rejection_signature"])

    def test_structured_repair_checker_hashes_package_without_executing_it(self) -> None:
        marker = self.run_root / "checker-executed-package.marker"
        sentinel = self.run_root / "SentinelLibra.m"
        sentinel.write_text(
            f'Put["EXECUTED", {json.dumps(str(marker))}]; Abort[];\n',
            encoding="utf-8",
        )
        sentinel_sha256 = hashlib.sha256(sentinel.read_bytes()).hexdigest()
        candidate = self.mutated_wl(
            FIXTURES / "structured-repair-candidate.wl",
            "structured-sentinel-provenance",
            (
                (
                    f'"entry" -> {FIXTURE_ENTRY_EXPRESSION}',
                    f'"entry" -> "{sentinel}"',
                ),
                (
                    FIXTURE_HASH_EXPRESSION,
                    f'"{sentinel_sha256}"',
                ),
            ),
        )
        output = self.run_root / "structured-sentinel-checker"
        result = self.run_wls(
            ROOT / "mma" / "CheckStructuredRepair.wls",
            self.structured_repair_checker_input(
                "T-STRUCTURED-SENTINEL-CHECKER",
                candidate,
                checker_entry=sentinel,
                checker_sha256=sentinel_sha256,
            ),
            output,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("PASS", "VERIFIED_STRUCTURED_REPAIR"),
        )
        self.assertTrue(result["summary"]["authenticated_libra_provenance"])
        self.assertFalse(marker.exists(), "checker executed the hashed provider package")

    def test_initial_components_work_in_an_arbitrary_installation_layout(self) -> None:
        initial = self.run_root / "solver files" / "entry.wl"
        finite_flow = self.run_root / "algebra files" / "binding.wl"
        native = self.run_root / "native files" / "declared-library.bin"
        reference = self.run_root / "reference data"
        marker = self.run_root / "selected-threads.wl"
        for directory in (initial.parent, finite_flow.parent, native.parent, reference):
            directory.mkdir()
        native.write_bytes(b"fixture for the declared native-library path")
        finite_flow.write_text(
            'BeginPackage["FiniteFlow`"]; Begin["`Private`"];\n'
            f'fflowlib = {json.dumps(str(native))};\nEnd[]; EndPackage[];\n',
            encoding="utf-8",
        )
        initial.write_text(
            'Options[TCalc] = {"NThreads" -> 1, "TakeRow" -> 1, "Silent" -> True};\n'
            'TCalc[a_, f_, v_, e_, OptionsPattern[]] := '
            f'(Put[OptionValue["NThreads"], {json.dumps(str(marker))}]; IdentityMatrix[26]);\n'
            'basisChange[a_, t_, v_, opts___] := a;\n',
            encoding="utf-8",
        )
        (reference / "AMatrix_ladder.m").write_text(
            "DiagonalMatrix[Join[{eps/x}, ConstantArray[0, 25]]]\n", encoding="utf-8"
        )
        (reference / "initial_basis_ladder.m").write_text(
            "Join[{G[2,{1,1,1,1,1,1,1,1,1,1,-1,0,0,0,0}]}, Array[b,25]]\n",
            encoding="utf-8",
        )
        (reference / "TMatrix_ladder_to_UT.m").write_text(
            "IdentityMatrix[26]\n", encoding="utf-8"
        )
        components = dict(zip(
            INITIAL_COMPONENT_KEYS,
            (str(path.relative_to(self.run_root)) for path in (initial, finite_flow, native, reference)),
        ))
        components["threads"] = 3
        provider_id = "T-INITIAL-PORTABLE-FIXTURE"
        provider_output = self.run_root / "portable-provider"
        provider = self.run_wls(
            ROOT / "methods" / "initial" / "run.wls",
            self.initial_provider_input(provider_id, components=components),
            provider_output,
        )
        self.assertEqual(provider["code"], "EVIDENCE_AWAITING_VERIFICATION")
        self.assertEqual(marker.read_text().strip(), "3")
        evidence = provider_output / provider["artifacts"]["ut_evidence"]["path"]
        checker = self.run_wls(
            ROOT / "mma" / "CheckUTEvidence.wls",
            self.initial_checker_input("T-CHECK-PORTABLE-FIXTURE", provider_id, evidence, components),
            self.run_root / "portable-checker",
        )
        self.assertEqual(checker["code"], "VERIFIED_EVIDENCE")

    @unittest.skipUnless(
        INITIAL_TEST_CONFIG is not None and INITIAL_TEST_CONFIG.is_file(),
        "set CANON_TEST_INITIAL_CONFIG to run the real INITIAL ladder test",
    )
    def test_initial_official_ladder_provider_and_independent_checker(self) -> None:
        assert INITIAL_TEST_CONFIG is not None
        components = json.loads(INITIAL_TEST_CONFIG.read_text(encoding="utf-8"))
        for key in INITIAL_COMPONENT_KEYS:
            components[key] = str((INITIAL_TEST_CONFIG.parent / components[key]).resolve())
        provider_task_id = "T-INITIAL-OFFICIAL-PROVIDER"
        provider_output = self.run_root / "initial-official-provider"
        provider_result = self.run_wls(
            ROOT / "methods" / "initial" / "run.wls",
            self.initial_provider_input(
                provider_task_id, components=components
            ),
            provider_output,
            timeout=600,
        )
        self.assertEqual(
            (provider_result["status"], provider_result["code"]),
            ("PROVISIONAL", "EVIDENCE_AWAITING_VERIFICATION"),
        )
        self.assertNotIn(provider_result["status"], {"PASS", "FAIL"})
        evidence_path = provider_output / provider_result["artifacts"][
            "ut_evidence"
        ]["path"]

        checker_output = self.run_root / "initial-official-checker"
        checker_result = self.run_wls(
            ROOT / "mma" / "CheckUTEvidence.wls",
            self.initial_checker_input(
                "T-INITIAL-OFFICIAL-CHECKER",
                provider_task_id,
                evidence_path,
                components,
            ),
            checker_output,
            timeout=240,
        )
        self.assertEqual(
            (checker_result["status"], checker_result["code"]),
            ("PASS", "VERIFIED_EVIDENCE"),
        )
        self.assertEqual(
            checker_result["summary"],
            {
                "family_id": "initial-official-massless-3l4p",
                "candidate_id": "official-planar-ladder-26x26",
                "basis_id": "initial-2.1-massless-3l4p-ladder-basis-26",
                "official_reference_match": True,
                "invertible": True,
                "exact_gauge": True,
                "epsilon_independent_after_division": True,
                "declared_dlog_alphabet": True,
            },
        )

    def test_initial_out_of_scope_family_is_inconclusive_without_tool_action(self) -> None:
        output = self.run_root / "initial-out-of-scope"
        result = self.run_wls(
            ROOT / "methods" / "initial" / "run.wls",
            self.initial_provider_input(
                "T-INITIAL-OUT-OF-SCOPE",
                candidate_updates={"family_id": "another-family"},
            ),
            output,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("INCONCLUSIVE", "OUT_OF_SCOPE"),
        )
        self.assertEqual(result["summary"]["workflow_action"], "none")
        self.assertFalse(result["artifacts"])

    def test_initial_provider_has_single_typed_publication_authority(self) -> None:
        runner = (ROOT / "methods" / "initial" / "run.wls").read_text(
            encoding="utf-8"
        )
        self.assertNotIn("CanonMethodCard`WriteResult[", runner)
        self.assertEqual(runner.count("CanonMethodCard`WriteProviderResult["), 2)
        self.assertNotIn('"FAIL"', runner)
        self.assertNotIn("EVIDENCE_REJECTED", runner)
        self.assertEqual(
            runner.count('"INCONCLUSIVE", "METHOD_EXHAUSTED"'), 2
        )

        checker = (ROOT / "mma" / "CheckUTEvidence.wls").read_text(
            encoding="utf-8"
        )
        self.assertIn('"FAIL", "EVIDENCE_REJECTED"', checker)
        self.assertIn('"PASS", "VERIFIED_EVIDENCE"', checker)

    def test_pre_reduction_integral_candidate_contract_is_role_separated(self) -> None:
        input_value = json.loads(
            (ROOT / "interfaces" / "integral-candidate-input.example.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(input_value["step"], "PROPOSE_INTEGRAL_CANDIDATES")
        self.assertEqual(input_value["payload"]["sector_identity"]["id"], 7)
        self.assertEqual(input_value["sector"]["id"], 7)
        for field in (
            "family_identity",
            "sector_identity",
            "dimension_policy",
            "numerator_or_power_counting_policy",
            "candidate_budget",
            "candidate_unit",
            "normalization_policy",
        ):
            self.assertIn(field, input_value["payload"])

        artifact = (FIXTURES / "integral-candidates.wl").read_text(
            encoding="utf-8"
        )
        for field in (
            '"schema" -> "canon-neu/integral-candidates/v1"',
            '"family_identity"',
            '"sector_identity"',
            '"dimension_policy"',
            '"numerator_or_power_counting_policy"',
            '"candidate_budget"',
            '"pool_exhausted"',
            '"candidate_unit"',
            '"normalization_policy"',
            '"candidate_id"',
            '"exact_definition"',
            '"candidate_pool"',
            '"method_evidence"',
            '"tool_provenance"',
        ):
            self.assertIn(field, artifact)

        runner = (ROOT / "methods" / "dlogbasis" / "run.wls").read_text(
            encoding="utf-8"
        )
        self.assertIn('step    = "PROPOSE_INTEGRAL_CANDIDATES"', runner)
        self.assertIn("PROVISIONAL/INTEGRAL_CANDIDATES", runner)
        self.assertIn("INCONCLUSIVE", runner)
        self.assertIn(
            "result = DlogBasis`DlogBasisSearch[",
            runner,
        )
        self.assertIn('prepared["family_data", "path"]', runner)
        self.assertIn('methodOptions["loop_order"]', runner)
        self.assertIn('methodOptions["loop_dimensions"]', runner)
        for forbidden in (
            'step    = "SEARCH_CORE"',
            '"sector_basis"',
            '"sector_cut_de"',
            "CANDIDATE_READY",
            "NO_CANDIDATE",
            "CANDIDATE_TRANSFORMATION",
            "LeadingSingularities",
            "UTCandidateGroupSearch",
            "DlogBasisRefine`",
            "GenerateSectorCandidates",
            "Quiet",
            "Check[",
            "Catch[",
            "Fallback",
        ):
            self.assertNotIn(forbidden, runner)

        template = (ROOT / "methods" / "method-card-template" / "run.wls").read_text(
            encoding="utf-8"
        )
        self.assertIn('"PROPOSE_INTEGRAL_CANDIDATES"', template)
        self.assertIn('"SEARCH_CORE"', template)
        interfaces = (ROOT / "INTERFACES.md").read_text(encoding="utf-8")

    def test_dlogbasis_refine_generates_sector_148_candidate_through_contract(
        self,
    ) -> None:
        if (
            DLOGBASIS_REFINE_ENTRY is None
            or not DLOGBASIS_REFINE_ENTRY.is_file()
            or FINITEFLOW_ENTRY is None
            or not FINITEFLOW_ENTRY.is_file()
        ):
            self.skipTest(
                "set CANON_TEST_DLOGBASIS_REFINE_ENTRY and CANON_TEST_FINITEFLOW_ENTRY"
            )
        package_entry = DLOGBASIS_REFINE_ENTRY
        package_root = package_entry.parent
        family_data = package_root / "Resources" / "Pentabox2L5P" / "family.wl"
        sector_source = (
            package_root / "Resources" / "Pentabox2L5P" / "sector-manifest.wl"
        )
        prepared_family = self.run_root / "dlogbasis-refine-prepared-family.wl"
        prepared_family.write_text(
            '<|"topology" -> "pentabox5", '
            '"variables" -> {CANON`DEData`s12, CANON`DEData`s23, '
            'CANON`DEData`s34, CANON`DEData`s45, CANON`DEData`s51}, '
            '"regulator" -> CANON`DEData`eps, '
            '"family_data" -> <|"path" -> '
            + json.dumps(str(family_data))
            + '|>, "sector_source" -> <|"path" -> '
            + json.dumps(str(sector_source))
            + "|>|>\n",
            encoding="utf-8",
        )
        value = {
            "schema": "canon-neu/script-input/v1",
            "task_id": "T-DLOGBASIS-REFINE-SECTOR-148",
            "step": "PROPOSE_INTEGRAL_CANDIDATES",
            "sector": {"id": 148, "propagator_count": 3},
            "payload": {
                "family_identity": {
                    "family_id": "massless-planar-two-loop-five-point-pentabox",
                    "family_spec_id": "dlogbasis-refine-2l5p-v1",
                },
                "sector_identity": {
                    "sector_id": "pentabox5-sector-148",
                    "id": 148,
                    "propagator_count": 3,
                },
                "prepared_family": {
                    "type": "mathematica-expression",
                    "path": str(prepared_family),
                },
                "dimension_policy": {
                    "spacetime_dimension": 4,
                    "per_loop_policy": "loop-order (1,2), dimensions (4,4)",
                },
                "numerator_or_power_counting_policy": {
                    "policy_id": "dlogbasis-refine-degree-0-total-dot-2",
                    "definition": {
                        "numerator_degree": 0,
                        "max_added_dots": 2,
                        "max_dots_per_propagator": 2,
                    },
                },
                "candidate_budget": {
                    "maximum": 4,
                    "unit": "PROVIDER_CANDIDATE",
                },
                "candidate_unit": "NORMALIZED_LINEAR_COMBINATION",
                "normalization_policy": {
                    "convention": "first-integral-coefficient-outside-definition",
                    "factors": {"placement": "normalization.factor"},
                },
                "method_options": {
                    "package_entry": str(package_entry),
                    "package_revision": os.environ.get("CANON_TEST_DLOGBASIS_REVISION"),
                    "finite_flow_package_file": os.path.relpath(FINITEFLOW_ENTRY, self.run_root),
                    "loop_order": [1, 2],
                    "loop_dimensions": [4, 4],
                    "numerator_positions": [],
                },
            },
        }
        input_path = self.run_root / "dlogbasis-refine-sector-148-input.json"
        input_path.write_text(
            json.dumps(value, indent=2) + "\n",
            encoding="utf-8",
        )
        output = self.run_root / "dlogbasis-refine-sector-148-output"
        result = self.run_wls(
            ROOT / "methods" / "dlogbasis" / "run.wls",
            input_path,
            output,
            timeout=180,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("PROVISIONAL", "INTEGRAL_CANDIDATES"),
        )
        self.assertEqual(result["summary"]["tool"], "DlogBasis-refine")
        self.assertEqual(
            result["summary"]["scientific_status"],
            "AffineFiniteMaximalCutCandidatePartialGeneralizedCutCoverage",
        )
        self.assertEqual(result["summary"]["candidate_count"], 1)
        self.assertFalse(
            result["summary"]["constant_leading_singularity_certified"]
        )
        self.assertEqual(
            result["summary"]["entry_sha256"],
            hashlib.sha256(package_entry.read_bytes()).hexdigest(),
        )
        self.assertEqual(
            result["summary"]["package_revision"],
            os.environ.get("CANON_TEST_DLOGBASIS_REVISION"),
        )
        artifact_path = output / result["artifacts"]["integral_candidates"]["path"]
        self.assertTrue(artifact_path.is_file())
        artifact = artifact_path.read_text(encoding="utf-8")
        compact_artifact = " ".join(artifact.split())
        self.assertIn(
            "HoldComplete[CANON`DEData`j[CANON`DEData`pentabox5, "
            "0, 0, 1, 0, 1, 0, 0, 2, 0, 0, 0]]",
            compact_artifact,
        )
        self.assertIn('"factor" -> 16', compact_artifact)
        self.assertIn("DlogBasis`DlogIntegral", artifact)
        self.assertNotIn("Global`DlogIntegral", artifact)
        for field in (
            '"schema" -> "canon-neu/integral-candidates/v1"',
            '"candidate_id"',
            '"exact_definition"',
            '"candidate_pool"',
            '"method_evidence"',
            '"AffineFiniteMaximalCutCandidatePartialGeneralizedCutCoverage"',
            '"ModuleLiftVerifiedQ" -> True',
            '"ConstantLeadingSingularityCertifiedQ" -> False',
            '"tool_provenance"',
        ):
            self.assertIn(field, artifact)

        value["task_id"] = "T-DLOGBASIS-REFINE-SECTOR-182"
        value["sector"] = {"id": 182, "propagator_count": 5}
        value["payload"]["sector_identity"] = {
            "sector_id": "pentabox5-sector-182",
            "id": 182,
            "propagator_count": 5,
        }
        power_definition = value["payload"][
            "numerator_or_power_counting_policy"
        ]["definition"]
        power_definition["max_added_dots"] = 1
        power_definition["max_dots_per_propagator"] = 1
        value["payload"]["candidate_budget"]["maximum"] = 2
        sector_182_input = self.run_root / "dlogbasis-refine-sector-182-input.json"
        sector_182_input.write_text(
            json.dumps(value, indent=2) + "\n", encoding="utf-8"
        )
        sector_182_output = self.run_root / "dlogbasis-refine-sector-182-output"
        sector_182_result = self.run_wls(
            ROOT / "methods" / "dlogbasis" / "run.wls",
            sector_182_input,
            sector_182_output,
            timeout=180,
        )
        self.assertEqual(
            (sector_182_result["status"], sector_182_result["code"]),
            ("PROVISIONAL", "INTEGRAL_CANDIDATES"),
        )
        self.assertEqual(sector_182_result["summary"]["candidate_count"], 2)
        sector_182_artifact = (
            sector_182_output
            / sector_182_result["artifacts"]["integral_candidates"]["path"]
        ).read_text(encoding="utf-8")
        self.assertIn('"candidate_pool"', sector_182_artifact)

        power_definition["max_added_dots"] = 2
        unsupported_input = (
            self.run_root / "dlogbasis-refine-unsupported-dots.json"
        )
        unsupported_input.write_text(
            json.dumps(value, indent=2) + "\n", encoding="utf-8"
        )
        unsupported_result = self.run_wls(
            ROOT / "methods" / "dlogbasis" / "run.wls",
            unsupported_input,
            self.run_root / "dlogbasis-refine-unsupported-dots-output",
        )
        self.assertEqual(
            (unsupported_result["status"], unsupported_result["code"]),
            ("ERROR", "UNSUPPORTED_POWER_COUNTING"),
        )

        power_definition["max_added_dots"] = 1
        value["payload"]["candidate_unit"] = "INDIVIDUAL_G_INTEGRAL"
        normalization_input = self.run_root / "dlogbasis-refine-normalization.json"
        normalization_input.write_text(
            json.dumps(value, indent=2) + "\n", encoding="utf-8"
        )
        normalization_result = self.run_wls(
            ROOT / "methods" / "dlogbasis" / "run.wls",
            normalization_input,
            self.run_root / "dlogbasis-refine-normalization-output",
        )
        self.assertEqual(
            (normalization_result["status"], normalization_result["code"]),
            ("ERROR", "UNSUPPORTED_CANDIDATE_NORMALIZATION"),
        )

        value["payload"]["candidate_unit"] = "NORMALIZED_LINEAR_COMBINATION"
        value["payload"]["candidate_budget"]["unit"] = "GROUP"
        budget_input = self.run_root / "dlogbasis-refine-budget.json"
        budget_input.write_text(
            json.dumps(value, indent=2) + "\n", encoding="utf-8"
        )
        budget_result = self.run_wls(
            ROOT / "methods" / "dlogbasis" / "run.wls",
            budget_input,
            self.run_root / "dlogbasis-refine-budget-output",
        )
        self.assertEqual(
            (budget_result["status"], budget_result["code"]),
            ("ERROR", "UNSUPPORTED_CANDIDATE_BUDGET"),
        )

    def test_provider_result_guard_accepts_only_typed_integral_candidate_outcome(self) -> None:
        input_path = self.run_root / "integral-provider-input.json"
        input_path.write_text(
            json.dumps(
                {
                    "schema": "canon-neu/script-input/v1",
                    "task_id": "T-INTEGRAL-PROVIDER-GUARD",
                    "step": "PROPOSE_INTEGRAL_CANDIDATES",
                    "payload": {},
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        script = self.run_root / "integral-provider-guard.wls"
        core = ROOT / "mma" / "lib" / "MethodCardCore.wl"
        script.write_text(
            f'''Get[{json.dumps(str(core))}];
args = CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[args[[1]], "PROPOSE_INTEGRAL_CANDIDATES"];
searchTask = Join[KeyDrop[task, {{"step"}}], <|"step" -> "SEARCH_CORE"|>];
repairTask = Join[KeyDrop[task, {{"step"}}], <|"step" -> "REPAIR_WITH_LIBRA"|>];
evidenceTask = Join[KeyDrop[task, {{"step"}}], <|"step" -> "PROVIDE_UT_EVIDENCE"|>];
good = CanonMethodCard`WriteProviderResult[
  task, args[[2]], "PROVISIONAL", "INTEGRAL_CANDIDATES", <||>, <||>
];
goodSearch = CanonMethodCard`WriteProviderResult[
  searchTask, FileNameJoin[{{args[[2]], "search"}}],
  "PROVISIONAL", "CANDIDATE_TRANSFORMATION", <||>, <||>
];
goodRepair = CanonMethodCard`WriteProviderResult[
  repairTask, FileNameJoin[{{args[[2]], "repair"}}],
  "PROVISIONAL", "CANDIDATE_TRANSFORMATION", <||>, <||>
];
goodEvidence = CanonMethodCard`WriteProviderResult[
  evidenceTask, FileNameJoin[{{args[[2]], "evidence"}}],
  "PROVISIONAL", "EVIDENCE_AWAITING_VERIFICATION", <||>, <||>
];
badSearchIntegral = CanonMethodCard`WriteProviderResult[
  searchTask, args[[2]], "PROVISIONAL", "INTEGRAL_CANDIDATES", <||>, <||>
];
badProposalTransformation = CanonMethodCard`WriteProviderResult[
  task, args[[2]], "PROVISIONAL", "CANDIDATE_TRANSFORMATION", <||>, <||>
];
badPass = CanonMethodCard`WriteProviderResult[
  task, args[[2]], "PASS", "INTEGRAL_CANDIDATES", <||>, <||>
];
badFail = CanonMethodCard`WriteProviderResult[
  task, args[[2]], "FAIL", "INTEGRAL_CANDIDATES", <||>, <||>
];
badGenericError = CanonMethodCard`WriteProviderResult[
  task, args[[2]], "ERROR", "ERROR", <||>, <||>
];
If[
  MemberQ[{{good, goodSearch, goodRepair, goodEvidence}}, $Failed] ||
    badSearchIntegral =!= $Failed || badProposalTransformation =!= $Failed ||
    badPass =!= $Failed || badFail =!= $Failed || badGenericError =!= $Failed,
  Exit[1]
];
''',
            encoding="utf-8",
        )
        result = self.run_wls(
            script,
            input_path,
            self.run_root / "integral-provider-guard-output",
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("PROVISIONAL", "INTEGRAL_CANDIDATES"),
        )
        self.assertNotIn(result["status"], {"PASS", "FAIL"})
        for role, step, code in (
            ("search", "SEARCH_CORE", "CANDIDATE_TRANSFORMATION"),
            ("repair", "REPAIR_WITH_LIBRA", "CANDIDATE_TRANSFORMATION"),
            ("evidence", "PROVIDE_UT_EVIDENCE", "EVIDENCE_AWAITING_VERIFICATION"),
        ):
            role_result = json.loads(
                (
                    self.run_root
                    / "integral-provider-guard-output"
                    / role
                    / "result.json"
                ).read_text(encoding="utf-8")
            )
            self.assertEqual(
                (role_result["step"], role_result["code"]),
                (step, code),
            )

    def test_retired_workflow_narratives_cannot_claim_current_authority(self) -> None:
        architecture = (ROOT / "ARCHITECTURE.md").read_text(encoding="utf-8")
        self.assertIn("历史架构（已退役）", architecture)
        self.assertIn("不得恢复或作为当前事实引用", architecture)
        self.assertIn("`AGENTS.md`", architecture)
        self.assertIn("`README.md`", architecture)
        self.assertIn("`statemng`", architecture)

        worklist = (ROOT / "WORKLIST.md").read_text(encoding="utf-8")
        self.assertIn("历史 scientific worklist（非状态看板）", worklist)
        self.assertIn("不是当前任务状态或 authority", worklist)
        self.assertIn("`statemng`", worklist)

        interfaces = (ROOT / "INTERFACES.md").read_text(encoding="utf-8")
        for retired in ("`delegate`", "`subreport`", "`state.json`"):
            self.assertNotIn(retired, interfaces)
        self.assertIn("根目录 `AGENTS.md` 和 `README.md`", interfaces)

        legacy_skills = "\n".join(
            path.read_text(encoding="utf-8")
            for path in sorted((ROOT / "skills").glob("canon-*/SKILL.md"))
        )
        for retired in ("state.json", "workflow.py", "subreport"):
            self.assertNotIn(retired, legacy_skills)
        self.assertIn("governed only by `statemng`", legacy_skills)

    def test_initial_missing_registered_components_is_tool_error(self) -> None:
        output = self.run_root / "initial-missing-components"
        result = self.run_wls(
            ROOT / "methods" / "initial" / "run.wls",
            self.initial_provider_input(
                "T-INITIAL-MISSING-COMPONENTS",
                components={key: str(self.run_root / key) for key in INITIAL_COMPONENT_KEYS},
            ),
            output,
            expected_returncode=1,
        )
        self.assertEqual(result["status"], "ERROR")
        self.assertIn(result["code"], {"TOOL_CONFIGURATION", "TOOL_COMPONENT_MISSING"})

    def test_initial_mismatched_tool_identity_is_error(self) -> None:
        output = self.run_root / "initial-wrong-identity"
        result = self.run_wls(
            ROOT / "methods" / "initial" / "run.wls",
            self.initial_provider_input(
                "T-INITIAL-WRONG-IDENTITY",
                components=dict.fromkeys(INITIAL_COMPONENT_KEYS, str(self.run_root / "unused")),
                identity_updates={"initial_identity": "INITIAL unknown"},
            ),
            output,
            expected_returncode=1,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("ERROR", "TOOL_IDENTITY_MISMATCH"),
        )

    def test_initial_checker_rejects_identity_order_seed_and_reference_mismatch(self) -> None:
        original = (FIXTURES / "forged-initial-ut-evidence.wl").read_text(
            encoding="utf-8"
        )
        mutations = {
            "task": ("T-FIXTURE-INITIAL-EVIDENCE", "T-WRONG-PROVIDER"),
            "family": (
                '"initial-official-massless-3l4p"',
                '"wrong-family"',
            ),
            "candidate": (
                '"official-planar-ladder-26x26"',
                '"wrong-candidate"',
            ),
            "basis": (
                '"initial-2.1-massless-3l4p-ladder-basis-26"',
                '"wrong-basis"',
            ),
            "order": (
                '"initial_basis_ladder.m:official-order"',
                '"reverse-order"',
            ),
            "normalization": ('"D=4-2 eps;x=t/s"', '"D=6-2 eps;x=t/s"'),
            "reference": (
                '"INITIAL-2.1:massless_3L4P/TMatrix_ladder_to_UT.m"',
                '"wrong-reference"',
            ),
            "seed": (
                "1, 1, -1, 0, 0, 0, 0}",
                "1, 1, 0, 0, 0, 0, 0}",
            ),
        }
        for name, (old, new) in mutations.items():
            with self.subTest(name=name):
                artifact = self.run_root / f"initial-{name}-evidence.wl"
                artifact.write_text(original.replace(old, new), encoding="utf-8")
                output = self.run_root / f"initial-{name}-check"
                result = self.run_wls(
                    ROOT / "mma" / "CheckUTEvidence.wls",
                    self.initial_checker_input(
                        f"T-INITIAL-CHECK-{name.upper()}",
                        "T-FIXTURE-INITIAL-EVIDENCE",
                        artifact,
                        {},
                    ),
                    output,
                )
                self.assertEqual(
                    (result["status"], result["code"]),
                    ("FAIL", "EVIDENCE_REJECTED"),
                )

    def test_initial_checker_ignores_forged_provider_pass_claims(self) -> None:
        output = self.run_root / "initial-forged-check"
        result = self.run_wls(
            ROOT / "mma" / "CheckUTEvidence.wls",
            self.initial_checker_input(
                "T-INITIAL-CHECK-FORGED",
                "T-FIXTURE-INITIAL-EVIDENCE",
                FIXTURES / "forged-initial-ut-evidence.wl",
                {},
            ),
            output,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("FAIL", "EVIDENCE_REJECTED"),
        )
        self.assertIn("singular", result["summary"]["reason"])

    def test_provider_fails_closed_when_declared_package_is_missing(self) -> None:
        output = self.run_root / "missing-package-provider"
        result = self.run_wls(
            ROOT / "methods" / "libra" / "run.wls",
            self.provider_input("libra", self.run_root / "missing-Libra.m"),
            output,
            expected_returncode=1,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("ERROR", "TOOL_UNAVAILABLE"),
        )

    def test_provider_rejects_malformed_package_option_as_input_error(self) -> None:
        output = self.run_root / "malformed-package-option"
        result = self.run_wls(
            ROOT / "methods" / "libra" / "run.wls",
            self.provider_input(
                "libra", method_options={"package_entry": 17}
            ),
            output,
            expected_returncode=1,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("ERROR", "INVALID_OPTIONS"),
        )

    def test_full_prefix_screen_replaces_bad_tail_before_repair(self) -> None:
        output = self.run_root / "tail-screen-pass"
        result = self.run_wls(
            ROOT / "methods" / "full-prefix-tail-screen" / "run.wls",
            self.tail_screen_input(
                "T-SCREEN-TAIL-PASS",
                FIXTURES / "tail-full-prefix-candidates.wl",
                2,
            ),
            output,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("PASS", "TAIL_SCREEN_PASS"),
        )
        summary = result["summary"]
        self.assertEqual(summary["selected_candidate_id"], "fixture-completed-candidate")
        self.assertEqual(summary["selected_pool_index"], 2)
        self.assertFalse(summary["repair_invoked"])
        self.assertFalse(summary["repair_eligible"])
        self.assertEqual(len(summary["attempts"]), 2)
        first, second = summary["attempts"]
        self.assertTrue(first["exact_core"])
        self.assertFalse(first["epsilon_factorized"])
        self.assertIn("not_epsilon_factorized", first["rejection_signature"])
        self.assertTrue(second["pass"])
        self.assertTrue(second["dlog_form"])
        artifact = output / result["artifacts"]["screened_candidate"]["path"]
        artifact_text = artifact.read_text(encoding="utf-8")
        self.assertIn('"candidate_id" -> "fixture-completed-candidate"', artifact_text)
        self.assertIn('"full_transformation" -> {{1, 0}, {x, 1}}', artifact_text)
        self.assertIn('"dlog_form" -> True', artifact_text)

    def test_full_prefix_screen_short_circuits_after_first_pass(self) -> None:
        output = self.run_root / "tail-screen-short-circuit"
        result = self.run_wls(
            ROOT / "methods" / "full-prefix-tail-screen" / "run.wls",
            self.tail_screen_input(
                "T-SCREEN-TAIL-SHORT-CIRCUIT",
                FIXTURES / "tail-full-prefix-short-circuit.wl",
                2,
            ),
            output,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("PASS", "TAIL_SCREEN_PASS"),
        )
        self.assertEqual(result["summary"]["selected_pool_index"], 1)
        self.assertEqual(len(result["summary"]["attempts"]), 1)
        self.assertEqual(
            result["summary"]["attempts"][0]["candidate_id"],
            "fixture-completed-candidate",
        )

    def test_tail_screen_budget_does_not_enable_repair_with_candidates_left(self) -> None:
        output = self.run_root / "tail-screen-budget"
        result = self.run_wls(
            ROOT / "methods" / "full-prefix-tail-screen" / "run.wls",
            self.tail_screen_input(
                "T-SCREEN-TAIL-BUDGET",
                FIXTURES / "tail-full-prefix-candidates.wl",
                1,
            ),
            output,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("INCONCLUSIVE", "CANDIDATE_BUDGET_EXHAUSTED"),
        )
        self.assertFalse(result["summary"]["pool_exhausted"])
        self.assertFalse(result["summary"]["repair_eligible"])
        self.assertFalse(result["summary"]["repair_invoked"])

    def test_tail_screen_enables_separate_repair_only_after_pool_exhaustion(self) -> None:
        output = self.run_root / "tail-screen-pool"
        result = self.run_wls(
            ROOT / "methods" / "full-prefix-tail-screen" / "run.wls",
            self.tail_screen_input(
                "T-SCREEN-TAIL-POOL",
                FIXTURES / "tail-full-prefix-all-bad.wl",
                2,
            ),
            output,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("FAIL", "CANDIDATE_POOL_EXHAUSTED"),
        )
        self.assertTrue(result["summary"]["pool_exhausted"])
        self.assertTrue(result["summary"]["repair_eligible"])
        self.assertFalse(result["summary"]["repair_invoked"])

    def test_tail_screen_rejects_incomplete_full_prefix_pool(self) -> None:
        output = self.run_root / "tail-screen-incomplete-pool"
        result = self.run_wls(
            ROOT / "methods" / "full-prefix-tail-screen" / "run.wls",
            self.tail_screen_input(
                "T-SCREEN-TAIL-INCOMPLETE",
                FIXTURES / "tail-full-prefix-incomplete.wl",
                1,
            ),
            output,
            expected_returncode=1,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("ERROR", "INVALID_CANDIDATE_IDS"),
        )
        self.assertFalse(result["summary"]["repair_invoked"])

    def test_tail_screen_rejects_epsilon_form_outside_declared_dlog_span(self) -> None:
        output = self.run_root / "tail-screen-not-dlog"
        result = self.run_wls(
            ROOT / "methods" / "full-prefix-tail-screen" / "run.wls",
            self.tail_screen_input(
                "T-SCREEN-TAIL-NOT-DLOG",
                FIXTURES / "tail-full-prefix-epsilon-not-dlog.wl",
                2,
            ),
            output,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("FAIL", "CANDIDATE_POOL_EXHAUSTED"),
        )
        attempt = result["summary"]["attempts"][1]
        self.assertTrue(attempt["epsilon_factorized"])
        self.assertFalse(attempt["dlog_form"])
        self.assertIn("not_declared_dlog", attempt["rejection_signature"])

    def test_tail_screen_rejects_lower_prefix_redefinition(self) -> None:
        output = self.run_root / "tail-screen-forbidden-lower"
        result = self.run_wls(
            ROOT / "methods" / "full-prefix-tail-screen" / "run.wls",
            self.tail_screen_input(
                "T-SCREEN-TAIL-FORBIDDEN-LOWER",
                FIXTURES / "tail-full-prefix-forbidden-lower.wl",
                2,
            ),
            output,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("FAIL", "CANDIDATE_POOL_EXHAUSTED"),
        )
        for attempt in result["summary"]["attempts"]:
            self.assertTrue(attempt["exact_full_gauge"])
            self.assertIn(
                "forbidden_lower_prefix_transform",
                attempt["rejection_signature"],
            )

    def test_tail_screen_rejects_declared_full_gauge_mismatch(self) -> None:
        output = self.run_root / "tail-screen-wrong-gauge"
        result = self.run_wls(
            ROOT / "methods" / "full-prefix-tail-screen" / "run.wls",
            self.tail_screen_input(
                "T-SCREEN-TAIL-WRONG-GAUGE",
                FIXTURES / "tail-full-prefix-wrong-gauge.wl",
                2,
            ),
            output,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("FAIL", "CANDIDATE_POOL_EXHAUSTED"),
        )
        for attempt in result["summary"]["attempts"]:
            self.assertFalse(attempt["exact_full_gauge"])
            self.assertIn("full_gauge_residual", attempt["rejection_signature"])


if __name__ == "__main__":
    unittest.main()
