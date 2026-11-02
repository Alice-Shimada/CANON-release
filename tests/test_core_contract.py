"""CHECK_CORE must bind exact algebra to the correct ordered input artifacts."""

from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests" / "fixtures" / "method_cards"
KERNEL = Path(
    os.environ.get("CANON_WOLFRAM_KERNEL") or shutil.which("WolframKernel") or "WolframKernel"
).expanduser().resolve()

# Same ordered tutorial system and transformation as the live provider tests.
# Include the pool and stable IDs emitted by the current CANONICA/Libra runners.
CANDIDATE = '''<|
  "candidate_id" -> "tutorial:1",
  "construction_rejection" -> None,
  "transformation" -> {{1, x}, {0, 1}},
  "full_new_basis_rows" -> {{1, -x}, {0, 1}},
  "transformed_matrices" -> {{{eps/x, eps/(1-x)}, {0, -eps/(1+x)}}}
|>'''
CANDIDATES = '''<|
  "schema" -> "canon-neu/core-candidates/v1",
  "sector" -> <|"id" -> 3, "propagator_count" -> 2|>,
  "family_id" -> "fixture-libra-tutorial-1",
  "basis_id" -> "fixture-sector-3-basis-v1",
  "coefficient_domain" -> "exact-rational-functions",
  "basis" -> {j1, j2}, "source_basis" -> {j1, j2},
  "variables" -> {x}, "regulator" -> eps,
  "convention" -> "old_basis = transformation . new_basis",
  "method" -> <|"id" -> "tutorial-contract-fixture"|>,
  "candidate_group_pool" -> <|"declared" -> 1, "eligible" -> 1,
    "remaining" -> 0, "unconsumed_candidates" -> 0, "pool_exhausted" -> True|>,
  "candidates" -> {CANDIDATE_RECORD}
|>'''.replace("CANDIDATE_RECORD", CANDIDATE)


@unittest.skipUnless(KERNEL.is_file(), "requires CANON_WOLFRAM_KERNEL or WolframKernel")
class CoreContractIntegrationTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.run_root = Path(self.temporary.name)
        self.counter = 0
        self.inputs = {
            "sector_basis": (FIXTURES / "sector-basis.wl").read_text(),
            "sector_cut_de": (FIXTURES / "sector-cut-de.wl").read_text(),
            "core_candidates": CANDIDATES,
        }

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def run_check(
        self,
        updates: dict[str, str] | None = None,
        *,
        sector: dict[str, int] | None = None,
        expected: tuple[str, str] = ("PASS", "CORE_PASS"),
    ) -> dict:
        self.counter += 1
        directory = self.run_root / str(self.counter)
        directory.mkdir()
        payload = {}
        for name, text in (self.inputs | (updates or {})).items():
            path = directory / f"{name}.wl"
            path.write_text(text)
            payload[name] = {"type": "mathematica-expression", "path": str(path)}
        task = {
            "schema": "canon-neu/script-input/v1",
            "task_id": f"core-contract-{self.counter}",
            "step": "CHECK_CORE",
            "sector": sector or {"id": 3, "propagator_count": 2},
            "payload": payload,
        }
        input_path = directory / "input.json"
        input_path.write_text(json.dumps(task))
        output = directory / "output"
        environment = os.environ.copy()
        for name in (
            "OMP_NUM_THREADS", "MKL_NUM_THREADS", "NUMEXPR_NUM_THREADS",
            "OPENBLAS_NUM_THREADS", "VECLIB_MAXIMUM_THREADS", "USE_OPENMP",
        ):
            environment[name] = "1"
        completed = subprocess.run(
            [sys.executable, str(ROOT / "tests" / "wolfram_kernel_launcher.py"),
             str(KERNEL), "-noinit", "-noprompt", "-script",
             str(ROOT / "mma" / "CheckSectorCore.wls"), str(input_path), str(output)],
            text=True, capture_output=True, timeout=60, env=environment, cwd=ROOT,
        )
        # Match the existing method-card harness: OpenMP's shared-memory object
        # can disappear slightly after kernel exit. This pause is not a retry.
        time.sleep(2.0)
        result_path = output / "result.json"
        debug = f"stdout:\n{completed.stdout}\nstderr:\n{completed.stderr}"
        self.assertTrue(result_path.is_file(), debug)
        result = json.loads(result_path.read_text())
        self.assertEqual(completed.returncode, 1 if expected[0] == "ERROR" else 0, debug)
        self.assertEqual((result["status"], result["code"]), expected, result)
        if expected[0] == "ERROR":
            self.assertEqual(result["artifacts"], {})
            self.assertFalse((output / "core-transform.wl").exists())
            self.assertFalse(result["summary"]["pool_exhausted"])
            self.assertFalse(result["summary"]["repair_eligible"])
            self.assertEqual(result["summary"]["preferred_next_route"], "FIX_INPUT")
        return result

    def test_valid_provider_contract_and_legacy_cut_domain(self) -> None:
        result = self.run_check()
        self.assertEqual(result["summary"]["attempts"][0]["inverse_verification"],
                         "two_sided_exact_identity")
        cut = self.inputs["sector_cut_de"].replace(
            '  "coefficient_domain" -> "exact-rational-functions",\n', ""
        )
        self.run_check({"sector_cut_de": cut})

    def test_inverse_proposal_is_independently_verified_and_legacy_falls_back(self) -> None:
        wrong = CANDIDATES.replace('"full_new_basis_rows" -> {{1, -x}, {0, 1}}',
                                   '"full_new_basis_rows" -> IdentityMatrix[2]')
        result = self.run_check({"core_candidates": wrong})
        self.assertEqual(result["summary"]["attempts"][0]["inverse_verification"],
                         "symbolic_inverse")
        without = CANDIDATES.replace('  "full_new_basis_rows" -> {{1, -x}, {0, 1}},\n', '')
        result = self.run_check({"core_candidates": without})
        self.assertEqual(result["summary"]["attempts"][0]["inverse_verification"],
                         "symbolic_inverse")
        bad = CANDIDATES.replace('"transformed_matrices" -> {{{eps/x, eps/(1-x)}, {0, -eps/(1+x)}}}',
                                 '"transformed_matrices" -> {ConstantArray[0,{2,2}]}')
        result = self.run_check({"core_candidates": bad}, expected=("FAIL", "CORE_FAIL"))
        self.assertIn("gauge_residual", result["summary"]["attempts"][0]["rejection_signature"])

    def test_legacy_candidate_domain_is_inferred_from_exact_entries(self) -> None:
        candidates = CANDIDATES.replace(
            '  "coefficient_domain" -> "exact-rational-functions",\n', ""
        )
        result = self.run_check({"core_candidates": candidates})
        self.assertTrue(result["summary"]["coefficient_domain_inferred"])
        self.assertEqual(result["summary"]["coefficient_domain"], "exact-rational-functions")
        self.assertIsNone(result["summary"]["declared_coefficient_domain"])

    def test_identity_and_order_mismatches_cannot_pass_valid_algebra(self) -> None:
        mutations = (
            ('"family_id" -> "fixture-libra-tutorial-1"', '"family_id" -> "other-family"'),
            ('"basis_id" -> "fixture-sector-3-basis-v1"', '"basis_id" -> "other-basis"'),
            ('"id" -> 3', '"id" -> 7'),
            ('"basis" -> {j1, j2}', '"basis" -> {j2, j1}'),
        )
        for name in self.inputs:
            for old, new in mutations:
                with self.subTest(artifact=name, replacement=new):
                    self.assertIn(old, self.inputs[name])
                    self.run_check(
                        {name: self.inputs[name].replace(old, new)},
                        expected=("ERROR", "INVALID_INPUT"),
                    )
        self.run_check(sector={"id": 7, "propagator_count": 2},
                       expected=("ERROR", "INVALID_INPUT"))

    def test_candidate_coordinate_identity_schema_and_convention(self) -> None:
        mutations = (
            ('"variables" -> {x}', '"variables" -> {y}'),
            ('"regulator" -> eps', '"regulator" -> eta'),
            ("canon-neu/core-candidates/v1", "canon-neu/core-transform/v1"),
            ("old_basis = transformation . new_basis", "new_basis = transformation . old_basis"),
            ('"source_basis" -> {j1, j2}', '"source_basis" -> {j1, j3}'),
        )
        for old, new in mutations:
            with self.subTest(replacement=new):
                self.run_check({"core_candidates": CANDIDATES.replace(old, new)},
                               expected=("ERROR", "INVALID_INPUT"))

    def test_cut_shape_and_coordinate_contract(self) -> None:
        mutations = (
            ('"variables" -> {x}', '"variables" -> {x, x}'),
            ('"variables" -> {x}', '"variables" -> {eps}'),
            ('"variables" -> {x}', '"variables" -> {1}'),
            ('"regulator" -> eps', '"regulator" -> 1'),
            ('"basis" -> {j1, j2}', '"basis" -> {j1}'),
            ("canon-neu/sector-cut-de/v1", "canon-neu/ordered-master-de/v1"),
        )
        for old, new in mutations:
            with self.subTest(replacement=new):
                self.run_check({"sector_cut_de": self.inputs["sector_cut_de"].replace(old, new)},
                               expected=("ERROR", "INVALID_DIFFERENTIAL_SYSTEM"))

    def test_pool_counts_and_ids_are_validated_before_selection(self) -> None:
        mutations = (
            ('"eligible" -> 1', '"eligible" -> 2'),
            ('"remaining" -> 0', '"remaining" -> -1'),
            ('"declared" -> 1', '"declared" -> 0'),
            ('"pool_exhausted" -> True', '"pool_exhausted" -> "true"'),
            ('"unconsumed_candidates" -> 0', '"unconsumed_candidates" -> 1'),
            ('"candidate_id" -> "tutorial:1"', '"candidate_id" -> ""'),
        )
        for old, new in mutations:
            with self.subTest(replacement=new):
                self.run_check({"core_candidates": CANDIDATES.replace(old, new)},
                               expected=("ERROR", "INVALID_INPUT"))
        duplicate = CANDIDATES.replace(CANDIDATE, f"{CANDIDATE}, {CANDIDATE}")
        duplicate = duplicate.replace('"declared" -> 1', '"declared" -> 2')
        duplicate = duplicate.replace('"eligible" -> 1', '"eligible" -> 2')
        self.run_check({"core_candidates": duplicate}, expected=("ERROR", "INVALID_INPUT"))

    def test_candidate_matrix_shape_and_exactness(self) -> None:
        mutations = (
            ('"transformation" -> {{1, x}, {0, 1}}', '"transformation" -> {{1}}'),
            ('"transformation" -> {{1, x}, {0, 1}}', '"transformation" -> {{1., x}, {0, 1}}'),
            ('"transformation" -> {{1, x}, {0, 1}}', '"transformation" -> {{Indeterminate, x}, {0, 1}}'),
            ('"transformed_matrices" -> {{{eps/x, eps/(1-x)}, {0, -eps/(1+x)}}}',
             '"transformed_matrices" -> {}'),
            ('"full_new_basis_rows" -> {{1, -x}, {0, 1}}', '"full_new_basis_rows" -> {{1, -x}}'),
        )
        for old, new in mutations:
            with self.subTest(replacement=new):
                self.run_check({"core_candidates": CANDIDATES.replace(old, new)},
                               expected=("ERROR", "INVALID_INPUT"))

    def test_algebraic_route_remains_accepted(self) -> None:
        basis = self.inputs["sector_basis"].replace("{j1, j2}", "{j1}")
        cut = '''<|"schema" -> "canon-neu/sector-cut-de/v1",
          "sector" -> <|"id" -> 3, "propagator_count" -> 2|>,
          "family_id" -> "fixture-libra-tutorial-1", "basis_id" -> "fixture-sector-3-basis-v1",
          "coefficient_domain" -> "exact-algebraic-functions", "basis" -> {j1},
          "variables" -> {x}, "regulator" -> eps,
          "matrices" -> {{{1/(2 x) + eps/Sqrt[x]}}}|>'''
        candidate = '''<|"candidate_id" -> "algebraic:1", "construction_rejection" -> None,
          "transformation" -> {{Sqrt[x]}}, "full_new_basis_rows" -> {{1/Sqrt[x]}},
          "transformed_matrices" -> {{{eps/Sqrt[x]}}}|>'''
        candidates = CANDIDATES.replace(CANDIDATE, candidate).replace("{j1, j2}", "{j1}")
        candidates = candidates.replace("exact-rational-functions", "exact-algebraic-functions")
        self.run_check({"sector_basis": basis, "sector_cut_de": cut, "core_candidates": candidates})
        legacy = candidates.replace('  "coefficient_domain" -> "exact-algebraic-functions",\n', "")
        result = self.run_check({"sector_basis": basis, "sector_cut_de": cut, "core_candidates": legacy})
        self.assertTrue(result["summary"]["coefficient_domain_inferred"])
        self.assertEqual(result["summary"]["coefficient_domain"], "exact-algebraic-functions")
        mislabeled = candidates.replace("exact-algebraic-functions", "exact-rational-functions")
        result = self.run_check({"sector_basis": basis, "sector_cut_de": cut, "core_candidates": mislabeled},
                               expected=("ERROR", "INVALID_INPUT"))
        self.assertFalse(result["summary"]["repair_eligible"])

    def test_transcendental_gauge_cannot_claim_an_algebraic_domain(self) -> None:
        basis = self.inputs["sector_basis"].replace("{j1, j2}", "{j1}")
        cut = self.inputs["sector_cut_de"].replace("{j1, j2}", "{j1}")
        start = cut.index('"matrices" ->')
        cut = cut[:start] + '"matrices" -> {{{0}}}|>'
        for domain in ('"exact-algebraic-functions"', None):
            with self.subTest(domain=domain):
                candidate = '''<|"candidate_id" -> "transcendental:1", "construction_rejection" -> None,
                  "transformation" -> {{Exp[-eps x]}}, "full_new_basis_rows" -> {{Exp[eps x]}},
                  "transformed_matrices" -> {{{eps}}}|>'''
                candidates = CANDIDATES.replace(CANDIDATE, candidate).replace("{j1, j2}", "{j1}")
                if domain is None:
                    candidates = candidates.replace('  "coefficient_domain" -> "exact-rational-functions",\n', "")
                else:
                    candidates = candidates.replace('"exact-rational-functions"', domain)
                result = self.run_check({"sector_basis": basis, "sector_cut_de": cut,
                                         "core_candidates": candidates}, expected=("ERROR", "INVALID_INPUT"))
                self.assertFalse(result["summary"]["pool_exhausted"])
                self.assertFalse(result["summary"]["repair_eligible"])

    def test_expression_domain_accepts_algebraic_roots_and_rejects_transcendentals(self) -> None:
        script = self.run_root / "domain.wls"
        script.write_text('''Get[LIBRARY];
good = {1/3, (x + I)/(1-x), Sqrt[x], x^(2/3),
  Root[#^5 - # + 1 &, 1], Root[#^3 + x # + 1 &, 1],
  AlgebraicNumber[Sqrt[2], {1, 1}]};
bad = {Exp[x], Log[x], Sin[x], x^eps, Pi, 1.2, Infinity, f[x]};
ok = And @@ (CanonMethodCard`ExactAlgebraicExpressionQ /@ good) &&
  !Or @@ (CanonMethodCard`ExactAlgebraicExpressionQ /@ bad);
Print[InputForm[{ok, CanonMethodCard`ExactAlgebraicExpressionQ /@ good,
  CanonMethodCard`ExactAlgebraicExpressionQ /@ bad}]];
Quit[If[TrueQ[ok], 0, 1]];
'''.replace("LIBRARY", json.dumps(str(ROOT / "mma/lib/MethodCardCore.wl"))))
        environment = os.environ.copy()
        environment["OMP_NUM_THREADS"] = "1"
        completed = subprocess.run([sys.executable, str(ROOT / "tests/wolfram_kernel_launcher.py"),
            str(KERNEL), "-noinit", "-noprompt", "-script", str(script)], cwd=ROOT,
            env=environment, text=True, capture_output=True, timeout=30)
        time.sleep(2.0)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)

    def test_full_source_basis_can_include_lower_sectors(self) -> None:
        candidates = CANDIDATES.replace('"source_basis" -> {j1, j2}',
                                        '"source_basis" -> {lower, j1, j2}')
        candidates = candidates.replace('"full_new_basis_rows" -> {{1, -x}, {0, 1}}',
                                        '"full_new_basis_rows" -> {{2, 1, -x}, {0, 0, 1}}')
        self.run_check({"core_candidates": candidates})

    def test_rejection_signatures_and_exhaustion_keep_their_meaning(self) -> None:
        rejected = '<|"candidate_id" -> "rejected:1", "construction_rejection" -> "rank_deficient"|>'
        candidates = CANDIDATES.replace(CANDIDATE, rejected)
        result = self.run_check({"core_candidates": candidates}, expected=("FAIL", "CORE_FAIL"))
        self.assertTrue(result["summary"]["repair_eligible"])
        self.assertEqual(result["summary"]["attempts"][0]["rejection_signature"], ["rank_deficient"])
        incomplete = candidates.replace('"pool_exhausted" -> True', '"pool_exhausted" -> False')
        result = self.run_check({"core_candidates": incomplete},
                                expected=("INCONCLUSIVE", "CANDIDATE_BUDGET_EXHAUSTED"))
        self.assertFalse(result["summary"]["repair_eligible"])
        empty = candidates.replace(rejected, "").replace('"declared" -> 1', '"declared" -> 0')
        empty = empty.replace('"eligible" -> 1', '"eligible" -> 0')
        self.run_check({"core_candidates": empty}, expected=("FAIL", "CORE_FAIL"))

    def test_failed_algebra_continues_to_next_stable_candidate(self) -> None:
        bad = CANDIDATE.replace('"tutorial:1"', '"bad:1"').replace(
            '"transformation" -> {{1, x}, {0, 1}}', '"transformation" -> IdentityMatrix[2]'
        )
        candidates = CANDIDATES.replace(CANDIDATE, f"{bad}, {CANDIDATE}")
        candidates = candidates.replace('"declared" -> 1', '"declared" -> 2')
        candidates = candidates.replace('"eligible" -> 1', '"eligible" -> 2')
        result = self.run_check({"core_candidates": candidates})
        self.assertEqual(result["summary"]["attempted_candidate_ids"], ["bad:1", "tutorial:1"])
        self.assertEqual(result["summary"]["selected_candidate_id"], "tutorial:1")
        self.assertIn("gauge_residual", result["summary"]["attempts"][0]["rejection_signature"])

    def test_malformed_candidates_do_not_block_a_valid_candidate(self) -> None:
        bad = CANDIDATE.replace('"tutorial:1"', '"bad:1"').replace(
            '"transformation" -> {{1, x}, {0, 1}}', '"transformation" -> {{1}}'
        )
        for records, attempted in ((f"{CANDIDATE}, {bad}", ["tutorial:1"]),
                                   (f"{bad}, {CANDIDATE}", ["bad:1", "tutorial:1"])):
            with self.subTest(attempted=attempted):
                candidates = CANDIDATES.replace(CANDIDATE, records)
                candidates = candidates.replace('"declared" -> 1', '"declared" -> 2')
                candidates = candidates.replace('"eligible" -> 1', '"eligible" -> 2')
                result = self.run_check({"core_candidates": candidates})
                self.assertEqual(result["summary"]["selected_candidate_id"], "tutorial:1")
                self.assertEqual(result["summary"]["attempted_candidate_ids"], attempted)
                self.assertFalse(result["summary"]["repair_eligible"])
                self.assertEqual(result["summary"]["remaining_candidate_groups"], 2-len(attempted))
                if len(attempted) == 2:
                    self.assertEqual(result["summary"]["invalid_candidate_ids"], ["bad:1"])
                    self.assertFalse(result["summary"]["attempts"][0]["input_valid"])

    def test_invalid_candidate_pool_is_not_mathematical_exhaustion(self) -> None:
        bad = CANDIDATE.replace('"transformation" -> {{1, x}, {0, 1}}',
                                '"transformation" -> {{1}}')
        result = self.run_check({"core_candidates": CANDIDATES.replace(CANDIDATE, bad)},
                               expected=("ERROR", "INVALID_INPUT"))
        self.assertEqual(result["summary"]["invalid_candidate_ids"], ["tutorial:1"])
        self.assertFalse(result["summary"]["pool_exhausted"])
        self.assertFalse(result["summary"]["repair_eligible"])
        self.assertEqual(result["summary"]["preferred_next_route"], "FIX_INPUT")


if __name__ == "__main__":
    unittest.main()
