#!/usr/bin/env python3
"""Serial symbolic target / DE compatibility regression; no native engine.

Use --canon CHECKOUT --components MANIFEST --inputs INPUTS.json --work FRESH_DIR.
The input manifest identifies existing prepared_family, master_basis,
sector_manifest, prepared_derivatives and ibp_reduction files by path and hash.
Accepted inputs are read in place; an embedded-reference equivalence fixture
rebinds only the prepared-family derivative reference. All scientific calls use
run_step.py and the full ordered selection.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--canon", required=True, type=Path)
    parser.add_argument("--components", required=True, action="append", type=Path)
    parser.add_argument("--inputs", required=True, type=Path)
    parser.add_argument("--work", required=True, type=Path)
    args = parser.parse_args()
    canon, work = args.canon.resolve(), args.work.resolve()
    work.mkdir(parents=True, exist_ok=False)
    manifest_path = args.inputs.resolve()
    inputs = json.loads(manifest_path.read_text())
    sources = {}
    for key, item in inputs.items():
        path = (manifest_path.parent / item["path"]).resolve()
        assert digest(path) == item["sha256"], key
        sources[key] = path
    components = [str(p.resolve()) for p in args.components]
    selection = [arg for path in components for arg in ("--components", path)]
    runtime = os.environ.get("CANON_WOLFRAMSCRIPT") or shutil.which("wolframscript")
    assert runtime, "Declare CANON_WOLFRAMSCRIPT or install wolframscript on PATH"
    env = os.environ.copy()
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    invocations = []

    def run(argv, log, expected=0):
        with log.open("w") as out:
            proc = subprocess.run(argv, cwd=canon, env=env, text=True,
                                  stdout=out, stderr=subprocess.STDOUT, timeout=90)
        record = {"argv": argv, "exit_code": proc.returncode,
                  "log": str(log.relative_to(work))}
        invocations.append(record)
        assert proc.returncode == expected, (record, log.read_text())
        return record

    def descriptor(request, path):
        return {"type": "mathematica-expression",
                "path": os.path.relpath(path, request.parent)}

    cases = {}

    def step(name, command, paths, sector=None, code="OK", error=False):
        request = work / "requests" / (name + ".json")
        data = {"schema": "canon-neu/script-input/v1", "task_id": name,
                "step": command,
                "payload": {key: descriptor(request, path) for key, path in paths.items()}}
        if sector is not None:
            data["sector"] = sector
        write_json(request, data)
        output = work / "outputs" / name
        argv = [sys.executable, str(canon / "run_step.py"), str(request), str(output), *selection]
        if command not in described:
            run([*argv, "--describe"], work / (command + "-describe.json"))
            described.add(command)
        run(argv, work / (name + ".log"), expected=int(error))
        result = json.loads((output / "result.json").read_text())
        assert (result["status"], result["code"]) == ("ERROR" if error else "PASS", code), result
        if error:
            assert result["artifacts"] == {}, result
        cases[name] = {"result": str(output / "result.json"), "error": error}
        return output

    described = set()
    fixture_dir = work / "relocated inputs with spaces" / "prepared"
    fixture_dir.mkdir(parents=True)
    scalar_prepared = fixture_dir / "scalar-prepared.wl"
    original = sources["prepared_family"].read_text()
    old_path = inputs["prepared_family"]["derivative_path"]
    assert original.count(json.dumps(old_path)) == 1
    scalar_prepared.write_text(original.replace(json.dumps(old_path), json.dumps(
        os.path.relpath(sources["prepared_derivatives"], scalar_prepared.parent))))
    scalar_inputs = {key: sources[key] for key in ("master_basis", "sector_manifest", "ibp_reduction")}
    scalar_inputs["prepared_family"] = sources["prepared_family"]
    scalar_inputs["prepared_derivatives"] = sources["prepared_derivatives"]
    scalar_sector = {"id": 3, "propagator_count": 2}
    step("scalar-targets", "PREPARE_REDUCTION_TARGETS",
         {key: scalar_inputs[key] for key in ("prepared_family", "master_basis", "prepared_derivatives")},
         code="REDUCTION_TARGETS_READY")
    step("scalar-embedded-targets", "PREPARE_REDUCTION_TARGETS", {
        "prepared_family": scalar_prepared, "master_basis": sources["master_basis"]},
        code="REDUCTION_TARGETS_READY")
    scalar_build = step("scalar-build", "BUILD_CUT_DE", scalar_inputs, scalar_sector)
    step("scalar-slice", "SLICE_CUT_DE", {
        "ordered_master_de": scalar_build / "ordered-master-de.wl",
        "sector_manifest": sources["sector_manifest"]}, scalar_sector)

    def fixture(name, variables, derivatives, masters, rules, count, slots, sectors,
                symbol_map="<||>"):
        directory = work / "fixtures" / name
        directory.mkdir(parents=True)
        values = {
            "derivatives": derivatives,
            "prepared_family": '''<|"schema" -> "canon-neu/prepared-family/v1",
 "family_ref" -> "target-fixture", "basis_ref" -> "source-order", "topology" -> "fixture",
 "parameters" -> Join[{d}, VARIABLES], "variables" -> VARIABLES,
 "regulator" -> eps, "dimension_rule" -> d -> 4-2eps,
 "index_order" -> ("D" <> ToString[#]& /@ Range[COUNT]),
 "operator_source_symbol_map" -> MAPPING,
 "prepared_derivatives" -> <|"path" -> "derivatives.wl"|>|>'''.replace(
                "VARIABLES", variables).replace("COUNT", str(count)).replace("MAPPING", symbol_map),
            "master_basis": '''<|"schema" -> "canon-neu/master-basis/v1", "family_ref" -> "target-fixture",
 "basis_ref" -> "source-order", "index_order" -> ("D" <> ToString[#]& /@ Range[COUNT]),
 "masters" -> MASTERS|>'''.replace("COUNT", str(count)).replace("MASTERS", masters),
            "sector_manifest": '''<|"schema" -> "canon-neu/sector-manifest/v1", "family_ref" -> "target-fixture",
 "propagator_slots" -> SLOTS, "sectors" -> SECTORS|>'''.replace("SLOTS", slots).replace("SECTORS", sectors),
            "ibp_reduction": '<|"masters" -> ' + masters + ', "rules" -> ' + rules + '|>',
        }
        paths = {}
        for key, data in values.items():
            path = directory / (key.replace("_", "-") + ".wl")
            path.write_text(data + "\n")
            paths[key] = path
        return {key: value for key, value in paths.items() if key != "derivatives"}

    sector1 = {"id": 1, "propagator_count": 1}
    sector_records = '{<|"id"->0,"propagator_count"->0,"sector_bits"->{0}|>, <|"id"->1,"propagator_count"->1,"sector_bits"->{1}|>}'
    multi = fixture("mapped-v2", "{y,x}", '''<|"schema"->"canon.prepared-derivatives/v2",
 "variables"->{ignored}, "denominator_count"->1, "operators"-><|
 Source`sy->{<|"constant"->2,"linear"->{}|>}, Source`sx->{<|"constant"->1,"linear"->{}|>}|>|>''',
                    "{f[0],f[2],f[1]}", "{f[3]->d f[0]+d f[1]+f[2]}", 1, "{1}", sector_records,
                    '<|"Source`sy"->"Global`y", "Source`sx"->"Global`x"|>')
    step("mapped-targets", "PREPARE_REDUCTION_TARGETS",
         {key: multi[key] for key in ("prepared_family", "master_basis")}, code="REDUCTION_TARGETS_READY")
    multi_build = step("mapped-build", "BUILD_CUT_DE", multi, sector1)
    step("mapped-slice", "SLICE_CUT_DE", {
        "ordered_master_de": multi_build / "ordered-master-de.wl",
        "sector_manifest": multi["sector_manifest"]}, sector1)

    zero = '<|"constant"->0,"linear"->{}|>'
    records = "{" + ",".join([zero] * 12) + "}"
    legacy = '<|"denominators"->Range[12],"records"->' + records + '|>'
    legacy_sectors = '{<|"id"->0,"propagator_count"->0,"sector_bits"->ConstantArray[0,12]|>, <|"id"->1,"propagator_count"->1,"sector_bits"->Join[{1},ConstantArray[0,11]]|>}'
    legacy_master = "{h[1,0,0,0,0,0,0,0,0,0,0,0]}"
    legacy_inputs = fixture("legacy", "{u}", legacy, legacy_master, "{}", 12, "{1}", legacy_sectors)
    step("legacy-targets", "PREPARE_REDUCTION_TARGETS",
         {key: legacy_inputs[key] for key in ("prepared_family", "master_basis")}, code="REDUCTION_TARGETS_READY")
    step("legacy-build", "BUILD_CUT_DE", legacy_inputs, sector1)

    negative_data = {
        "missing-record-field": ("{u}", legacy.replace(zero, '<|"linear"->{}|>', 1)),
        "record-count-mismatch": ("{u}", legacy.replace(records, "Most[" + records + "]")),
        "bad-denominator-index": ("{u}", legacy.replace(zero, '<|"constant"->0,"linear"->{<|"coefficient"->1,"denominator"->13|>}|>', 1)),
        "missing-linear-field": ("{u}", legacy.replace(zero, '<|"constant"->0,"linear"->{<|"denominator"->1|>}|>', 1)),
        "multivariable-legacy": ("{u,v}", legacy),
    }
    for name, (variables, derivative) in negative_data.items():
        data = fixture(name, variables, derivative, legacy_master, "{}", 12, "{1}", legacy_sectors)
        step(name + "-targets", "PREPARE_REDUCTION_TARGETS",
             {key: data[key] for key in ("prepared_family", "master_basis")},
             code="INVALID_PREPARED_DERIVATIVES", error=True)
        step(name + "-build", "BUILD_CUT_DE", data, sector1,
             code="INVALID_PREPARED_DERIVATIVES", error=True)
    unclosed = fixture("unclosed", "{u}", legacy.replace(zero, '<|"constant"->1,"linear"->{}|>', 1),
                       legacy_master, "{}", 12, "{1}", legacy_sectors)
    step("unclosed-build", "BUILD_CUT_DE", unclosed, sector1,
         code="INVALID_DIFFERENTIAL_EQUATION", error=True)
    floating = fixture("floating-rule", "{y,x}",
                       (work / "fixtures/mapped-v2/derivatives.wl").read_text(),
                       "{f[0],f[2],f[1]}", "{f[3]->0.5 f[1]}", 1, "{1}", sector_records,
                       '<|"Source`sy"->"Global`y", "Source`sx"->"Global`x"|>')
    step("floating-rule-build", "BUILD_CUT_DE", floating, sector1,
         code="INVALID_DIFFERENTIAL_EQUATION", error=True)
    invalid_regulator = legacy_inputs["prepared_family"].with_name("invalid-regulator-prepared.wl")
    invalid_regulator.write_text(legacy_inputs["prepared_family"].read_text().replace(
        '"regulator" -> eps', '"regulator" -> 1'))
    step("invalid-regulator-build", "BUILD_CUT_DE",
         {**legacy_inputs, "prepared_family": invalid_regulator}, sector1,
         code="INVALID_DIFFERENTIAL_EQUATION", error=True)

    case_path = work / "cases.json"
    write_json(case_path, cases)
    checker = Path(__file__).with_name("ReductionTargetsChecks.wls").resolve()
    exact_path = work / "exact-checks.json"
    run([runtime, "-file", str(checker), str(case_path), str(exact_path)], work / "readback.log")
    exact = json.loads(exact_path.read_text())
    assert exact["all_pass"], exact
    assert exact["runtime"]["subkernel_count"] == 0, exact
    for key, item in inputs.items():
        assert digest(sources[key]) == item["sha256"], key
    evidence = {"all_pass": True, "scientific_calls": len(cases),
                "exact_checks": len(exact["checks"]), "negative_calls": sum(c["error"] for c in cases.values()),
                "component_selection": components, "runtime": runtime,
                "native_invocations": 0, "concurrent_test_kernels": 1,
                "input_references": inputs, "invocations": invocations}
    write_json(work / "evidence.json", evidence)
    print(json.dumps({key: evidence[key] for key in ("all_pass", "scientific_calls", "exact_checks", "negative_calls", "native_invocations")}, indent=2))


if __name__ == "__main__":
    main()
