#!/usr/bin/env python3
"""Neutral serialized artifact contexts through the public canonical pipeline."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


FILES = {
    "family": '''<|"family_ref"->"neutral-context", "basis_ref"->"neutral/source",
"topology"->"F", "integral_head"->"F", "parameters"->{d,x,y}, "variables"->{x,y},
"regulator"->eps, "dimension_rule"->(d->4-2 eps), "index_order"->{"D1"}|>''',
    "masters": '''<|"family_ref"->"neutral-context", "basis_ref"->"neutral/source",
"masters"->{F[1]}, "index_order"->{"D1"}|>''',
    "basis": '''<|"schema"->"canon-neu/sector-basis/v1", "family_id"->"neutral-context",
"basis_id"->"neutral/1", "sector"-><|"id"->1,"propagator_count"->1|>, "basis"->{F[1]}|>''',
    "cut": '''<|"schema"->"canon-neu/sector-cut-de/v1", "family_id"->"neutral-context",
"basis_id"->"neutral/1", "sector"-><|"id"->1,"propagator_count"->1|>, "basis"->{F[1]},
"variables"->{x,y}, "regulator"->eps, "coefficient_domain"->"exact-rational-functions",
"matrices"->{{{(eps-1)/x}},{{2 eps/y}}}|>''',
    "ordered": '''<|"schema"->"canon-neu/ordered-master-de/v1", "family_id"->"neutral-context",
"basis_id"->"neutral/source", "basis"->{F[1]}, "variables"->{x,y}, "regulator"->eps,
"matrices"->{{{(eps-1)/x}},{{2 eps/y}}}|>''',
    "manifest": '''<|"family_ref"->"neutral-context", "basis_ref"->"neutral/source",
"sectors"->{<|"id"->1,"propagator_count"->1,"positions"->{1}|>}|>''',
    "bridge": '''<|"schema"->"canon-neu/candidate-ibp-bridge/v1",
"family_ref"->"neutral-context", "basis_ref"->"neutral/source", "masters"->{CANON`DEData`F[1]},
"variables"->{CANON`DEData`x,CANON`DEData`y}, "tool_provenance"-><|"tool"->"neutral analytic fixture"|>,
"candidate_pool"-><|"remaining"->0,"pool_exhausted"->True|>,
"candidates"->{<|"candidate_id"->"x-dimension-prefactor",
"reduced_expression"->CANON`DEData`x (CANON`DEData`d-4) CANON`DEData`F[1]|>}|>''',
}

READBACK = r'''{canon,base,mode}=Rest[$ScriptCommandLine];
Get[FileNameJoin[{canon,"mma","lib","MethodCardCore.wl"}]];
request=Import[FileNameJoin[{base,"route.json"}],"RawJSON"];
load[name_]:=CanonMethodCard`LoadArtifact[request,FileNameJoin[{base,"route.json"}],name];
family=load["prepared_family"]; basis=load["sector_basis"]; bridge=load["candidate_ibp_bridge"];
row=Coefficient[First[bridge["candidates"]]["reduced_expression"],First[basis["basis"]]];
facts=<|"source_basis_matches"->(bridge["masters"]===basis["basis"]),
"dimension_rule_matches"->!FreeQ[First[bridge["candidates"]]["reduced_expression"],First[family["dimension_rule"]]],
"variables_match"->(bridge["variables"]===family["variables"]), "projection_nonzero"->(row=!=0)|>;
If[mode==="baseline",
 Export[FileNameJoin[{base,"readback.json"}],facts,"RawJSON"];
 Exit[If[!Or@@Values[facts],0,1]]];
read[path_]:=CanonMethodCard`ReadWLData[FileNameJoin[{base,path}]];
routed=read["route/core-candidates.wl"];
core=read["core/core-transform.wl"];
prefix=read["commit/accepted-prefix.wl"];
de=read["final/canonical-de.wl"];
x=CANON`DEData`x; y=CANON`DEData`y; eps=CANON`DEData`eps;
facts=Join[facts,<|
"one_nonempty_group"->(Length[routed["candidates"]]===1),
"dimension_substitution"->(routed["candidates"][[1]]["new_basis_rows"]==={{-2 eps x}}),
"expected_inverse_row"->(Together[core["transformation"][[1,1]]+1/(2 eps x)]===0),
"gauge_derivative_term"->(Together[core["transformed_matrices"][[1,1,1]]-eps/x]===0),
"second_variable"->(Together[core["transformed_matrices"][[2,1,1]]-2 eps/y]===0),
"committed_basis"->(Together[First[prefix["basis"]]+2 eps x CANON`DEData`F[1]]===0),
"regulator_and_variable_identity"->(de["regulator"]===eps && de["variables"]==={x,y}),
"independent_final_checks"->And@@Values[de["checks"]]|>];
Export[FileNameJoin[{base,"readback.json"}],facts,"RawJSON"];
Exit[If[And@@Values[facts],0,1]];
'''


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--canon", type=Path, required=True)
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--components", type=Path, action="append", default=[])
    parser.add_argument("--baseline", action="store_true")
    args = parser.parse_args()
    canon, work = args.canon.resolve(), args.work.resolve()
    work.mkdir(parents=True, exist_ok=False)
    for name, value in FILES.items():
        (work / (name + ".wl")).write_text(value + "\n")
    components = [str(p.resolve()) for p in args.components]
    environment = dict(os.environ)
    environment.pop("CANON_COMPONENTS", None)
    results = {}

    def descriptor(name):
        return {"type": "mathematica-expression", "path": name + ".wl"}

    def run(name, step, payload, expected=None):
        request = work / (name + ".json")
        write_json(request, {"schema": "canon-neu/script-input/v1", "task_id": name,
            "step": step, "sector": {"id": 1, "propagator_count": 1}, "payload": payload})
        command = [sys.executable, str(canon / "run_step.py"), str(request), str(work / name)]
        for path in components:
            command += ["--components", path]
        with (work / (name + ".log")).open("w") as log:
            process = subprocess.run(command, env=environment, stdout=log, stderr=subprocess.STDOUT, timeout=90)
        result = json.loads((work / name / "result.json").read_text())
        results[name] = {"returncode": process.returncode, "status": result["status"], "code": result["code"],
                         "summary": result["summary"]}
        if expected is not None:
            assert (process.returncode, result["status"], result["code"]) == expected, (name, results[name])
        return {key: {**value, "path": str(work / name / value["path"])}
                for key, value in result["artifacts"].items()}

    route_payload = {key: descriptor(name) for key, name in (
        ("prepared_family", "family"), ("sector_basis", "basis"),
        ("sector_cut_de", "cut"), ("candidate_ibp_bridge", "bridge"))}
    routed = run("route", "ROUTE_CORE_CANDIDATES", route_payload,
                 None if args.baseline else (0, "PROVISIONAL", "CORE_CANDIDATES_ROUTED"))
    if not args.baseline:
        core = run("core", "CHECK_CORE", {**route_payload, **routed}, (0, "PASS", "CORE_PASS"))
        full = run("full", "BUILD_FULL_DE", {**routed, **core, "ordered_master_de": descriptor("ordered"),
            "sector_cut_de": descriptor("cut"), "declared_alphabet": None, "accepted_prefix": None}, (0, "PASS", "OK"))
        tail = run("tail", "SOLVE_TAIL", {**full, **core}, (0, "PASS", "TAIL_READY"))
        canonical = run("canonical", "CHECK_CANONICAL", {**full, **tail}, (0, "PASS", "CANONICAL_PASS"))
        committed = run("commit", "COMMIT_SECTOR", {**tail, **canonical,
            "sector_basis": descriptor("basis"), "previous_accepted_prefix": None}, (0, "PASS", "OK"))
        run("final", "FINAL_CHECK", {**committed, "prepared_family": descriptor("family"),
            "master_basis": descriptor("masters"), "sector_manifest": descriptor("manifest"),
            "ordered_master_de": descriptor("ordered")}, (0, "PASS", "ALL_PASS"))
        variants = {
            "foreign-basis": FILES["bridge"].replace("CANON`DEData`F", "Foreign`F"),
            "foreign-variable": FILES["bridge"].replace("CANON`DEData`x", "Foreign`x"),
            "rank-zero": FILES["bridge"].replace("CANON`DEData`x (CANON`DEData`d-4) CANON`DEData`F[1]", "0"),
        }
        for name, text in variants.items():
            (work / (name + ".wl")).write_text(text + "\n")
            run(name, "ROUTE_CORE_CANDIDATES", {**route_payload, "candidate_ibp_bridge": descriptor(name)},
                (0, "PROVISIONAL", "CORE_CANDIDATES_ROUTED") if name == "rank-zero"
                else (1, "ERROR", "SOURCE_BASIS_MISMATCH"))
        assert results["rank-zero"]["summary"]["candidate_ids"] == []
    check = work / "Readback.wls"
    check.write_text(READBACK)
    runtime = shutil.which(os.environ.get("CANON_WOLFRAMSCRIPT", "wolframscript"))
    with (work / "readback.log").open("w") as log:
        subprocess.run([runtime, "-file", str(check), str(canon), str(work),
                        "baseline" if args.baseline else "fixed"], check=True,
                       stdout=log, stderr=subprocess.STDOUT, timeout=60)
    facts = json.loads((work / "readback.json").read_text())
    write_json(work / "evidence.json", {"scope": "neutral public serialized context boundary",
        "baseline": args.baseline, "components": components, "results": results, "facts": facts})
    print(json.dumps({"baseline": args.baseline, "results": results, "facts": facts}, indent=2))


if __name__ == "__main__":
    main()
