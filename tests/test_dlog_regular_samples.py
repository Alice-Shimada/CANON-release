"""Public canonical checks for a logarithmic divisor on the old first sample."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class DLogRegularSampleIntegrationTest(unittest.TestCase):
    def setUp(self):
        saved = os.environ.get("CANON_TEST_DLOG_OUTPUT")
        if saved:
            self.directory = Path(saved) / self._testMethodName
            self.directory.mkdir(parents=True)
            self.temporary = None
        else:
            self.temporary = tempfile.TemporaryDirectory()
            self.directory = Path(self.temporary.name)

    def tearDown(self):
        if self.temporary:
            self.temporary.cleanup()

    def check(self, coefficients):
        sector = {"id": 1, "propagator_count": 1}
        common = (
            '"sector" -> <|"id" -> 1, "propagator_count" -> 1|>, '
            '"family_id" -> "regular-sample-fixture", '
            '"current_basis_id" -> "fixture/raw", "accepted_prefix_id" -> Null, '
            '"coefficient_domain" -> "exact-rational-functions", '
            '"source_basis" -> {j}, "variables" -> {x,y,z,w}, "regulator" -> eps, '
            '"alphabet" -> {z-x-y}, '
            '"convention" -> "old_prefix_basis = full_transformation . candidate_prefix_basis"'
        )
        matrices = "{" + ",".join("{{" + value + "}}" for value in coefficients) + "}"
        full = self.directory / "full.wl"
        full.write_text(
            '<|"schema" -> "canon-neu/full-prefix-candidates/v1", ' + common + ', '
            '"source_matrices" -> ' + matrices + ', '
            '"block_boundaries" -> <|"lower_dimension" -> 0, "current_dimension" -> 1|>|>\n'
        )
        transform = self.directory / "transform.wl"
        transform.write_text(
            '<|"schema" -> "canon-neu/sector-transform/v1", ' + common + ', '
            '"candidate_id" -> "identity", "member_candidate_ids" -> {"identity"}, '
            '"transformation" -> {{1}}, "transformed_matrices" -> ' + matrices + ', '
            '"method" -> "generic-test-fixture"|>\n'
        )
        request = self.directory / "input.json"
        request.write_text(json.dumps({
            "schema": "canon-neu/script-input/v1", "task_id": self._testMethodName,
            "step": "CHECK_CANONICAL", "sector": sector,
            "payload": {
                "full_sector_de": {"type": "mathematica-expression", "path": str(full)},
                "sector_transform": {"type": "mathematica-expression", "path": str(transform)},
            },
        }, indent=2) + "\n")
        command = [sys.executable, str(ROOT / "run_step.py"), str(request), str(self.directory / "check")]
        selected = os.environ.get("CANON_COMPONENTS", "")
        components = json.loads(selected) if selected.lstrip().startswith("[") else ([selected] if selected else [])
        for component in components:
            command.extend(["--components", component])
        description = subprocess.run(command + ["--describe"], capture_output=True, text=True, check=True)
        process = subprocess.run(command, capture_output=True, text=True)
        (self.directory / "invocation.json").write_text(json.dumps({
            "command": command, "description": json.loads(description.stdout),
            "returncode": process.returncode, "stdout": process.stdout, "stderr": process.stderr,
        }, indent=2) + "\n")
        self.assertEqual(process.returncode, 0, process.stdout + process.stderr)
        self.assertNotRegex(process.stdout + process.stderr, r"(?:Power::infy|RowReduce::|Part::|LinearSolve::)")
        return json.loads((self.directory / "check/result.json").read_text())

    def test_constant_residue_at_old_singular_sample(self):
        result = self.check(["-eps/(z-x-y)", "-eps/(z-x-y)", "eps/(z-x-y)", "0"])
        self.assertEqual((result["status"], result["code"]), ("PASS", "CANONICAL_PASS"))
        self.assertTrue(all(result["summary"]["full_checks"].values()))
        self.assertTrue(all(result["summary"]["core_checks"].values()))
        self.assertIn("canonical_sector_de", result["artifacts"])

    def test_exact_flat_higher_pole_is_rejected(self):
        result = self.check(["eps/(z-x-y)^2", "eps/(z-x-y)^2", "-eps/(z-x-y)^2", "0"])
        self.assertEqual((result["status"], result["code"]), ("FAIL", "CORE_FAIL"))
        self.assertEqual(result["artifacts"], {})
        expected = {
            "exact_gauge": True, "flat_connection": True, "epsilon_factorized": True,
            "declared_dlog_alphabet": False, "upper_right_zero": True,
        }
        self.assertEqual(result["summary"]["full_checks"], expected)


if __name__ == "__main__":
    unittest.main()
