"""Pentabox fixture acceptance through the public IBP audit, without native Kira."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "tests/fixtures/kira-massless-two-loop-five-point-pentabox"
RUNTIME = os.environ.get("CANON_WOLFRAMSCRIPT") or shutil.which("wolframscript")


def fixture_lines(name):
    return [value for line in (FIXTURE / name).read_text().splitlines()
            if (value := line.split("#", 1)[0].strip())]


@unittest.skipUnless(RUNTIME, "configure CANON_WOLFRAMSCRIPT or wolframscript")
class PentaboxIBPAuditTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="pentabox audit ")
        self.addCleanup(self.temporary.cleanup)
        self.work = Path(self.temporary.name)
        self.masters = fixture_lines("preferred-masters")
        self.targets = fixture_lines("targets")
        self.rules = [f"{target} -> (d-4)/s12 {master}"
                      for target, master in zip(self.targets, self.masters)]
        self.environment = dict(os.environ, CANON_WOLFRAMSCRIPT=RUNTIME,
                                CANON_PYTHON=sys.executable, PYTHONDONTWRITEBYTECODE="1")

    def reduction(self, rules=None, masters=None):
        path = self.work / "reduction with spaces.wl"
        path.write_text('<|"masters"->{' + ",".join(masters or self.masters) +
                        '},"rules"->{' + ",".join(self.rules if rules is None else rules) + '}|>\n')
        return path

    def invoke(self, script, *arguments):
        return subprocess.run([RUNTIME, "-file", str(ROOT / "tests" / script),
                               *map(str, arguments)], env=self.environment,
                              capture_output=True, text=True, timeout=90)

    def check(self, path):
        output = self.work / "check output"
        completed = self.invoke("CheckPentaboxIBP.wls", path, output)
        result = json.loads((output / "audit/result.json").read_text())
        return completed, result, output

    def assert_check_failed(self, result, reason):
        self.assertEqual((result["status"], result["code"]), ("FAIL", "IBP_CHECK_FAILED"))
        self.assertEqual(result["summary"]["reason_code"], reason)

    def test_valid_rules_use_public_audit_and_fixture_oracle(self):
        completed, result, output = self.check(self.reduction())
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertEqual((result["step"], result["status"], result["code"]),
                         ("CHECK_IBP", "PASS", "IBP_AUDIT_PASS"))
        self.assertEqual(result["summary"]["counts"]["masters"], 61)
        self.assertEqual(result["summary"]["counts"]["required_targets"], 2)
        self.assertTrue((output / "audit/ibp-audit.wl").is_file())
        checks = json.loads((output / "checks.json").read_text())
        self.assertTrue(checks["passed"])
        self.assertTrue(all(checks["checks"].values()))

    def test_nonlinear_master_product_cannot_pass(self):
        rules = [f"{self.targets[0]} -> {self.masters[0]} {self.masters[1]}", self.rules[1]]
        completed, result, _ = self.check(self.reduction(rules))
        self.assertEqual(completed.returncode, 1)
        self.assert_check_failed(result, "IBP_UNSUPPORTED_STRUCTURE")

    def test_undeclared_coefficient_cannot_pass(self):
        rules = [f"{self.targets[0]} -> rogue {self.masters[0]}", self.rules[1]]
        completed, result, _ = self.check(self.reduction(rules))
        self.assertEqual(completed.returncode, 1)
        self.assert_check_failed(result, "IBP_UNDECLARED_SYMBOL")

    def test_missing_target_cannot_pass(self):
        completed, result, _ = self.check(self.reduction(self.rules[:1]))
        self.assertEqual(completed.returncode, 1)
        self.assert_check_failed(result, "IBP_MISSING_TARGETS")

    def test_duplicate_rule_cannot_pass(self):
        completed, result, _ = self.check(self.reduction(self.rules + self.rules[:1]))
        self.assertEqual(completed.returncode, 1)
        self.assert_check_failed(result, "IBP_DUPLICATE_LHS")

    def test_fixture_source_master_order_is_preserved(self):
        completed, result, _ = self.check(self.reduction(masters=self.masters[::-1]))
        self.assertEqual(completed.returncode, 1)
        self.assert_check_failed(result, "IBP_MASTER_ORDER_MISMATCH")

    def test_fixture_oracle_rejects_extra_export_after_audit_pass(self):
        extra = self.targets[0].replace("[2,", "[3,", 1)
        completed, result, output = self.check(
            self.reduction(self.rules + [f"{extra} -> {self.masters[0]}"]))
        self.assertEqual(completed.returncode, 1)
        self.assertEqual(result["status"], "PASS")
        checks = json.loads((output / "checks.json").read_text())
        self.assertFalse(checks["passed"])
        self.assertFalse(checks["checks"]["ordered_fixture_targets"])

    def test_live_entry_uses_audit_for_supplied_native_exports(self):
        # Simulate only native file generation; both public CANON steps are real.
        for name, rules, expected in (
                ("valid", self.rules, "IBP_AUDIT_PASS"),
                ("nonlinear", [f"{self.targets[0]} -> {self.masters[0]} {self.masters[1]}",
                               self.rules[1]], "IBP_UNSUPPORTED_STRUCTURE")):
            with self.subTest(name=name):
                fake = self.work / ("fake kira " + name)
                fake.write_text("#!" + sys.executable + "\nfrom pathlib import Path\n"
                    "import sys\nassert sys.argv[1] == '--parallel=1'\n"
                    "out=Path('results/pentabox5');out.mkdir(parents=True,exist_ok=True)\n"
                    "(out/'masters.final').write_text(" + repr("\n".join(self.masters)) + ")\n"
                    "(out/'kira_targets.m').write_text(" + repr("{" + ",".join(rules) + "}") + ")\n")
                fake.chmod(0o755)
                output = self.work / (name + " live")
                completed = self.invoke("RunPentaboxIBPLiveTest.wls", fake, output)
                self.assertEqual(completed.returncode, 0 if name == "valid" else 1,
                                 completed.stdout + completed.stderr)
                result = json.loads(Path(str(output) + ".check/audit/result.json").read_text())
                self.assertEqual(result["step"], "CHECK_IBP")
                if name == "valid":
                    self.assertEqual(result["code"], expected)
                else:
                    self.assert_check_failed(result, expected)

    def test_live_entry_uses_declared_artifact_and_requires_successful_producer(self):
        # Replace only native production; the fixture checker and CHECK_IBP run.
        reduction = self.reduction().read_text()
        for mode in ("relative", "absolute", "wrong-task", "wrong-hash", "failed-exit", "failed-status"):
            with self.subTest(mode=mode):
                package = self.work / (mode + " component")
                package.mkdir()
                script = package / "producer.py"
                script.write_text(
                    "import hashlib,json,pathlib,sys\n"
                    "request,output=map(pathlib.Path,sys.argv[1:]);output.mkdir(parents=True)\n"
                    "task=json.loads(request.read_text())\n"
                    "artifact=output/'exports/renamed result.wl';artifact.parent.mkdir()\n"
                    f"artifact.write_text({reduction!r})\n"
                    f"mode={mode!r}\n"
                    "descriptor={'path':str(artifact.resolve()) if mode=='absolute' else str(artifact.relative_to(output)),"
                    "'sha256':'0'*64 if mode=='wrong-hash' else hashlib.sha256(artifact.read_bytes()).hexdigest()}\n"
                    "result={'schema':'canon-neu/script-result/v1','task_id':'wrong-task' if mode=='wrong-task' else task['task_id'],"
                    "'step':'REDUCE_IBP','status':'ERROR' if mode=='failed-status' else 'PASS',"
                    "'code':'FIXTURE_ERROR' if mode=='failed-status' else 'IBP_REDUCED',"
                    "'artifacts':{'ibp_reduction':descriptor},'summary':{}}\n"
                    "(output/'result.json').write_text(json.dumps(result))\n"
                    "sys.exit(7 if mode=='failed-exit' else 0)\n")
                (package / "README.md").write_text("Native-format fixture producer for descriptor acceptance tests.\n")
                manifest = package / "components.json"
                manifest.write_text(json.dumps({"schema": "canon-neu/components/v1", "steps": {
                    "REDUCE_IBP": {"command": [sys.executable, str(script)], "instructions": "README.md"}}}))
                inherited = self.environment.get("CANON_COMPONENTS")
                stack = json.loads(inherited) if inherited and inherited.startswith("[") else [inherited] if inherited else []
                self.environment["CANON_COMPONENTS"] = json.dumps([*stack, str(manifest)])
                try:
                    output = self.work / (mode + " live")
                    completed = self.invoke("RunPentaboxIBPLiveTest.wls", "unused-native-fixture", output)
                finally:
                    if inherited is None:
                        self.environment.pop("CANON_COMPONENTS", None)
                    else:
                        self.environment["CANON_COMPONENTS"] = inherited
                accepted = mode in ("relative", "absolute")
                self.assertEqual(completed.returncode, 0 if accepted else 1,
                                 completed.stdout + completed.stderr)
                check = Path(str(output) + ".check")
                if accepted:
                    result = json.loads((check / "audit/result.json").read_text())
                    self.assertEqual((result["status"], result["code"]), ("PASS", "IBP_AUDIT_PASS"))
                    self.assertTrue(json.loads((check / "checks.json").read_text())["passed"])
                else:
                    self.assertFalse(check.exists(), "unsuccessful or mismatched producer must not start the audit")


if __name__ == "__main__":
    unittest.main()
