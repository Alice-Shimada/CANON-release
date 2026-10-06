#!/usr/bin/env python3
"""Exercise automatic/standalone physical derivatives and actual DE consumers.

No native reduction runs. Optional --g3447-inputs supplies existing verified
master_basis, sector_manifest and ibp_reduction descriptors for a 34-master check.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--canon", required=True, type=Path)
    parser.add_argument("--work", required=True, type=Path)
    parser.add_argument("--g3447-inputs", type=Path)
    args = parser.parse_args()
    canon, work = args.canon.resolve(), args.work.resolve()
    work.mkdir(parents=True, exist_ok=False)
    tree = work / "original tree"
    sources = tree / "sources"
    sources.mkdir(parents=True)
    for name in ("scalar-spec.wl", "scalar-masters", "scalar-master-basis.wl", "scalar-sectors.wl", "scalar-reduction.wl"):
        shutil.copyfile(canon / "components/parameterization/examples" / name, sources / name)
    environment = dict(os.environ, OMP_NUM_THREADS="1", MKL_NUM_THREADS="1", OPENBLAS_NUM_THREADS="1")
    runtime = environment.get("CANON_WOLFRAMSCRIPT") or shutil.which("wolframscript")
    if not runtime:
        raise RuntimeError("Set CANON_WOLFRAMSCRIPT or put wolframscript on PATH")
    invocations = []
    selection = ["--components", str(canon / "components/parameterization/components.json")]

    def descriptor(path):
        return {"type": "mathematica-expression", "path": str(path)}

    def step(name, command, payload, code, sector=None, failure=False):
        request = tree / (name + ".json")
        request.write_text(json.dumps({"schema": "canon-neu/script-input/v1", "task_id": "PHYSICAL-DERIVATIVE-TEST",
            "step": command, "sector": sector, "payload": payload}, indent=2) + "\n")
        destination = tree / name
        process = subprocess.run([sys.executable, str(canon / "run_step.py"), str(request), str(destination), *selection],
            env=environment, capture_output=True, text=True, timeout=120)
        (destination / "process.log").write_text(process.stdout + process.stderr)
        result = json.loads((destination / "result.json").read_text())
        assert process.returncode == int(failure), (name, process.stdout, process.stderr)
        assert (result["status"], result["code"]) == ("FAIL" if failure else "PASS", code), result
        invocations.append({"step": command, "status": result["status"], "code": code})
        return destination

    step("prepare", "PREPARE", {"family_spec": descriptor("sources/scalar-spec.wl")}, "PARAMETERIZATION_READY")
    assert (tree / "prepare/prepared-derivatives.wl").is_file()
    denied = (sources / "scalar-spec.wl").read_text().replace('"ordered_masters" ->',
        '"prepared_derivatives" -> "must-not-be-loaded.wl", "ordered_masters" ->')
    (sources / "manual-spec.wl").write_text(denied)
    step("manual-denied", "PREPARE", {"family_spec": descriptor("sources/manual-spec.wl")},
         "DERIVATIVES_GENERATED_FROM_FAMILY", failure=True)
    step("derivatives", "PREPARE_DERIVATIVES", {"family_data": descriptor("prepare/family-data.wl")},
         "PHYSICAL_DERIVATIVES_READY")
    relocated = work / "relocated inputs with spaces"
    shutil.move(tree, relocated)
    tree, sources = relocated, relocated / "sources"
    common = {"prepared_family": descriptor("prepare/prepared-family.wl"),
              "master_basis": descriptor("sources/scalar-master-basis.wl")}
    step("targets", "PREPARE_REDUCTION_TARGETS", common, "REDUCTION_TARGETS_READY")
    step("build", "BUILD_CUT_DE", {**common, "sector_manifest": descriptor("sources/scalar-sectors.wl"),
         "ibp_reduction": descriptor("sources/scalar-reduction.wl")}, "OK", {"id": 3, "propagator_count": 2})
    (sources / "scalar-candidates.wl").write_text(
        '<|"proposal_id"->"physical-bubble","candidate_pool"-><|"available"->1,"remaining"->0,"pool_exhausted"->True|>,'
        '"method_evidence"-><||>,"tool_provenance"-><|"tool"->"analytic-fixture"|>,'
        '"candidates"->{<|"candidate_id"->"u-times-bubble","normalization"-><|"factor"->1|>,'
        '"exact_definition"->HoldComplete[u Q[1,1]]|>}|>\n')
    step("candidate-bridge", "REDUCE_CANDIDATE_IBP", {**common,
         "integral_candidates": descriptor("sources/scalar-candidates.wl"),
         "prepared_derivatives": descriptor("prepare/prepared-derivatives.wl"),
         "ibp_reduction": descriptor("sources/scalar-reduction.wl"),
         "derivative_operator_selection": "prepared-affine"}, "CANDIDATES_REDUCED")
    if args.g3447_inputs:
        input_manifest = args.g3447_inputs.resolve()
        supplied = json.loads(input_manifest.read_text())
        bound = {}
        for key in ("master_basis", "sector_manifest", "ibp_reduction"):
            item = supplied[key]
            path = (input_manifest.parent / item["path"]).resolve()
            assert hashlib.sha256(path.read_bytes()).hexdigest() == item["sha256"], key
            bound[key] = descriptor(path)
        shutil.copyfile(canon / "tests/fixtures/physical-derivatives/g3447-spec.wl", sources / "g3447-spec.wl")
        step("g-prepare", "PREPARE", {"family_spec": descriptor("sources/g3447-spec.wl")}, "PARAMETERIZATION_READY")
        g_common = {"prepared_family": descriptor("g-prepare/prepared-family.wl"), "master_basis": bound["master_basis"]}
        step("g-targets", "PREPARE_REDUCTION_TARGETS", g_common, "REDUCTION_TARGETS_READY")
        step("g-build", "BUILD_CUT_DE", {**g_common, "sector_manifest": bound["sector_manifest"],
            "ibp_reduction": bound["ibp_reduction"]}, "OK", {"id": 1286, "propagator_count": 4})
    receipt = work / "scientific-checks.json"
    process = subprocess.run([runtime, "-file", str(canon / "tests/PhysicalDerivativeChecks.wls"),
        str(canon), str(tree), str(receipt)], env=environment, capture_output=True, text=True, timeout=120)
    (work / "checks.log").write_text(process.stdout + process.stderr)
    checks = json.loads(receipt.read_text())
    assert process.returncode == 0 and all(checks.values()), (checks, process.stdout, process.stderr)
    evidence = {"scope": "Physical derivative generation and symbolic DE regression; no new native reduction",
        "checks": checks, "invocations": invocations, "native_reduction_runs": 0, "all_pass": True}
    (work / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print(json.dumps(evidence, indent=2))


if __name__ == "__main__":
    main()
