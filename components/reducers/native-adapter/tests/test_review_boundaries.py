#!/usr/bin/env python3
"""Focused point-scope, process-exit and FIRE discovery-source regressions."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--canon", required=True, type=Path)
    parser.add_argument("--work", required=True, type=Path)
    parser.add_argument("--wolframscript", default=os.environ.get("CANON_WOLFRAMSCRIPT", "wolframscript"))
    args = parser.parse_args()
    canon, work = args.canon.resolve(), args.work.resolve()
    shared = Path(__file__).resolve().parents[1]
    fire = shared.parent / "fire7"
    work.mkdir(parents=True, exist_ok=False)
    # A thin test entry binds the revised library while unchanged sources remain referenced in place.
    runtime = work / "runtime"
    runtime.mkdir()
    (runtime / "run.py").symlink_to(shared / "run.py")
    (runtime / "Normalize.wls").write_text('$HistoryLength=0; {canon,input,out,receipt}=Rest[$ScriptCommandLine];\n'
        'Get[FileNameJoin[{canon,"mma","lib","MethodCardCore.wl"}]];\n'
        'Get[' + json.dumps(str(shared / "NativeAdapter.wl")) + '];\n'
        'CanonNativeAdapter`NormalizeStep[input,out,receipt];\n')
    manifest = work / "components.json"
    manifest.write_text(json.dumps({"schema": "canon-neu/components/v1", "workflow": str(shared / "README.md"), "steps": {
        name: {"command": ["{python}", str(runtime / "run.py"), "{canon}", "{wolframscript}", "fire7", str(fire)],
               "instructions": str(shared / "README.md")} for name in ("DISCOVER", "REDUCE_IBP", "BUILD_CUT_DE")}}, indent=2))
    records = []

    def write_json(path, value):
        path.write_text(json.dumps(value, indent=2) + "\n")

    def point(value):
        return [] if value is None else [{"variable": "u", "value": str(value)}]

    def fixture(name, family_point=None, binding_point=None, step="REDUCE_IBP", prepared=False):
        directory = work / name
        directory.mkdir()
        family = {"schema": "canon-neu/reducer-family/v1", "family_ref": "scope-family", "basis_ref": "scope-basis",
                  "topology": "native_scope", "integral_head": "J", "index_order": ["D1", "D2"], "propagator_slots": [1, 2],
                  "top_level_sectors": [3], "loop_momenta": ["ell"], "external_momenta": ["p"],
                  "propagators": [{"momentum": "ell", "mass_squared": "0"}, {"momentum": "ell-p", "mass_squared": "0"}],
                  "scalar_products": [{"momenta": ["p", "p"], "value": str(family_point) if family_point is not None else "u"}],
                  "invariants": [{"name": "u", "mass_dimension": 2}], "point": point(family_point),
                  "variables": ["u"], "dimension": "d", "regulator": "eps", "dimension_rule": "d -> 4 - 2 eps"}
        write_json(directory / "family.json", family)
        (directory / "prepared.wl").write_text('<|"family_ref"->"scope-family","basis_ref"->"scope-basis","topology"->"native_scope",'
            '"integral_head"->"J","index_order"->{"D1","D2"},"propagator_slots"->{1,2},"variables"->{u},'
            '"dimension"->d,"regulator"->eps,"dimension_rule"->(d->4-2eps)|>\n')
        target_point = "{}" if binding_point is None else "{u->" + str(binding_point) + "}"
        (directory / "targets.wl").write_text('<|"schema"->"canon-neu/reduction-targets/v1","family_ref"->"scope-family",'
            '"basis_ref"->"scope-basis","targets"->{J[2,1]},"masters"->{J[1,1]},"point"->' + target_point + '|>\n')
        (directory / "masters.wl").write_text('<|"schema"->"canon-neu/master-basis/v1","family_ref"->"scope-family",'
            '"basis_ref"->"scope-basis","masters"->{J[1,1]}|>\n')
        (directory / "sectors.wl").write_text('<|"schema"->"canon-neu/sector-manifest/v1","family_ref"->"scope-family",'
            '"propagator_slots"->{1,2},"sectors"->{<|"id"->3,"propagator_count"->2,"sector_bits"->{1,1},"master_count"->1|>}|>\n')
        (directory / "native-masters.wl").write_text('{{7,{1,1}}}\n')
        native_point = family_point if family_point is not None else binding_point
        denominator = "u" if native_point is None else "(" + str(native_point) + ")"
        (directory / "native-rules.wl").write_text('{G[7,{2,1}]->(d-4)/(2*' + denominator + ') G[7,{1,1}]}\n')
        (directory / "native-de.wl").write_text('<|"masters"->{G[7,{1,1}]},"variables"->{u},"matrices"->{{{-eps/u}}},'
            '"coefficient_domain"->"exact-rational-functions","point"->{},"convention"->"D[basis, variables[[i]]] = matrices[[i]] . basis"|>\n')
        backend = {"schema": "canon-neu/native-backend/v1", "adapter": "fire7", "encoding": {"head": "G", "family": 7, "layout": "family-list"},
                   "masters_format": "family-index-pairs", "binding": {"family_ref": "scope-family", "basis_ref": "scope-basis",
                       "index_order": ["D1", "D2"], "coefficient_domain": "exact-rational-functions", "point": point(binding_point)},
                   "operations": {"DISCOVER": {"mode": "import", "source_format": "native-masters", "exports": {"masters": "native-masters.wl"}},
                       "REDUCE_IBP": {"mode": "import", "source_format": "fire7-rules", "exports": {"masters": "native-masters.wl", "rules": "native-rules.wl"}},
                       "BUILD_CUT_DE": {"mode": "import", "source_format": "exact-de-association", "exports": {"de": "native-de.wl"}}}}
        write_json(directory / "backend.json", backend)
        payload = {"backend": {"path": "backend.json"}, "master_basis": {"path": "masters.wl"},
                   "prepared_family" if prepared else "reducer_family": {"path": "prepared.wl" if prepared else "family.json"}}
        if step == "REDUCE_IBP":
            payload["reduction_targets"] = {"path": "targets.wl"}
        if step == "BUILD_CUT_DE":
            payload["sector_manifest"] = {"path": "sectors.wl"}
        request = {"schema": "canon-neu/script-input/v1", "task_id": name, "step": step,
                   "sector": {"id": 3, "propagator_count": 2} if step == "BUILD_CUT_DE" else None, "payload": payload}
        write_json(directory / "request.json", request)
        return directory

    def run(directory, expected, wolfram=None, extra_environment=None):
        env = dict(os.environ, CANON_WOLFRAMSCRIPT=wolfram or args.wolframscript)
        env.update(extra_environment or {})
        completed = subprocess.run([sys.executable, str(canon / "run_step.py"), str(directory / "request.json"), str(directory / "out"),
                                    "--components", str(manifest)], cwd=work, env=env, text=True, capture_output=True, timeout=90)
        (directory / "test.log").write_text(completed.stdout + completed.stderr)
        assert completed.returncode == 0, (directory.name, completed.stdout, completed.stderr)
        result = json.loads((directory / "out" / "result.json").read_text())
        assert (result["status"], result["code"]) == expected, (directory.name, result, expected)
        records.append({"case": directory.name, "status": result["status"], "code": result["code"], "expected": True})
        print(directory.name + ": " + "/".join(expected), flush=True)
        return result

    for name, actual, declared, step_name in (
        ("frozen-versus-symbolic-reduction", 2, None, "REDUCE_IBP"),
        ("different-points", 2, 3, "REDUCE_IBP"),
        ("frozen-versus-symbolic-de", 2, None, "BUILD_CUT_DE"),
        ("symbolic-versus-point", None, 2, "REDUCE_IBP"),
    ):
        run(fixture(name, actual, declared, step_name), ("ERROR", "POINT_SCOPE_MISMATCH"))
    run(fixture("matching-point", 2, 2), ("PASS", "IBP_REDUCED"))
    run(fixture("de-point", 2, 2, "BUILD_CUT_DE"), ("ERROR", "POINT_ONLY_DE_EXPORT"))
    run(fixture("prepared-import-point", None, 2, prepared=True), ("PASS", "IBP_REDUCED"))

    fake = work / "nonzero-normalizer.py"
    fake.write_text('#!' + sys.executable + '\nimport json,sys\nfrom pathlib import Path\n'
        'request=json.loads(Path(sys.argv[-3]).read_text()); output=Path(sys.argv[-2])\n'
        'status=request["payload"]["test_status"]\n'
        'result={"schema":"canon-neu/script-result/v1","task_id":request["task_id"],"step":request["step"],"status":status,'
        '"code":"FALSE_PASS" if status=="PASS" else "SPECIFIC_ERROR","artifacts":{},"summary":{"detail":"preserve-specific-error"}}\n'
        '(output/"result.json").write_text(json.dumps(result))\nsys.exit(9)\n')
    fake.chmod(0o755)
    for status, code in (("PASS", "NORMALIZATION_PROCESS_FAILED"), ("ERROR", "SPECIFIC_ERROR")):
        directory = fixture("nonzero-" + status.lower())
        request = json.loads((directory / "request.json").read_text())
        request["payload"]["test_status"] = status
        write_json(directory / "request.json", request)
        result = run(directory, ("ERROR", code), str(fake))
        if status == "ERROR":
            assert result["summary"] == {"detail": "preserve-specific-error"}

    probe = work / "launch-probe.py"
    probe.write_text('#!' + sys.executable + '\nimport os\nfrom pathlib import Path\nPath(os.environ["CANON_TEST_LAUNCH_MARKER"]).write_text("launched")\n')
    probe.chmod(0o755)
    for name, master_export in (("fire-backend-masters", {"base": "backend", "path": "native-masters.wl"}),
                                ("fire-escaping-output", {"base": "output", "path": "../native-masters.wl"})):
        directory = fixture(name, step="DISCOVER")
        backend = json.loads((directory / "backend.json").read_text())
        backend.update(master_export=master_export, executable=str(probe))
        backend["operations"]["DISCOVER"].update(mode="command", argv=["{python}", str(fire / "native.py"), "{context}"])
        write_json(directory / "backend.json", backend)
        marker = directory / "launched.marker"
        run(directory, ("ERROR", "NATIVE_DRIVER_FAILED"), str(probe), {"CANON_TEST_LAUNCH_MARKER": str(marker)})
        assert not marker.exists(), "FIRE preparation or native executable launched before rejecting master source"
        assert "FIRE DISCOVER" in (directory / "out" / "native-driver.log").read_text()

    # Read back the two passing reductions exactly in one bounded kernel invocation.
    verify = work / "verify-matching.wls"
    verify.write_text('paths=Rest[$ScriptCommandLine]; ok=And@@Table[r=Get[p]; '
        'r["masters"]==={J[1,1]} && r["rules"][[1,1]]===J[2,1] && '
        'TrueQ[Together[r["rules"][[1,2]]-(d-4) J[1,1]/4]===0],{p,paths}];If[!ok,Exit[1]];\n')
    verified = subprocess.run([args.wolframscript, "-file", str(verify),
        str(work / "matching-point" / "out" / "ibp-reduction.wl"), str(work / "prepared-import-point" / "out" / "ibp-reduction.wl")],
        cwd=work, text=True, capture_output=True, timeout=90)
    (work / "exact-readback.log").write_text(verified.stdout + verified.stderr)
    assert verified.returncode == 0, (verified.stdout, verified.stderr)
    receipt = {"all_expected": True, "focused_step_expectations": len(records), "cases": records,
               "exact_matching_point_readbacks": 2, "fire_preparation_and_reducer_launches": 0,
               "kernel_concurrency": 1, "full_48_case_suite_replayed": False, "native_campaigns": 0}
    write_json(work / "focused-receipt.json", receipt)
    print(f"PASS: {len(records)} focused step expectations and 2 exact matching-point readbacks", flush=True)


if __name__ == "__main__":
    main()
