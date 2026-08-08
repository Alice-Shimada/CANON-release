from __future__ import annotations

import json
import os
import subprocess
import tempfile
import time
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests" / "fixtures" / "method_cards"
DEFAULT_KERNEL = Path(
    "/Applications/Mathematica.app/Contents/MacOS/WolframKernel"
)
KERNEL = Path(os.environ.get("CANON_WOLFRAM_KERNEL", DEFAULT_KERNEL))


def optional_entry(name: str) -> Path | None:
    value = os.environ.get(name)
    return Path(value).resolve() if value else None


CANONICA_ENTRY = optional_entry("CANON_TEST_CANONICA_ENTRY")
LIBRA_ENTRY = optional_entry("CANON_TEST_LIBRA_ENTRY")
INITIAL_HEP_TOOLS_ROOT = optional_entry("CANON_TEST_INITIAL_HEP_TOOLS_ROOT")


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
        environment["OMP_NUM_THREADS"] = "1"
        environment["MKL_NUM_THREADS"] = "1"
        environment["NUMEXPR_NUM_THREADS"] = "1"
        environment["OPENBLAS_NUM_THREADS"] = "1"
        environment["USE_OPENMP"] = "1"
        environment["VECLIB_MAXIMUM_THREADS"] = "1"
        completed = subprocess.run(
            [
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
        time.sleep(1.0)
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

    def initial_candidate(self) -> dict:
        value = json.loads(
            (FIXTURES / "initial-evidence-input.json").read_text(encoding="utf-8")
        )
        return value["payload"]["candidate"]

    def initial_provider_input(
        self,
        task_id: str,
        *,
        hep_tools_root: Path | None = None,
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
        if hep_tools_root is not None:
            options = {
                "hep_tools_root": str(hep_tools_root),
                "initial_identity": (
                    "INITIAL 2.1; 63d8f813ac415f82f7ef945ee7e3f78a242fae49"
                ),
                "finiteflow_identity": (
                    "FiniteFlow; 278344c169010b74e791af8c5604c8cb9cd8df11"
                ),
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
        hep_tools_root: Path,
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
                "checker_options": {"hep_tools_root": str(hep_tools_root)},
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
    ) -> None:
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
            ("PASS", "CANDIDATE_READY"),
        )
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
        self.assertEqual(
            check_result["summary"],
            {
                "candidate_index": 1,
                "invertible": True,
                "exact_gauge": True,
                "flat_connection": True,
                "epsilon_factorized": True,
            },
        )

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
            relative_entry=True,
        )

    @unittest.skipUnless(
        LIBRA_ENTRY is not None and LIBRA_ENTRY.is_file(),
        "set CANON_TEST_LIBRA_ENTRY to run the real Libra provider test",
    )
    def test_libra_provider_and_independent_checker(self) -> None:
        assert LIBRA_ENTRY is not None
        self.assert_provider_closes_exact_core_loop(
            "libra",
            LIBRA_ENTRY,
            '"transformation" -> {{1, x}, {0, 1}}',
            relative_entry=False,
        )

    @unittest.skipUnless(
        INITIAL_HEP_TOOLS_ROOT is not None and INITIAL_HEP_TOOLS_ROOT.is_dir(),
        "set CANON_TEST_INITIAL_HEP_TOOLS_ROOT to run the real INITIAL ladder test",
    )
    def test_initial_official_ladder_provider_and_independent_checker(self) -> None:
        assert INITIAL_HEP_TOOLS_ROOT is not None
        provider_task_id = "T-INITIAL-OFFICIAL-PROVIDER"
        provider_output = self.run_root / "initial-official-provider"
        provider_result = self.run_wls(
            ROOT / "methods" / "initial" / "run.wls",
            self.initial_provider_input(
                provider_task_id, hep_tools_root=INITIAL_HEP_TOOLS_ROOT
            ),
            provider_output,
            timeout=600,
        )
        self.assertEqual(
            (provider_result["status"], provider_result["code"]),
            ("PROVISIONAL", "EVIDENCE_AWAITING_VERIFICATION"),
        )
        self.assertNotEqual(provider_result["status"], "PASS")
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
                INITIAL_HEP_TOOLS_ROOT,
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

    def test_initial_missing_registered_components_is_tool_error(self) -> None:
        fake_root = self.run_root / "empty-hep-tools"
        fake_root.mkdir()
        output = self.run_root / "initial-missing-components"
        result = self.run_wls(
            ROOT / "methods" / "initial" / "run.wls",
            self.initial_provider_input(
                "T-INITIAL-MISSING-COMPONENTS", hep_tools_root=fake_root
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
                hep_tools_root=self.run_root,
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
                        self.run_root / "not-used",
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
                self.run_root / "not-used",
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

    def test_checker_rejects_provider_claim_with_wrong_gauge_residual(self) -> None:
        output = self.run_root / "negative-check"
        result = self.run_wls(
            ROOT / "mma" / "CheckSectorCore.wls",
            self.check_input(
                "T-CHECK-NEGATIVE", FIXTURES / "bad-core-candidates.wl"
            ),
            output,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("FAIL", "CORE_FAIL"),
        )
        checks = result["summary"]["candidate_checks"]
        self.assertFalse(checks[0]["exact_gauge"])

    def test_checker_rejects_candidate_from_wrong_sector(self) -> None:
        output = self.run_root / "wrong-sector-check"
        result = self.run_wls(
            ROOT / "mma" / "CheckSectorCore.wls",
            self.check_input(
                "T-CHECK-WRONG-SECTOR",
                FIXTURES / "wrong-sector-core-candidates.wl",
            ),
            output,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("FAIL", "CORE_FAIL"),
        )
        self.assertIn("identity mismatch", result["summary"]["reason"])

    def test_checker_rejects_approximate_candidate(self) -> None:
        output = self.run_root / "approximate-check"
        result = self.run_wls(
            ROOT / "mma" / "CheckSectorCore.wls",
            self.check_input(
                "T-CHECK-APPROXIMATE",
                FIXTURES / "approximate-core-candidates.wl",
            ),
            output,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("FAIL", "CORE_FAIL"),
        )
        checks = result["summary"]["candidate_checks"]
        self.assertIn("exact rational-function domain", checks[0]["reason"])

    def test_checker_rejects_algebraic_candidate_in_rational_domain(self) -> None:
        output = self.run_root / "algebraic-check"
        result = self.run_wls(
            ROOT / "mma" / "CheckSectorCore.wls",
            self.check_input(
                "T-CHECK-ALGEBRAIC",
                FIXTURES / "algebraic-core-candidates.wl",
            ),
            output,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("FAIL", "CORE_FAIL"),
        )
        checks = result["summary"]["candidate_checks"]
        self.assertIn("exact rational-function domain", checks[0]["reason"])

    def test_nonflat_cut_is_upstream_error_not_candidate_failure(self) -> None:
        output = self.run_root / "nonflat-check"
        result = self.run_wls(
            ROOT / "mma" / "CheckSectorCore.wls",
            self.check_input(
                "T-CHECK-NONFLAT",
                FIXTURES / "nonflat-core-candidates.wl",
                sector={"id": 4, "propagator_count": 2},
                sector_basis=FIXTURES / "nonflat-sector-basis.wl",
                sector_cut_de=FIXTURES / "nonflat-sector-cut-de.wl",
            ),
            output,
            expected_returncode=1,
        )
        self.assertEqual(
            (result["status"], result["code"]),
            ("ERROR", "INVALID_CUT_DE"),
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
            ("FAIL", "CANDIDATE_BUDGET_EXHAUSTED"),
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
