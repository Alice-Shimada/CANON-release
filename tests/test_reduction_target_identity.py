#!/usr/bin/env python3
"""Six serial named calls for prepared-family/master-basis identity binding.

Use --canon CHECKOUT --components MANIFEST --inputs INPUTS.json --work FRESH_DIR.
INPUTS identifies immutable prepared_family, prepared_derivatives, master_basis,
sector_manifest and ibp_reduction plus expected target and DE artifacts. Each
entry has path and sha256; relative paths use that manifest's directory.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--canon", type=Path, required=True)
    parser.add_argument("--components", type=Path, action="append", required=True)
    parser.add_argument("--inputs", type=Path, required=True)
    parser.add_argument("--work", type=Path, required=True)
    args = parser.parse_args()
    canon, work = args.canon.resolve(), args.work.resolve()
    work.mkdir(parents=True, exist_ok=False)
    input_manifest = args.inputs.resolve()
    references = json.loads(input_manifest.read_text())
    paths = {}
    for role, descriptor in references.items():
        path = (input_manifest.parent / descriptor["path"]).resolve()
        assert sha256(path) == descriptor["sha256"], role
        paths[role] = path
    components = [str(p.resolve()) for p in args.components]
    selection = [arg for p in components for arg in ("--components", p)]
    env = os.environ.copy()
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    receipts = []
    descriptions = {}

    for case in ("matched", "family_ref", "basis_ref"):
        master_path = paths["master_basis"]
        if case != "matched":
            master_path = work / (case + "-mismatch.wl")
            expression, changes = re.subn(
                r'("' + case + r'"\s*->\s*)"([^"\n]*)"',
                lambda match: match[1] + json.dumps(match[2] + "/unrelated"),
                paths["master_basis"].read_text(),
            )
            assert changes == 1, case
            master_path.write_text(expression)
        for step in ("PREPARE_REDUCTION_TARGETS", "BUILD_CUT_DE"):
            name = case + "-" + step.lower()
            request = work / (name + ".json")
            roles = ["prepared_family", "prepared_derivatives"]
            if step == "BUILD_CUT_DE":
                roles += ["sector_manifest", "ibp_reduction"]
            bound = {role: paths[role] for role in roles}
            bound["master_basis"] = master_path
            data = {"schema": "canon-neu/script-input/v1", "task_id": name,
                    "step": step, "payload": {
                        role: {"type": "mathematica-expression",
                               "path": os.path.relpath(path, request.parent)}
                        for role, path in bound.items()}}
            if step == "BUILD_CUT_DE":
                data["sector"] = {"id": 3, "propagator_count": 2}
            request.write_text(json.dumps(data, indent=2) + "\n")
            output = work / name
            argv = [sys.executable, str(canon / "run_step.py"), str(request), str(output), *selection]
            if step not in descriptions:
                described = subprocess.run([*argv, "--describe"], cwd=canon, env=env,
                                           text=True, capture_output=True, check=True)
                descriptions[step] = json.loads(described.stdout)
            with (work / (name + ".log")).open("w") as log:
                process = subprocess.run(argv, cwd=canon, env=env, text=True,
                                         stdout=log, stderr=subprocess.STDOUT, timeout=90)
            result = json.loads((output / "result.json").read_text())
            mismatch = case != "matched"
            assert process.returncode == int(mismatch), (case, step, result)
            equality = {}
            if mismatch:
                assert (result["status"], result["code"], result["artifacts"]) == (
                    "ERROR", "SOURCE_BASIS_MISMATCH", {}), result
            else:
                expected_code = "REDUCTION_TARGETS_READY" if step == "PREPARE_REDUCTION_TARGETS" else "OK"
                assert (result["status"], result["code"]) == ("PASS", expected_code), result
                for role, descriptor in result["artifacts"].items():
                    actual = output / descriptor["path"]
                    expected = paths["expected_" + role]
                    assert actual.read_bytes() == expected.read_bytes(), role
                    equality[role] = {"sha256": sha256(actual),
                                      "expected_reference": references["expected_" + role],
                                      "byte_identical": True}
            receipts.append({"case": case, "step": step, "argv": argv,
                             "exit_code": process.returncode, "result": result,
                             "exact_output_comparison": equality,
                             "request_sha256": sha256(request),
                             "master_sha256": sha256(master_path)})
    for role, descriptor in references.items():
        assert sha256(paths[role]) == descriptor["sha256"], role
    evidence = {"all_pass": True, "scientific_calls": 6, "mismatch_calls": 4,
                "matched_calls": 2, "byte_identical_outputs": 4,
                "component_selection": components, "descriptions": descriptions,
                "input_references": references, "receipts": receipts,
                "execution": "Serial foreground steps, one Wolfram kernel at a time",
                "native_engine_invocations": 0,
                "scope": "Identity boundary revision only; prior 22-call and 27-check evidence retained by reference."}
    (work / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print(json.dumps({key: evidence[key] for key in (
        "all_pass", "scientific_calls", "mismatch_calls", "matched_calls", "byte_identical_outputs")}, indent=2))


if __name__ == "__main__":
    main()
