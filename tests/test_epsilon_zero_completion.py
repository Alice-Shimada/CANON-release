"""Public completion regressions; finite proposals still need CHECK_CORE."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from tests.test_epsilon_zero_regular_samples import make_fixture, invoke

ROOT = Path(__file__).resolve().parents[1]


class EpsilonZeroCompletionTest(unittest.TestCase):
    def setUp(self):
        saved = os.environ.get("CANON_TEST_COMPLETION_OUTPUT")
        self.temporary = None if saved else tempfile.TemporaryDirectory()
        self.directory = Path(saved or self.temporary.name) / self._testMethodName
        self.directory.mkdir(parents=True)

    def tearDown(self):
        if self.temporary:
            self.temporary.cleanup()

    def provider(self, variables, matrices):
        self.request, self.basis, self.cut = make_fixture(self.directory, variables, matrices, 2)
        record = invoke(ROOT, self.request, self.directory / "provider", "epsilon-zero")
        self.assertEqual(record["returncode"], 0, record)
        self.assertNotRegex(record["stdout"] + record["stderr"], r"(?:Power::infy|Infinity::indet|Inverse::sing|NullSpace::|Part::)")
        self.assertIsNotNone(record["result"], record)
        result = record["result"]
        if result["status"] == "PROVISIONAL":
            candidate = self.directory / "provider" / result["artifacts"]["core_candidates"]["path"]
            self.assertNotIn("Inverse[", candidate.read_text())
            self.candidate = candidate
        return result

    def core(self, candidate=None):
        request = self.directory / "core-input.json"
        request.write_text(json.dumps({"schema": "canon-neu/script-input/v1", "task_id": self._testMethodName + "-core",
            "step": "CHECK_CORE", "sector": {"id": 3, "propagator_count": 2}, "payload": {
                "sector_basis": {"type": "mathematica-expression", "path": str(self.basis)},
                "sector_cut_de": {"type": "mathematica-expression", "path": str(self.cut)},
                "core_candidates": {"type": "mathematica-expression", "path": str(candidate or self.candidate)}}}, indent=2) + "\n")
        record = invoke(ROOT, request, self.directory / "core")
        self.assertEqual(record["returncode"], 0, record)
        self.assertIsNotNone(record["result"], record)
        return record["result"]

    def require_core_pass_and_meromorphic_frame(self):
        result = self.core()
        self.assertEqual((result["status"], result["code"]), ("PASS", "CORE_PASS"))
        attempt = result["summary"]["attempts"][0]
        for flag in ("invertible", "exact_gauge", "flat_connection", "epsilon_factorized"):
            self.assertTrue(attempt[flag])
        inspector = self.directory / "inspect.wls"
        inspector.write_text('Get[' + json.dumps(str(ROOT / "mma/lib/MethodCardCore.wl")) + '];\n'
            '{path,out}=CanonMethodCard`ScriptArguments[];\n'
            'c=CanonMethodCard`ReadWLData[path];r=First[c["candidates"]]["new_basis_rows"];'
            't=First[c["candidates"]]["transformation"];e=c["regulator"];\n'
            'Export[out,<|"generic_row_invertible"->(Together[Det[r]]=!=0),'
            '"row_determinant_vanishes_at_epsilon_zero"->(Together[Det[r]/.e->0]===0),'
            '"transformation_has_epsilon_zero_pole"->(Together[Denominator[Together[Det[t]]]/.e->0]===0),'
            '"evaluated_inverse"->FreeQ[t,_Inverse]|>,"RawJSON"];Quit[0];\n')
        output = self.directory / "meromorphic-facts.json"
        command = [os.environ.get("CANON_WOLFRAMSCRIPT", "wolframscript"), "-file", str(inspector), str(self.candidate), str(output)]
        process = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(process.returncode, 0, process.stdout + process.stderr)
        facts = json.loads(output.read_text())
        self.assertTrue(all(facts.values()), facts)

    def test_original_first_entry_zero_is_a_finite_rejected_proposal(self):
        result = self.provider(["w", "x", "y"],
            ["{{0,0},{eps/w,0}}", "{{0,0},{-y/x^2,0}}", "{{0,0},{1/x,0}}"])
        self.assertEqual(result["status"], "PROVISIONAL")
        result = self.core()
        self.assertEqual((result["status"], result["code"]), ("FAIL", "CORE_FAIL"))
        attempt = result["summary"]["attempts"][0]
        self.assertTrue(attempt["invertible"])
        self.assertTrue(attempt["exact_gauge"])
        self.assertTrue(attempt["flat_connection"])
        self.assertEqual(attempt["rejection_signature"], ["not_epsilon_factorized"])

    def test_later_usable_entry_preserves_epsilon_singular_completion(self):
        self.provider(["w", "x"], ["{{0,0},{0,0}}", "{{0,0},{1/x,0}}"])
        self.require_core_pass_and_meromorphic_frame()

    def test_rational_regulator_profile_is_supported(self):
        self.provider(["x"], ["{{0,0},{(1+eps)/x,0}}"])
        self.require_core_pass_and_meromorphic_frame()

    def require_limit(self, result, reason):
        self.assertEqual((result["status"], result["code"]), ("INCONCLUSIVE", "OUT_OF_SCOPE"))
        self.assertEqual(result["artifacts"], {})
        self.assertEqual(result["summary"]["reason"], reason)
        self.assertFalse(result["summary"]["nonexistence_proved"])
        self.assertFalse((self.directory / "provider/core-candidates.wl").exists())

    def test_unsupported_leading_primitive_is_short_circuited(self):
        result = self.provider(["x"], ["{{0,eps/x},{1/x,0}}"])
        self.require_limit(result, "leading_primitive_unsupported")

    def test_kinematics_dependent_opposite_profile_is_a_method_limit(self):
        result = self.provider(["x"], ["{{0,0},{(1+eps x)/x,0}}"])
        self.require_limit(result, "opposite_entry_profile_unsupported")

    def test_independent_checker_rejects_identically_singular_transform(self):
        self.request, self.basis, self.cut = make_fixture(self.directory, ["x"], ["{{0,0},{1/x,0}}"], 2)
        candidate = self.directory / "singular-candidates.wl"
        candidate.write_text('<|"schema"->"canon-neu/core-candidates/v1",'
            '"sector"-><|"id"->3,"propagator_count"->2|>,'
            '"family_id"->"finite-field-sample-fixture","basis_id"->"fixture/raw",'
            '"basis"->{j1,j2},"source_basis"->{j1,j2},"variables"->{x},"regulator"->eps,'
            '"coefficient_domain"->"exact-algebraic-functions",'
            '"convention"->"old_basis = transformation . new_basis",'
            '"method"-><|"id"->"negative-fixture"|>,'
            '"candidate_group_pool"-><|"declared"->1,"eligible"->1,"remaining"->0,"pool_exhausted"->True|>,'
            '"candidates"->{<|"candidate_id"->"singular","construction_rejection"->None,'
            '"transformation"->{{0,0},{0,0}},"transformed_matrices"->{{{0,0},{0,0}}}|>}|>\n')
        result = self.core(candidate)
        self.assertEqual((result["status"], result["code"]), ("FAIL", "CORE_FAIL"))
        self.assertEqual(result["summary"]["attempts"][0]["rejection_signature"], ["singular_transformation"])


if __name__ == "__main__":
    unittest.main()
