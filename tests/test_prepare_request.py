import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

import run_step


ROOT = Path(__file__).resolve().parents[1]


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value), encoding="utf-8")


class RequestBindingTest(unittest.TestCase):
    def call(self, tree, template, output):
        source = tree / "templates/template.json"
        save(source, template)
        request = tree / "bind.json"
        save(request, {"schema": "canon-neu/script-input/v1", "task_id": "bind-test",
                       "step": "PREPARE_REQUEST", "sector": None,
                       "payload": {"template": {"path": "templates/template.json"}}})
        process = subprocess.run([sys.executable, str(ROOT / "run_step.py"), str(request),
                                  str(output), "--defaults"], text=True, capture_output=True)
        return process, json.loads((output / "result.json").read_text())

    def template(self, payload):
        return {"schema": "canon-neu/script-input/v1", "task_id": "scientific-step",
                "step": "BUILD_CUT_DE", "sector": {"id": 3, "propagator_count": 2},
                "payload": payload}

    def tail_result(self, tree, **changes):
        value = {"schema": "canon-neu/script-result/v1", "step": "SOLVE_TAIL",
                 "status": "INCONCLUSIVE", "code": "TAIL_UNSOLVED",
                 "artifacts": {"tail_checkpoint": {
                     "type": "mathematica-expression", "path": "checkpoint.wl",
                     "sha256": "a" * 64},
                     "sector_transform": {"type": "mathematica-expression", "path": "unsafe.wl"}}}
        value.update(changes)
        save(tree / "producer/result.json", value)
        return {"from_result": "../producer/result.json", "artifact": "tail_checkpoint"}

    def test_tail_continuation_preserves_descriptor_and_budget(self):
        with tempfile.TemporaryDirectory() as temporary:
            tree = Path(temporary).resolve()
            reference = self.tail_result(tree)
            template = {**self.template({"tail_checkpoint": reference,
                         "method_options": {"max_wall_seconds": 17, "tail_strategy": "subsector"}}),
                        "step": "SOLVE_TAIL"}
            output = tree / "bound"
            process, result = self.call(tree, template, output)
            self.assertEqual(process.returncode, 0, result)
            payload = json.loads((output / "request.json").read_text())["payload"]
            self.assertEqual(payload["tail_checkpoint"]["type"], "mathematica-expression")
            self.assertEqual(payload["tail_checkpoint"]["sha256"], "a" * 64)
            self.assertEqual((output / payload["tail_checkpoint"]["path"]).resolve(),
                             tree / "producer/checkpoint.wl")
            self.assertEqual(payload["method_options"], template["payload"]["method_options"])

    def test_tail_continuation_exception_is_scoped_to_one_producer_and_slot(self):
        changes = ({"schema": "other"}, {"step": "CHECK_CANONICAL"},
                   {"status": "FAIL"}, {"status": "ERROR"}, {"code": "OTHER"})
        for change in changes:
            with self.subTest(change=change), tempfile.TemporaryDirectory() as temporary:
                tree = Path(temporary).resolve()
                reference = self.tail_result(tree, **change)
                template = {**self.template({"tail_checkpoint": reference}), "step": "SOLVE_TAIL"}
                output = tree / "bound"
                _, result = self.call(tree, template, output)
                self.assertEqual(result["code"], "REQUEST_BINDING_FAILED")
                self.assertFalse((output / "request.json").exists())
        for slot in ("nested", "list", "other_step", "other_artifact", "cache_hit"):
            with self.subTest(slot=slot), tempfile.TemporaryDirectory() as temporary:
                tree = Path(temporary).resolve()
                reference = self.tail_result(tree)
                payload = {"tail_checkpoint": reference}
                step = "SOLVE_TAIL"
                if slot == "nested":
                    payload = {"nested": payload}
                elif slot == "list":
                    payload = {"tail_checkpoint": [reference]}
                elif slot == "other_step":
                    step = "BUILD_FULL_DE"
                elif slot == "other_artifact":
                    payload = {"tail_checkpoint": {**reference, "artifact": "sector_transform"}}
                else:
                    payload["sector_transform"] = {**reference, "artifact": "sector_transform"}
                template = {**self.template(payload), "step": step}
                output = tree / "bound"
                _, result = self.call(tree, template, output)
                self.assertEqual(result["code"], "REQUEST_BINDING_FAILED")
                self.assertFalse((output / "request.json").exists())

    def test_moved_nested_bindings_keep_producer_metadata_and_literal_paths(self):
        with tempfile.TemporaryDirectory(prefix="canon bindings ") as temporary:
            original = Path(temporary) / "original"
            artifact = original / "producer/scientific data/master-basis.wl"
            artifact.parent.mkdir(parents=True)
            artifact.write_text("{Q[1,1]}\n")
            digest = hashlib.sha256(artifact.read_bytes()).hexdigest()
            save(original / "producer/result.json", {"schema": "canon-neu/script-result/v1",
                 "status": "PROVISIONAL", "artifacts": {"master_basis": {
                     "type": "mathematica-expression", "path": "scientific data/master-basis.wl",
                     "sha256": digest, "basis_ref": "source-order"}}})
            save(original / "settings/backend.json", {"executable": "caller-tool"})
            moved = Path(temporary) / "moved tree with spaces"
            shutil.move(original, moved)
            payload = {
                "master_basis": {"from_result": "../producer/result.json", "artifact": "master_basis"},
                "nested": [{"from_result": "../producer/result.json", "artifact": "master_basis"}],
                "backend": {"type": "json", "path": "../settings/backend.json"},
                "options": {"budget": 17, "label": "literal options"}}
            destination = moved / "new requests/bound"
            process, result = self.call(moved, self.template(payload), destination)
            self.assertEqual(process.returncode, 0, process.stderr)
            self.assertEqual((result["status"], result["code"]), ("PASS", "REQUEST_READY"))
            request = json.loads((destination / "request.json").read_text())
            bound = request["payload"]
            self.assertEqual((destination / bound["master_basis"]["path"]).resolve(),
                             moved / "producer/scientific data/master-basis.wl")
            self.assertEqual(bound["master_basis"]["sha256"], digest)
            self.assertEqual(bound["master_basis"]["basis_ref"], "source-order")
            self.assertEqual(bound["nested"], [bound["master_basis"]])
            self.assertEqual((destination / bound["backend"]["path"]).resolve(), moved / "settings/backend.json")
            self.assertEqual(bound["options"], payload["options"])
            self.assertEqual(request["sector"], {"id": 3, "propagator_count": 2})
            self.assertFalse(original.exists())

    def test_failed_result_or_missing_artifact_cannot_publish_partial_request(self):
        for status, artifacts in [("FAIL", {"master_basis": {"path": "basis.wl"}}), ("PASS", {})]:
            with self.subTest(status=status), tempfile.TemporaryDirectory() as temporary:
                tree = Path(temporary)
                save(tree / "producer/result.json", {"schema": "canon-neu/script-result/v1",
                     "status": status, "artifacts": artifacts})
                output = tree / "output"
                process, result = self.call(tree, self.template({"master_basis": {
                    "from_result": "../producer/result.json", "artifact": "master_basis"}}), output)
                self.assertNotEqual(process.returncode, 0)
                self.assertEqual((result["status"], result["code"]), ("ERROR", "REQUEST_BINDING_FAILED"))
                self.assertFalse((output / "request.json").exists())

    def test_per_step_reference_reports_the_selected_interface(self):
        with tempfile.TemporaryDirectory() as temporary:
            profile = Path(temporary) / "components.json"
            save(profile, {"schema": "canon-neu/components/v1", "steps": {
                "BIND": {"from": str(ROOT / "components/default.json"), "step": "PREPARE_REQUEST"}}})
            selected = run_step.load_components(profile)["BIND"]
            self.assertEqual(selected["interface"]["inputs"], ["template"])
            self.assertEqual(selected["interface"]["outputs"], ["request"])
            self.assertEqual(selected["manifest"], str(ROOT / "components/default.json"))
            self.assertEqual(selected["binding_manifest"], str(profile))


if __name__ == "__main__":
    unittest.main()
