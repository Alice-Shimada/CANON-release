"""Exact method regressions and the public diagnosis -> proposal -> check route."""
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
FIXTURES = ROOT / "tests/fixtures/residue-balance"
KERNEL = os.environ.get("CANON_WOLFRAM_KERNEL") or shutil.which("WolframKernel")
WLS = os.environ.get("CANON_WOLFRAMSCRIPT") or shutil.which("wolframscript")


@unittest.skipUnless(KERNEL and WLS, "requires declared WolframKernel and wolframscript")
class ResidueBalanceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="canon residue balance ")
        cls.root = Path(os.environ.get("CANON_TEST_RESIDUE_OUTPUT_ROOT", cls.temporary.name))
        cls.root.mkdir(parents=True, exist_ok=True)
        cls.env = os.environ.copy()
        cls.env.pop("CANON_COMPONENTS", None)
        cls.env.update({"OMP_NUM_THREADS": "1", "MKL_NUM_THREADS": "1", "OPENBLAS_NUM_THREADS": "1"})
        cls.env["CANON_WOLFRAMSCRIPT"] = str(WLS)
        cls.units = cls.root / "units"
        cls.unit_process = subprocess.run(
            [sys.executable, str(ROOT / "tests/wolfram_kernel_launcher.py"), str(KERNEL),
             "-noinit", "-noprompt", "-script", str(ROOT / "tests/RunResidueBalanceUnitTests.wls"),
             str(cls.units)], cwd=ROOT, env=cls.env, capture_output=True, text=True, timeout=90,
        )

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def invoke(self, name, step, *, cut=None, basis=None, options=None, candidates=None, code=0):
        source = cut or FIXTURES / "g3382-cut.wl"
        basis = basis or FIXTURES / "g3382-basis.wl"
        sector = {"id": 3, "propagator_count": 2} if source.name.startswith("nilpotent") else {"id": 3382, "propagator_count": 7}
        sector = dict(reversed(list(sector.items())))  # Record key order is not sector order.
        payload = {"sector_cut_de": {"type": "mathematica-expression", "path": str(source)},
                   "sector_basis": {"type": "mathematica-expression", "path": str(basis)}}
        if options is not None:
            payload["method_options"] = options
        if candidates is not None:
            payload["core_candidates"] = {"type": "mathematica-expression", "path": str(candidates)}
        request = self.root / (name + ".json")
        request.write_text(json.dumps({"schema": "canon-neu/script-input/v1", "task_id": name,
                                       "step": step, "sector": sector, "payload": payload}))
        output = self.root / name
        command = [sys.executable, str(ROOT / "run_step.py"), str(request), str(output)]
        # Preserve the real task's ordered reducer + execution composition.
        for component in ("reducers/kira/components.json", "local-jobs/components.json"):
            command.extend(["--components", str(ROOT / "components" / component)])
        if step == "SEARCH_CORE":
            command.extend(["--method", "residue-balance"])
        completed = subprocess.run(command, cwd=ROOT, env=self.env, text=True, capture_output=True, timeout=90)
        self.assertEqual(completed.returncode, code, completed.stdout + completed.stderr)
        receipt = json.loads((output / "result.json").read_text())
        self.assertNotIn("::", completed.stdout + completed.stderr)
        return receipt, output

    def test_exact_unit_cases(self):
        self.assertEqual(self.unit_process.returncode, 0, self.unit_process.stdout + self.unit_process.stderr)
        facts = json.loads((self.units / "facts.json").read_text())
        self.assertGreaterEqual(len(facts), 25)
        self.assertTrue(all(facts.values()), facts)

    def test_g3382_public_route(self):
        diagnosis, _ = self.invoke("g-diagnosis", "DIAGNOSE_CORE")
        self.assertEqual((diagnosis["status"], diagnosis["code"]), ("PROVISIONAL", "CORE_DIAGNOSIS"))
        self.assertFalse(diagnosis["summary"]["nonexistence_proved"])
        proposal, directory = self.invoke("g-proposal", "SEARCH_CORE")
        self.assertEqual((proposal["status"], proposal["code"]), ("PROVISIONAL", "CANDIDATE_TRANSFORMATION"))
        self.assertEqual(proposal["summary"]["balance_count"], 3)
        checked, _ = self.invoke("g-check", "CHECK_CORE",
                                 candidates=directory / proposal["artifacts"]["core_candidates"]["path"])
        self.assertEqual((checked["status"], checked["code"]), ("PASS", "CORE_PASS"))

    def test_nilpotent_public_route_with_exact_reference_pair(self):
        inputs = {"cut": self.units / "nilpotent-cut.wl", "basis": self.units / "nilpotent-basis.wl"}
        proposal, directory = self.invoke("nilpotent-proposal", "SEARCH_CORE", **inputs,
                                          options={"reference_regulators": [[2, 7]]})
        self.assertEqual(proposal["code"], "CANDIDATE_TRANSFORMATION")
        checked, _ = self.invoke("nilpotent-check", "CHECK_CORE", **inputs,
                                 candidates=directory / proposal["artifacts"]["core_candidates"]["path"])
        self.assertEqual((checked["status"], checked["code"]), ("PASS", "CORE_PASS"))

    def test_exhaustion_is_inconclusive(self):
        receipt, _ = self.invoke("bounded-limit", "SEARCH_CORE", options={"max_balance_steps": 0})
        self.assertEqual((receipt["status"], receipt["code"]), ("INCONCLUSIVE", "METHOD_EXHAUSTED"))
        self.assertFalse(receipt["summary"]["nonexistence_proved"])

    def test_nonexact_reference_is_rejected(self):
        receipt, _ = self.invoke("nonexact-reference", "SEARCH_CORE", options={"reference_regulators": [0.5]}, code=1)
        self.assertEqual((receipt["status"], receipt["code"]), ("ERROR", "INVALID_OPTIONS"))

    def test_diagnosis_dimension_limit_is_not_no_go(self):
        receipt, _ = self.invoke("diagnosis-limit", "DIAGNOSE_CORE", options={"max_dimension": 2})
        self.assertEqual((receipt["status"], receipt["code"]), ("INCONCLUSIVE", "OUT_OF_SCOPE"))
        self.assertFalse(receipt["summary"]["nonexistence_proved"])

    def test_source_basis_mismatch_is_rejected(self):
        receipt, _ = self.invoke("basis-mismatch", "SEARCH_CORE", basis=self.units / "nilpotent-basis.wl", code=1)
        self.assertEqual((receipt["status"], receipt["code"]), ("ERROR", "INVALID_INPUT"))


if __name__ == "__main__":
    unittest.main()
