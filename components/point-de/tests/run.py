#!/usr/bin/env python3
"""Bounded point-DE tests. All generated files stay below --output."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--canon", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    canon, output = args.canon.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    tree = output / "tree"
    package = tree / "package"
    shutil.copytree(Path(__file__).resolve().parents[1], package)
    receipts = []

    def request(path, step, payload):
        path.write_text(json.dumps({"schema": "canon-neu/script-input/v1", "task_id": "POINT-DE-TEST",
                                    "step": step, "sector": None, "payload": payload}, indent=2))

    def desc(path):
        return {"type": "mathematica-expression", "path": path}

    def run(input_path, destination, expected):
        command = [sys.executable, str(canon / "run_step.py"), str(input_path), str(destination),
                   "--components", str(package / "components.json")]
        process = subprocess.run(command, text=True, capture_output=True, timeout=120)
        result = json.loads((destination / "result.json").read_text())
        assert result["code"] == expected, result
        assert process.returncode == (0 if result["status"] == "PASS" else 1), process.stderr
        receipts.append({"step": result["step"], "code": result["code"], "returncode": process.returncode})
        (destination / "process.log").write_text(process.stdout + process.stderr)

    run(package / "examples" / "prepare.json", tree / "training-prepared", "POINT_PREPARED")
    request(tree / "build-training.json", "BUILD_POINT_DE", {
        "prepared_point": desc("training-prepared/prepared-point.wl"),
        "ibp_reduction": {**desc("package/examples/reduction.wl"), "symbolic": True}})
    run(tree / "build-training.json", tree / "training", "POINT_DE_BUILT")

    (tree / "validation-point.wl").write_text((package / "examples" / "point.wl").read_text().replace("x -> 2", "x -> 3"))
    request(tree / "prepare-validation.json", "PREPARE_POINT", {
        "family_data": desc("package/examples/family.wl"), "master_basis": desc("package/examples/masters.wl"),
        "candidates": desc("package/examples/candidates.wl"), "point_spec": desc("validation-point.wl")})
    run(tree / "prepare-validation.json", tree / "validation-prepared", "POINT_PREPARED")
    request(tree / "build-validation.json", "BUILD_POINT_DE", {
        "prepared_point": desc("validation-prepared/prepared-point.wl"),
        "ibp_reduction": {**desc("package/examples/reduction.wl"), "symbolic": True}})
    run(tree / "build-validation.json", tree / "validation", "POINT_DE_BUILT")

    (tree / "training2-point.wl").write_text((package / "examples" / "point.wl").read_text().replace("x -> 2", "x -> 4"))
    request(tree / "prepare-training2.json", "PREPARE_POINT", {
        "family_data": desc("package/examples/family.wl"), "master_basis": desc("package/examples/masters.wl"),
        "candidates": desc("package/examples/candidates.wl"), "point_spec": desc("training2-point.wl")})
    run(tree / "prepare-training2.json", tree / "training2-prepared", "POINT_PREPARED")
    request(tree / "build-training2.json", "BUILD_POINT_DE", {
        "prepared_point": desc("training2-prepared/prepared-point.wl"),
        "ibp_reduction": {**desc("package/examples/reduction.wl"), "symbolic": True}})
    run(tree / "build-training2.json", tree / "training2", "POINT_DE_BUILT")

    # No reducer executable is invoked: this deliberately incomplete rules file must fail.
    (tree / "incomplete-rules.wl").write_text("{}\n")
    request(tree / "build-incomplete.json", "BUILD_POINT_DE", {
        "prepared_point": desc("training-prepared/prepared-point.wl"),
        "ibp_reduction": {"type": "mathematica-rules", "path": "incomplete-rules.wl", "symbolic": True}})
    run(tree / "build-incomplete.json", tree / "incomplete", "MISSING_TARGETS")

    (tree / "point-rules.wl").write_text("{B[0,2,0,0,0] -> 0, B[1,2,0,0,0] -> -(d-3)/16 B[1,1,0,0,0]}\n")
    point_payload = {"prepared_point": desc("training-prepared/prepared-point.wl"),
                     "ibp_reduction": {"type": "mathematica-rules", "path": "point-rules.wl",
                                       "kinematics": "training-prepared/reduction-kinematics.wl"}}
    request(tree / "build-point-bound.json", "BUILD_POINT_DE", point_payload)
    run(tree / "build-point-bound.json", tree / "point-bound", "POINT_DE_BUILT")
    point_payload["ibp_reduction"]["kinematics"] = "validation-prepared/reduction-kinematics.wl"
    request(tree / "build-wrong-point.json", "BUILD_POINT_DE", point_payload)
    run(tree / "build-wrong-point.json", tree / "wrong-point", "REDUCTION_POINT_MISMATCH")

    roles = {"training": [{"id": "train", "path": "training/de-sample.wl"},
                          {"id": "train2", "path": "training2/de-sample.wl"}],
             "validation": [{"id": "check", "path": "validation/de-sample.wl"}]}
    request(tree / "collect.json", "COLLECT_DE_SAMPLES", roles)
    run(tree / "collect.json", tree / "samples", "DE_SAMPLES_COLLECTED")
    roles["validation"] = [{"id": "same-point", "path": "training/de-sample.wl"}]
    request(tree / "collect-overlap.json", "COLLECT_DE_SAMPLES", roles)
    run(tree / "collect-overlap.json", tree / "overlap", "OVERLAPPING_SAMPLE_ROLES")

    moved = output / "relocated" / "tree"
    moved.parent.mkdir()
    shutil.move(tree, moved)
    tree, package = moved, moved / "package"
    run(tree / "collect.json", tree / "samples-after-move", "DE_SAMPLES_COLLECTED")

    runtime = os.environ.get("CANON_WOLFRAMSCRIPT") or shutil.which("wolframscript")
    if not runtime:
        raise RuntimeError("Set CANON_WOLFRAMSCRIPT or put wolframscript on PATH")
    check_file = output / "scientific-checks.json"
    process = subprocess.run([runtime, "-file", str(package / "tests" / "Checks.wls"), str(canon),
                              str(package), str(tree), str(check_file)], text=True, capture_output=True, timeout=120)
    (output / "checks.log").write_text(process.stdout + process.stderr)
    checks = json.loads(check_file.read_text())
    assert process.returncode == 0 and all(checks.values()), checks
    collector_file = output / "collector-checks.json"
    process = subprocess.run([runtime, "-file", str(package / "tests" / "CollectorChecks.wls"), str(canon),
                              str(package), str(tree), str(collector_file)], text=True, capture_output=True, timeout=120)
    (output / "collector-checks.log").write_text(process.stdout + process.stderr)
    collector_checks = json.loads(collector_file.read_text())
    assert process.returncode == 0 and all(collector_checks.values()), collector_checks
    checks.update(collector_checks)
    evidence = {"scope": "Synthetic point-DE implementation fixtures; no physical campaign or global canonical acceptance",
                "invocations": receipts, "scientific_checks": checks, "all_pass": True,
                "runtime": runtime, "kernels_in_parallel": 1}
    (output / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print(json.dumps(evidence, indent=2))


if __name__ == "__main__":
    main()
