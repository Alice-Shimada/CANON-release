"""Automatic engine selection without running a scientific reduction."""

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


PACKAGE = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("kira_adapter", PACKAGE / "run.py")
ADAPTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ADAPTER)


class JobEngineTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.project = self.directory / "project"
        self.project.mkdir()
        self.family = json.loads((PACKAGE / "examples/reducer-family.json").read_text())
        self.backend = {"seed": {"r": 3, "s": 0, "d": 1}}

    def generate(self, step="REDUCE_IBP"):
        jobs = ADAPTER.prepare_project(
            self.family, self.backend, self.directory / "backend.json", self.project, step)
        return (self.project / jobs[0]).read_text()

    def test_omitted_engine_uses_firefly_and_keeps_export(self):
        job = self.generate()
        self.assertIn("run_firefly: true", job)
        self.assertNotIn("run_triangular", job)
        self.assertNotIn("run_back_substitution", job)
        self.assertIn("preferred_masters: preferred-masters", job)
        self.assertIn("kira2math:", job)

    def test_explicit_fermat_uses_symbolic_reduction(self):
        self.backend["reduction_engine"] = "fermat"
        job = self.generate()
        self.assertNotIn("run_firefly", job)
        self.assertIn("run_triangular: true", job)
        self.assertIn("run_back_substitution: true", job)

    def test_unknown_engine_is_rejected(self):
        self.backend["reduction_engine"] = "unknown"
        with self.assertRaisesRegex(ValueError, "reduction_engine"):
            self.generate()
        self.assertFalse((self.project / "jobs.yaml").exists())

    def test_discovery_is_still_initiation_only(self):
        job = self.generate("DISCOVER")
        self.assertIn("run_initiate: masters", job)
        self.assertNotIn("run_firefly", job)
        self.assertNotIn("run_triangular", job)
        self.assertNotIn("kira2math", job)

    def test_custom_jobs_are_not_rewritten(self):
        source = self.directory / "caller.yaml"
        content = "jobs:\n  - reduce_sectors:\n      run_firefly: true\n"
        source.write_text(content)
        self.backend = {"jobs": ["caller.yaml"], "reduction_engine": "fermat"}
        self.assertEqual(self.generate(), content)


if __name__ == "__main__":
    unittest.main()
