#!/usr/bin/env python3
"""Bounded neutral-parameterization and downstream compatibility tests."""
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
    parser.add_argument("--point-de", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    canon, source_point, output = args.canon.resolve(), args.point_de.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    tree = output / "tree"
    package = tree / "parameterization"
    shutil.copytree(Path(__file__).resolve().parents[1], package)
    point_package = tree / "point-de"
    point_package.mkdir()
    for name in ("PointDE.wl", "Run.wls", "README.md"):
        shutil.copyfile(source_point / name, point_package / name)
    point_manifest = {"schema": "canon-neu/components/v1", "steps": {
        step: {"command": ["{wolframscript}", "-file", "{package}/Run.wls", "{canon}"], "instructions": "README.md"}
        for step in ("PREPARE_POINT", "BUILD_POINT_DE")}}
    (point_package / "components.json").write_text(json.dumps(point_manifest, indent=2))
    selection = {"schema": "canon-neu/components/v1", "steps": {
        "PREPARE": {"from": "parameterization/components.json"},
        "PREPARE_POINT": {"from": "point-de/components.json"},
        "BUILD_POINT_DE": {"from": "point-de/components.json"}}}
    (tree / "selection.json").write_text(json.dumps(selection, indent=2))
    invocations = []

    def desc(path):
        return {"type": "mathematica-expression", "path": path}

    def request(name, step, payload, sector=None):
        path = tree / name
        path.write_text(json.dumps({"schema": "canon-neu/script-input/v1", "task_id": "PARAMETERIZATION-TEST",
                                    "step": step, "sector": sector, "payload": payload}, indent=2))
        return path

    def run(path, destination, code, status="PASS"):
        result = subprocess.run([sys.executable, str(canon / "run_step.py"), str(path), str(destination),
                                 "--components", str(tree / "selection.json")], capture_output=True, text=True, timeout=120)
        (destination / "process.log").write_text(result.stdout + result.stderr)
        scientific = json.loads((destination / "result.json").read_text())
        assert result.returncode == (0 if status == "PASS" else 1) and scientific["status"] == status and scientific["code"] == code, scientific
        invocations.append({"step": scientific["step"], "status": scientific["status"], "code": scientific["code"]})

    run(package / "examples" / "vector-prepare.json", tree / "vector", "PARAMETERIZATION_READY")
    run(package / "examples" / "scalar-prepare.json", tree / "scalar", "PARAMETERIZATION_READY")
    symbol_spec = package / "examples" / "symbol-spec.wl"
    symbol_spec.write_text((package / "examples" / "scalar-spec.wl").read_text().replace(
        '"index_order" -> {"D1","D2"}', '"index_order" -> {D1,D2}'))
    symbol_request = request("symbol-prepare.json", "PREPARE", {"family_spec": desc("parameterization/examples/symbol-spec.wl")})
    run(symbol_request, tree / "symbol", "PARAMETERIZATION_READY")
    for kind in ("scalar", "symbol"):
        assert json.loads((tree / kind / "reducer-family.json").read_text())["index_order"] == ["D1", "D2"]

    failed_export = tree / "failed-export"
    (failed_export / "reducer-family.json").mkdir(parents=True)
    run(package / "examples" / "scalar-prepare.json", failed_export, "REDUCER_FAMILY_EXPORT_FAILED", status="FAIL")
    assert not (failed_export / "prepared-family.wl").exists()
    assert json.loads((failed_export / "result.json").read_text())["artifacts"] == {}
    expected_files = {"family-data.wl", "reducer-family.json", "prepared-family.wl", "prepared-derivatives.wl", "result.json", "process.log"}
    assert {p.name for p in (tree / "vector").iterdir()} == expected_files
    assert {p.name for p in (tree / "scalar").iterdir()} == expected_files
    forbidden = {"kira", "backend", "jobs", "seed", "executable", "project", "options"}

    def keys(value):
        if isinstance(value, dict):
            return set(value) | set().union(*(keys(v) for v in value.values()))
        if isinstance(value, list):
            return set().union(*(keys(v) for v in value))
        return set()

    for kind in ("vector", "scalar"):
        data = json.loads((tree / kind / "reducer-family.json").read_text())
        assert not keys(data) & forbidden
        assert not Path(data["family_data"]["path"]).is_absolute()

    (tree / "vector-masters.wl").write_text('<|"schema"->"canon-neu/master-basis/v1","family_ref"->"synthetic-bubble","basis_ref"->"bubble-master","masters"->{B[1,1,0,0,0]}|>\n')
    (tree / "vector-candidates.wl").write_text('<|"schema"->"canon-neu/point-candidates/v1","basis_id"->"x-times-bubble","rows"->{{<|"indices"->{1,1,0,0,0},"numerator"->x[1]|>}}|>\n')
    (tree / "vector-point.wl").write_text('<|"schema"->"canon-neu/point-spec/v1","family_id"->"synthetic-bubble","basis_id"->"bubble-restored","chart_id"->"indexed-scale","frame_id"->"divide-by-x","scope"-><|"included_sectors"->{3},"excluded_sectors"->"others"|>,"point"->{x[1]->2},"frame"->{{1/x[1]}}|>\n')
    (tree / "vector-rules.wl").write_text('{B[0,2,0,0,0]->0,B[1,2,0,0,0]->-(d-3)/16 B[1,1,0,0,0]}\n')
    request("point-prepare.json", "PREPARE_POINT", {"family_data": desc("vector/family-data.wl"),
        "master_basis": desc("vector-masters.wl"), "candidates": desc("vector-candidates.wl"), "point_spec": desc("vector-point.wl")})
    request("point-build.json", "BUILD_POINT_DE", {"prepared_point": desc("point/prepared-point.wl"),
        "ibp_reduction": {**desc("vector-rules.wl"), "kinematics": "vector/family-data.wl"}})
    request("discover.json", "DISCOVER", {"prepared_family": desc("scalar/prepared-family.wl")})
    request("scalar-build.json", "BUILD_CUT_DE", {"prepared_family": desc("scalar/prepared-family.wl"),
        "master_basis": desc("parameterization/examples/scalar-master-basis.wl"),
        "sector_manifest": desc("parameterization/examples/scalar-sectors.wl"),
        "ibp_reduction": desc("parameterization/examples/scalar-reduction.wl")}, {"id": 3, "propagator_count": 2})

    # Relocate once before downstream use, without repeating completed scientific steps.
    relocated = output / "relocated" / "tree"
    relocated.parent.mkdir()
    shutil.move(tree, relocated)
    tree, package, point_package = relocated, relocated / "parameterization", relocated / "point-de"
    run(tree / "point-prepare.json", tree / "point", "POINT_PREPARED")
    run(tree / "point-build.json", tree / "point-de-result", "POINT_DE_BUILT")
    run(tree / "discover.json", tree / "discovery", "SECTORS_READY")
    run(tree / "scalar-build.json", tree / "scalar-de", "OK")

    runtime = os.environ.get("CANON_WOLFRAMSCRIPT") or shutil.which("wolframscript")
    if not runtime:
        raise RuntimeError("Set CANON_WOLFRAMSCRIPT or put wolframscript on PATH")
    receipt = output / "scientific-checks.json"
    process = subprocess.run([runtime, "-file", str(package / "tests" / "Checks.wls"), str(canon),
                              str(package), str(point_package), str(tree), str(receipt)], capture_output=True,
                             text=True, timeout=120)
    (output / "checks.log").write_text(process.stdout + process.stderr)
    checks = json.loads(receipt.read_text())
    assert process.returncode == 0 and all(checks.values()), checks
    evidence = {"scope": "Bounded synthetic parameterization and standard-consumer compatibility; no native reduction campaign",
                "scientific_checks": checks, "invocations": invocations, "native_project_files": [],
                "index_labels_exported_as_strings": True, "export_failure_reported": True,
                "no_backend_keys": True, "kernels_in_parallel": 1, "all_pass": True}
    (output / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print(json.dumps(evidence, indent=2))


if __name__ == "__main__":
    main()
