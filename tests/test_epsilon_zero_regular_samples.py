"""Generic public regressions for epsilon-zero finite-field sample boundaries."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def make_fixture(directory, variables, matrices, dimension, letters=None, prime=None):
    directory.mkdir(parents=True, exist_ok=True)
    sector = {"id": 3, "propagator_count": 2}
    basis = "{" + ",".join("j" + str(i + 1) for i in range(dimension)) + "}"
    common = ('"sector" -> <|"id" -> 3, "propagator_count" -> 2|>, '
              '"family_id" -> "finite-field-sample-fixture", "basis_id" -> "fixture/raw", '
              '"basis" -> ' + basis)
    basis_path = directory / "basis.wl"
    basis_path.write_text('<|"schema" -> "canon-neu/sector-basis/v1", ' + common + '|>\n')
    cut_path = directory / "cut.wl"
    cut_path.write_text('<|"schema" -> "canon-neu/sector-cut-de/v1", ' + common + ', '
        '"variables" -> {' + ",".join(variables) + '}, "regulator" -> eps, '
        '"coefficient_domain" -> "exact-algebraic-functions", "matrices" -> {' + ",".join(matrices) + '}|>\n')
    payload = {"sector_cut_de": {"type": "mathematica-expression", "path": str(cut_path)}}
    if letters:
        alphabet = directory / "alphabet.wl"
        alphabet.write_text('<|"schema" -> "canon-neu/declared-alphabet/v1", "letters" -> {' + ",".join(letters) + '}|>\n')
        payload["declared_alphabet"] = {"type": "mathematica-expression", "path": str(alphabet)}
    if prime is not None:
        payload["method_options"] = {"prime": prime}
    request = directory / "input.json"
    request.write_text(json.dumps({"schema": "canon-neu/script-input/v1", "task_id": directory.name,
        "step": "SEARCH_CORE", "sector": sector, "payload": payload}, indent=2) + "\n")
    return request, basis_path, cut_path


def diagonal_connection(variables, divisor, root=False):
    result = []
    for v in variables:
        canonical = "eps/x" if v == "x" else "0"
        coefficient = f"-Together[D[({divisor}),{v}]/({divisor})]" + ("/2" if root else "")
        result.append("{{" + coefficient + "+" + canonical + ",0},{0," +
                      (coefficient + "+" if root else "") + canonical + "}}")
    return result


def nilpotent_connection(variables, coefficients, dimension=3):
    return ["ReplacePart[ConstantArray[0,{" + str(dimension) + "," + str(dimension) +
            "}],{1,2}->(" + value + ")]" for value in coefficients]


def invoke(root, request, output, method=None):
    command = [sys.executable, str(root / "run_step.py"), str(request), str(output)]
    selection = os.environ.get("CANON_COMPONENTS", "")
    components = json.loads(selection) if selection.lstrip().startswith("[") else ([selection] if selection else [])
    for component in components:
        command.extend(["--components", component])
    if method:
        command.extend(["--method", method])
    description = subprocess.run(command + ["--describe"], capture_output=True, text=True, check=True)
    process = subprocess.run(command, capture_output=True, text=True)
    result_path = output / "result.json"
    result = json.loads(result_path.read_text()) if result_path.is_file() else None
    receipt = {"command": command, "description": json.loads(description.stdout),
        "returncode": process.returncode, "stdout": process.stdout, "stderr": process.stderr, "result": result}
    output.parent.mkdir(parents=True, exist_ok=True)
    (output.parent / (output.name + "-invocation.json")).write_text(json.dumps(receipt, indent=2) + "\n")
    return receipt


class EpsilonZeroRegularSampleTest(unittest.TestCase):
    def setUp(self):
        saved = os.environ.get("CANON_TEST_EPSILON_OUTPUT")
        self.temporary = None if saved else tempfile.TemporaryDirectory()
        self.directory = Path(saved or self.temporary.name) / self._testMethodName
        self.directory.mkdir(parents=True)

    def tearDown(self):
        if self.temporary:
            self.temporary.cleanup()

    def provider(self, variables, matrices, dimension, letters=None, prime=None):
        self.request, self.basis, self.cut = make_fixture(self.directory, variables, matrices, dimension, letters, prime)
        record = invoke(ROOT, self.request, self.directory / "provider", "epsilon-zero")
        self.assertEqual(record["returncode"], 0, record)
        self.assertNotRegex(record["stdout"] + record["stderr"], r"(?:Power::infy|Infinity::indet|PowerMod::|NullSpace::|Mod::)")
        self.assertIsNotNone(record["result"], record)
        return record["result"]

    def core(self, result):
        candidate_path = self.directory / "provider" / result["artifacts"]["core_candidates"]["path"]
        request = self.directory / "core-input.json"
        request.write_text(json.dumps({"schema": "canon-neu/script-input/v1", "task_id": self._testMethodName + "-core",
            "step": "CHECK_CORE", "sector": {"id": 3, "propagator_count": 2}, "payload": {
                "sector_basis": {"type": "mathematica-expression", "path": str(self.basis)},
                "sector_cut_de": {"type": "mathematica-expression", "path": str(self.cut)},
                "core_candidates": {"type": "mathematica-expression", "path": str(candidate_path)}}}, indent=2) + "\n")
        record = invoke(ROOT, request, self.directory / "core")
        self.assertEqual(record["returncode"], 0, record)
        self.assertEqual((record["result"]["status"], record["result"]["code"]), ("PASS", "CORE_PASS"))
        return candidate_path.read_text()

    def test_first_prime_divisor(self):
        variables = ["x", "y", "z", "w"]
        result = self.provider(variables, diagonal_connection(variables, "z-x-y"), 2)
        self.assertEqual(result["status"], "PROVISIONAL")
        candidate = self.core(result)
        self.assertIn('"prime" -> 2147483647', candidate)
        self.assertIn('"regular_sample_count" -> 7', candidate)
        self.assertIn('"sample_attempts" -> 8', candidate)

    def test_removable_regulator_pole_matches_cancelled(self):
        directory = self.directory
        self.directory = directory / "removable"
        result = self.provider(["x"], ["{{(eps+eps^2)/(eps*x)}}"], 1)
        self.assertEqual(result["status"], "PROVISIONAL")
        removable = self.core(result)

        self.directory = directory / "cancelled"
        result = self.provider(["x"], ["{{(1+eps)/x}}"], 1)
        self.assertEqual(result["status"], "PROVISIONAL")
        self.assertEqual(self.core(result), removable)

    def test_genuine_regulator_pole_is_not_removed(self):
        # A genuine pole remains outside the provider's regular-input contract.
        request, _, _ = make_fixture(self.directory, ["x"], ["{{1/(eps*x)}}"], 1)
        record = invoke(ROOT, request, self.directory / "provider", "epsilon-zero")
        self.assertEqual(record["returncode"], 0, record)
        result = record["result"]
        self.assertEqual(result["status"], "INCONCLUSIVE")
        self.assertEqual(result["artifacts"], {})
        self.assertFalse(result["summary"]["nonexistence_proved"])
        self.assertFalse((self.directory / "provider/core-candidates.wl").exists())

    def test_multiple_bad_points(self):
        variables = ["x", "y"]
        divisor = "(x-(2/3)y)(x-(5/7)y)(x-(11/13)y)"
        result = self.provider(variables, diagonal_connection(variables, divisor), 2)
        candidate = self.core(result)
        self.assertIn('"regular_sample_count" -> 10', candidate)
        self.assertIn('"sample_attempts" -> 13', candidate)

    def test_modular_bad_denominator_is_skipped(self):
        result = self.provider(["x"], diagonal_connection(["x"], "x"), 2, prime=7)
        candidate = self.core(result)
        self.assertIn('"prime" -> 7', candidate)
        self.assertIn('"regular_sample_count" -> 7', candidate)
        self.assertIn('"sample_attempts" -> 8', candidate)

    def test_algebraic_normalized_prefactor(self):
        variables = ["x", "y", "z", "w"]
        divisor = "(z-x-y)(w+x)"
        result = self.provider(variables, diagonal_connection(variables, divisor, root=True), 2,
                               ["Sqrt[(z-x-y)(w+x)]"])
        self.assertEqual(result["status"], "PROVISIONAL")
        self.core(result)

    def assert_sampling_incomplete(self, result, rejection):
        self.assertEqual((result["status"], result["code"]), ("INCONCLUSIVE", "OUT_OF_SCOPE"))
        self.assertEqual(result["artifacts"], {})
        self.assertEqual(result["summary"]["reason"], "regular finite-field sampling incomplete")
        self.assertFalse(result["summary"]["nonexistence_proved"])
        failed = result["summary"]["sampling_failures"][0]
        self.assertLess(failed["regular_sample_count"], failed["requested_sample_count"])
        self.assertGreater(failed["rejected_samples"].get(rejection, 0), 0)

    def test_noninvertible_constant_denominator(self):
        result = self.provider(["x"], nilpotent_connection(["x"], ["1/(7 x)"]), 3, prime=7)
        self.assert_sampling_incomplete(result, "noninvertible_modular_denominator")

    def test_unsupported_modular_coefficient_domain(self):
        result = self.provider(["x"], nilpotent_connection(["x"], ["Sqrt[2]/x"]), 3)
        self.assert_sampling_incomplete(result, "unsupported_modular_coefficient_domain")

    def test_bounded_regular_sample_exhaustion(self):
        variables = ["x", "y"]
        coefficients = [f"Sum[D[x/y,{v}]/(x/y-Prime[2 k+1]/Prime[2 k+2]),{{k,0,55}}]" for v in variables]
        result = self.provider(variables, nilpotent_connection(variables, coefficients), 3)
        self.assert_sampling_incomplete(result, "undefined_exact_sample")
        failed = result["summary"]["sampling_failures"][0]
        self.assertEqual((failed["requested_sample_count"], failed["sample_attempts"], failed["regular_sample_count"]), (7, 56, 0))

    def test_sample_fit_is_not_exact_horizontal_verification(self):
        variables = ["x", "y"]
        function = "Times@@Table[(x/y-Prime[2 k+1]/Prime[2 k+2])^2,{k,0,6}]"
        coefficients = [f"D[({function}),{v}]" for v in variables]
        result = self.provider(variables, nilpotent_connection(variables, coefficients), 3)
        self.assertEqual((result["status"], result["code"]), ("INCONCLUSIVE", "METHOD_EXHAUSTED"))
        self.assertEqual(result["artifacts"], {})
        self.assertFalse(result["summary"]["nonexistence_proved"])
        self.assertEqual(result["summary"]["sampling_failures"], [])

    def test_malformed_prime_is_rejected_without_substitution(self):
        result = self.provider(["x"], diagonal_connection(["x"], "x"), 2, prime=9)
        self.assertEqual((result["status"], result["code"]), ("ERROR", "INVALID_METHOD_OPTIONS"))
        self.assertEqual(result["artifacts"], {})


if __name__ == "__main__":
    unittest.main()
