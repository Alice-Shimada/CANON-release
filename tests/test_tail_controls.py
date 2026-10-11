"""Tail controls retain original-source checks and bind resumable D to its input."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
KERNEL = Path(os.environ.get("CANON_WOLFRAM_KERNEL") or shutil.which("WolframKernel") or "WolframKernel").resolve()
ENTRY = os.environ.get("CANON_TEST_CANONICA_ENTRY")

FULL = '''Module[{target, known, raw},
 target = eps {{1,0,0},{2,3,0},{4,5,6}}/x;
 known = {{1,0,0},{0,1,0},{1/(x (1+eps)),1/((x-1) (1+2 eps)),1}};
 raw = Map[Together,(D[known,x]+known.target).Inverse[known],{2}];
 <|"schema"->"canon-neu/full-prefix-candidates/v1",
 "sector"-><|"id"->7,"propagator_count"->3|>,"family_id"->"tail-control",
 "current_basis_id"->"current", "accepted_prefix_id"->"prefix-test",
 "source_basis"->{l1,l2,j},"variables"->{x},"regulator"->eps,"alphabet"->{x},
 "block_boundaries"-><|"lower_dimension"->2,"current_dimension"->1|>,
 "convention"->"old_prefix_basis = full_transformation . candidate_prefix_basis",
 "source_matrices"->{raw},"candidates"->{<|"candidate_id"->"candidate",
 "member_candidate_ids"->{"seed"},"new_basis_rows"->IdentityMatrix[3],
 "full_transformation"->IdentityMatrix[3],"transformed_matrices"->{raw}|>}|>]
'''
CORE = '''<|"schema"->"canon-neu/core-transform/v1","candidate_id"->"candidate",
 "family_id"->"tail-control","basis_id"->"current","basis"->{j},
 "sector"-><|"id"->7,"propagator_count"->3|>,"variables"->{x},"regulator"->eps,
 "checks"-><|"pass"->True|>|>'''

@unittest.skipUnless(KERNEL.is_file() and ENTRY, "requires configured kernel and CANON_TEST_CANONICA_ENTRY")
class TailControlsTest(unittest.TestCase):
    def setUp(self):
        retained = os.environ.get("CANON_TEST_TAIL_OUTPUT_ROOT")
        self.temp = None if retained else tempfile.TemporaryDirectory()
        self.directory = Path(retained) / self._testMethodName if retained else Path(self.temp.name)
        self.directory.mkdir(parents=True, exist_ok=True)
        self.index = 0
        self.full = self.directory / "full.wl"
        self.full.write_text(FULL)
        self.core = self.directory / "core.wl"
        self.core.write_text(CORE)

    def tearDown(self):
        if self.temp is not None:
            self.temp.cleanup()

    def ref(self, path, **extra):
        return {"type": "mathematica-expression", "path": str(path), **extra}

    def call(self, options, checkpoint=None, full=None, expected=("PASS", "TAIL_READY"), ansatz=None,
             entry=None, core_file=None):
        self.index += 1
        payload = {"full_sector_de": self.ref(full or self.full), "core_transform": self.ref(core_file or self.core),
                   "method_options": {"package_entry": str(entry or ENTRY), **options}}
        if checkpoint:
            payload["tail_checkpoint"] = checkpoint
        if ansatz:
            payload["d_ansatz"] = ansatz
        task = {"schema": "canon-neu/script-input/v1", "task_id": f"tail-{self.index}",
                "step": "SOLVE_TAIL", "sector": {"id": 7, "propagator_count": 3}, "payload": payload}
        input_path = self.directory / f"input-{self.index}.json"
        output = self.directory / f"output-{self.index}"
        input_path.write_text(json.dumps(task))
        process = subprocess.run([sys.executable, str(ROOT / "tests/wolfram_kernel_launcher.py"),
            str(KERNEL), "-noinit", "-noprompt", "-script", str(ROOT / "mma/SolveTail.wls"),
            str(input_path), str(output)], capture_output=True, text=True, cwd=ROOT, timeout=100)
        output.with_suffix(".kernel.log").write_text(process.stdout + process.stderr, encoding="utf-8")
        path = output / "result.json"
        self.assertTrue(path.is_file(), process.stdout + process.stderr)
        result = json.loads(path.read_text())
        self.assertEqual((result["status"], result["code"]), expected, result)
        self.assertEqual(process.returncode, 1 if expected[0] == "ERROR" else 0, process.stdout + process.stderr)
        return result, output

    def check_canonical(self, result, output):
        artifact = output / result["artifacts"]["sector_transform"]["path"]
        task = {"schema": "canon-neu/script-input/v1", "task_id": f"check-{self.index}",
                "step": "CHECK_CANONICAL", "sector": {"id": 7, "propagator_count": 3},
                "payload": {"full_sector_de": self.ref(self.full), "sector_transform": self.ref(artifact)}}
        request = self.directory / f"check-{self.index}.json"
        request.write_text(json.dumps(task))
        check_output = self.directory / f"checked-{self.index}"
        p = subprocess.run([sys.executable, str(ROOT / "tests/wolfram_kernel_launcher.py"),
            str(KERNEL), "-noinit", "-noprompt", "-script", str(ROOT / "mma/CheckCanonical.wls"),
            str(request), str(check_output)], capture_output=True, text=True, cwd=ROOT, timeout=60)
        check_output.with_suffix(".kernel.log").write_text(p.stdout + p.stderr, encoding="utf-8")
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        checked = json.loads((check_output / "result.json").read_text())
        self.assertEqual((checked["status"], checked["code"]), ("PASS", "CANONICAL_PASS"), checked)

    def checkpoint(self):
        result, output = self.call({"tail_strategy": "subsector", "max_subsector_steps": 1},
                                  expected=("INCONCLUSIVE", "TAIL_UNSOLVED"))
        descriptor = result["artifacts"]["tail_checkpoint"]
        path = output / descriptor["path"]
        self.assertEqual(descriptor["sha256"], hashlib.sha256(path.read_bytes()).hexdigest())
        return {**descriptor, "path": str(path)}

    def test_legacy_and_subsector_paths_have_independent_full_gauge(self):
        for options in ({}, {"tail_strategy": "subsector"}, {"d_delta_numerator_degree": 1}):
            with self.subTest(options=options):
                result, output = self.call(options)
                self.check_canonical(result, output)

    def test_existing_receipts_and_message_log_are_not_overwritten(self):
        for with_result in (True, False):
            with self.subTest(with_result=with_result):
                self.index += 1
                task = {"schema": "canon-neu/script-input/v1", "task_id": f"tail-{self.index}",
                        "step": "SOLVE_TAIL", "sector": {"id": 7, "propagator_count": 3},
                        "payload": {"full_sector_de": self.ref(self.full), "core_transform": self.ref(self.core),
                                    "method_options": {"package_entry": str(ENTRY)}}}
                input_path = self.directory / f"input-{self.index}.json"
                input_path.write_text(json.dumps(task))
                output = self.directory / f"output-{self.index}"
                output.mkdir()
                message_path = output / "canonica-tail-messages.log"
                message_bytes = b"preserved CANONICA tail messages\n"
                message_path.write_bytes(message_bytes)
                result_path = output / "result.json"
                result_bytes = b'{"status":"PASS","code":"PRESERVED","artifacts":{}}\n'
                if with_result:
                    result_path.write_bytes(result_bytes)
                completed = subprocess.run([sys.executable, str(ROOT / "tests/wolfram_kernel_launcher.py"),
                    str(KERNEL), "-noinit", "-noprompt", "-script", str(ROOT / "mma/SolveTail.wls"),
                    str(input_path), str(output)], capture_output=True, text=True, cwd=ROOT, timeout=100)
                output.with_suffix(".kernel.log").write_text(completed.stdout + completed.stderr)
                self.assertNotEqual(completed.returncode, 0, completed.stdout + completed.stderr)
                self.assertEqual(message_path.read_bytes(), message_bytes)
                if with_result:
                    self.assertEqual(result_path.read_bytes(), result_bytes)
                else:
                    self.assertFalse(result_path.exists())
                self.assertFalse((output / "sector-transform.wl").exists())
                self.assertFalse((output / "tail-checkpoint.wl").exists())
                self.assertEqual({path.name for path in output.iterdir()},
                                 {"result.json", "canonica-tail-messages.log"} if with_result
                                 else {"canonica-tail-messages.log"})
                self.assertIn("OUTPUT_ERROR", completed.stdout + completed.stderr)

    def test_checkpoint_resume_and_source_binding(self):
        checkpoint = self.checkpoint()
        result, output = self.call({"tail_strategy": "subsector"}, checkpoint)
        self.assertTrue(result["summary"]["backend"]["resumed"])
        self.check_canonical(result, output)
        other = self.directory / "other.wl"
        other.write_text(FULL.replace('"tail-control"', '"different-family"'))
        other_core = self.directory / "other-core.wl"
        other_core.write_text(CORE.replace('"tail-control"', '"different-family"'))
        rejected, _ = self.call({"tail_strategy": "subsector"}, checkpoint, other,
                                 expected=("ERROR", "INVALID_INPUT"), core_file=other_core)
        self.assertEqual(rejected["summary"]["reason"], "tail_checkpoint_source_mismatch")

    def test_checkpoint_hash_and_matrix_shape_rejected(self):
        checkpoint = self.checkpoint()
        self.call({"tail_strategy": "subsector"}, {**checkpoint, "sha256": "0" * 64},
                  expected=("ERROR", "INVALID_INPUT"))
        original = Path(checkpoint["path"])
        altered = self.directory / "altered.wl"
        # Preserve binding while substituting an impossible shape in the saved state.
        altered.write_text(f'Join[Get[{json.dumps(str(original))}],<|"previous_d"->{{{{1,2,3}}}}|>]')
        changed = self.ref(altered, sha256=hashlib.sha256(altered.read_bytes()).hexdigest())
        self.call({"tail_strategy": "subsector"}, changed, expected=("ERROR", "INVALID_INPUT"))

    def test_checkpoint_binding_and_partial_d_domain_cannot_be_forged(self):
        checkpoint = self.checkpoint()
        original = Path(checkpoint["path"])
        mutations = {
            "candidate": 'Join[c["binding"], <|"identity" -> Join[c["binding", "identity"], <|"candidate_id" -> "other"|>]|>]',
            "base-gauge": 'Join[c["binding"], <|"base_transformation_sha256" -> "other"|>]',
            "tool-bytes": 'Join[c["binding"], <|"entry_sha256" -> "other"|>]',
            "active-rows": 'Join[c["binding"], <|"active_rows" -> {2,3}|>]',
        }
        for label, binding in mutations.items():
            with self.subTest(binding=label):
                changed = self.directory / f"checkpoint-{label}.wl"
                changed.write_text(f'Module[{{c = Get[{json.dumps(str(original))}]}}, Join[c,<|"binding" -> {binding}|>]]')
                descriptor = self.ref(changed, sha256=hashlib.sha256(changed.read_bytes()).hexdigest())
                result, _ = self.call({"tail_strategy": "subsector"}, descriptor, expected=("ERROR", "INVALID_INPUT"))
                self.assertEqual(result["summary"]["reason"], "tail_checkpoint_source_mismatch")
        for label, value in (("root", "Sqrt[x]"), ("approximate", "0.5"), ("symbol", "y")):
            with self.subTest(partial_d=label):
                changed = self.directory / f"checkpoint-{label}.wl"
                changed.write_text(f'Module[{{c = Get[{json.dumps(str(original))}]}}, Join[c,<|"previous_d" -> {{{{{value}}}}}|>]]')
                descriptor = self.ref(changed, sha256=hashlib.sha256(changed.read_bytes()).hexdigest())
                result, _ = self.call({"tail_strategy": "subsector"}, descriptor, expected=("ERROR", "INVALID_INPUT"))
                self.assertEqual(result["summary"]["reason"], "tail_checkpoint_shape_or_domain")

    def test_malformed_backend_matrices_stop_before_lift_or_publication(self):
        two_current = self.directory / "two-current.wl"
        two_current_core = self.directory / "two-current-core.wl"
        two_current_core.write_text(CORE.replace('"basis"->{j}', '"basis"->{j1,j2}'))
        two_current.write_text('''Module[{target, known, raw},
 target = eps {{1,0,0,0},{2,3,0,0},{4,5,6,0},{7,8,0,9}}/x;
 known = {{1,0,0,0},{0,1,0,0},{1/(x (1+eps)),1/((x-1) (1+2 eps)),1,0},
   {1/(x (1+3 eps)),1/((x-1) (1+4 eps)),0,1}};
 raw = Map[Together,(D[known,x]+known.target).Inverse[known],{2}];
 <|"schema"->"canon-neu/full-prefix-candidates/v1", "sector"-><|"id"->7,"propagator_count"->3|>,
 "family_id"->"tail-control", "current_basis_id"->"current", "accepted_prefix_id"->"prefix-test",
 "source_basis"->{l1,l2,j1,j2},"variables"->{x},"regulator"->eps,"alphabet"->{x},
 "block_boundaries"-><|"lower_dimension"->2,"current_dimension"->2|>,
 "convention"->"old_prefix_basis = full_transformation . candidate_prefix_basis",
 "source_matrices"->{raw},"candidates"->{<|"candidate_id"->"candidate",
 "member_candidate_ids"->{"seed"},"new_basis_rows"->IdentityMatrix[4],
 "full_transformation"->IdentityMatrix[4],"transformed_matrices"->{raw}|>}|>]
''')
        for mode, strategy, full, reason in (
            ("ragged", "subsector", two_current, "subsector_no_transformation"),
            ("symbol", "subsector", self.full, "subsector_no_transformation"),
            ("approximate", "subsector", self.full, "subsector_no_transformation"),
            ("off-shape", "monolithic", self.full, "backend_no_transformation"),
            ("normalization-shape", "monolithic", self.full, "epsilon_normalization_no_transformation"),
            ("normalization-singular", "monolithic", self.full, "epsilon_normalization_no_transformation"),
        ):
            with self.subTest(mode=mode):
                fake = self.directory / f"fake-{mode}.m"
                fake.write_text('''BeginPackage["CANONICA`"];
eps; VerbosityLevel; DDeltaNumeratorDegree;
SectorBoundariesFromDE[a_] := Table[{i,i},{i,Length[First[a]]}];
CalculateNextSubsectorD[a_,v_,b_,d_,t_,___] := Switch["''' + mode + '''",
 "ragged", {{0},{0,0}}, "symbol", {{Global`y}}, "approximate", {{0.5}}, _, {{0}}];
TransformOffDiagonalBlock[v_,b_,t_,a_,___] := {If["''' + mode + '''" === "off-shape",
 IdentityMatrix[Length[t]+1],t],a};
TransformDlogToEpsForm[v_,b_,t_,a_,___] := {Switch["''' + mode + '''",
 "normalization-shape", IdentityMatrix[Length[t]+1],
 "normalization-singular", ConstantArray[0,Dimensions[t]], _, t],a};
EndPackage[];
''')
                result, output = self.call({"tail_strategy": strategy}, full=full, entry=fake,
                                          expected=("INCONCLUSIVE", "TAIL_UNSOLVED"),
                                          core_file=two_current_core if full == two_current else None)
                self.assertEqual(result["summary"]["reason"], reason)
                self.assertIn("invalid_provider_result", result["summary"]["backend"]["diagnostics"][-1]["diagnostic_classes"])
                self.assertNotIn("sector_transform", result["artifacts"])
                self.assertFalse((output / "sector-transform.wl").exists())

    def test_invalid_strategy_budget_and_unknown_option(self):
        for options in ({"tail_strategy": "automatic"}, {"max_subsector_steps": 0},
                        {"max_wall_seconds": -1}, {"d_delta_numerator_degree": 1.5},
                        {"unexpected": True}):
            with self.subTest(options=options):
                self.call(options, expected=("ERROR", "INVALID_OPTIONS"))

    def d_ansatz(self, terms):
        self.index += 1
        path = self.directory / f"d-ansatz-{self.index}.wl"
        source_hash = hashlib.sha256(self.full.read_bytes()).hexdigest()
        path.write_text('''<|"schema"->"canon-neu/canonica-rational-ansatz/v1","kind"->"D",
          "identity"-><|"sector"-><|"id"->7,"propagator_count"->3|>,
          "family_id"->"tail-control","current_basis_id"->"current",
          "accepted_prefix_id"->"prefix-test","candidate_id"->"candidate",
          "source_basis"->{l1,l2,j},"regulator"->eps,"source_de_sha256"->"'''
          + source_hash + '''"|>,"scope"-><|"block_bounds"->{3,3}|>,
          "variables"->{x},"terms"->''' + terms + '|>')
        return self.ref(path, sha256=hashlib.sha256(path.read_bytes()).hexdigest())

    def test_directed_d_ansatz_keeps_full_gauge_and_rejects_wrong_domain(self):
        ansatz = self.d_ansatz('{1,1/x,1/(x-1)}')
        result, output = self.call({"tail_strategy": "subsector"}, ansatz=ansatz)
        self.assertEqual(result["summary"]["backend"]["ansatz"]["term_count"], 3)
        self.check_canonical(result, output)
        for terms in ('{Sqrt[x]}', '{eps/x}', '{y/x}', '{}'):
            with self.subTest(terms=terms):
                self.call({"tail_strategy": "subsector"}, ansatz=self.d_ansatz(terms),
                          expected=("ERROR", "INVALID_INPUT"))
        self.call({"tail_strategy": "subsector", "max_ansatz_terms": 2}, ansatz=ansatz,
                  expected=("ERROR", "INVALID_INPUT"))
        self.call({}, ansatz=ansatz, expected=("ERROR", "INVALID_OPTIONS"))

    def test_backend_time_limit_preserves_stage_diagnostics(self):
        result, _ = self.call({"max_wall_seconds": 0.001},
                              expected=("INCONCLUSIVE", "TAIL_UNSOLVED"))
        diagnostics = result["summary"]["backend"]["diagnostics"]
        self.assertTrue(any(item["timed_out"] for item in diagnostics), diagnostics)

    def test_finite_d_exhaustion_preserves_scientific_failure_class(self):
        result, output = self.call({"tail_strategy": "subsector"},
            ansatz=self.d_ansatz('{1}'), expected=("INCONCLUSIVE", "TAIL_UNSOLVED"))
        self.assertEqual(result["summary"]["reason"], "subsector_no_transformation")
        diagnostics = result["summary"]["backend"]["diagnostics"]
        self.assertIn("finite_ansatz_exhausted", diagnostics[-1]["diagnostic_classes"])
        self.assertNotIn("invalid_provider_result", diagnostics[-1]["diagnostic_classes"])
        self.assertEqual(diagnostics[-1]["attempted_ansatz"]["term_count"], 1)
        self.assertIn("tail_checkpoint", result["artifacts"])
        self.assertNotIn("sector_transform", result["artifacts"])

if __name__ == "__main__":
    unittest.main()
