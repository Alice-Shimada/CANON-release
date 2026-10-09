#!/usr/bin/env python3
"""Focused SOLVE_TAIL diagnostics with an injected, counted CANONICA fixture."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


FULL_DE = r'''With[{raw = {{{0,0,0},{0,0,0},{TAIL,0,0}}}},
<|"schema"->"canon-neu/full-prefix-candidates/v1", "family_id"->"tail-diagnostic-fixture",
"sector"-><|"id"->7,"propagator_count"->3|>, "current_basis_id"->"fixture/7",
"accepted_prefix_id"->"fixture/lower", "source_basis"->{j1,j2,j3},
"source_matrices"->raw, "variables"->{x}, "regulator"->eps, "alphabet"->{},
"convention"->"old=T.new", "block_boundaries"-><|"lower_dimension"->2,"current_dimension"->1|>,
"candidates"->{<|"candidate_id"->"fixture", "member_candidate_ids"->{"fixture"},
"new_basis_rows"->IdentityMatrix[3], "full_transformation"->IdentityMatrix[3],
"transformed_matrices"->raw|>}|>]
'''

BACKEND = r'''BeginPackage["CANONICA`"];
TransformOffDiagonalBlock; TransformDlogToEpsForm; VerbosityLevel; eps;
Begin["`Private`"];
base = DirectoryName[$InputFileName];
mode = "MODE";
record[stage_, variables_, boundaries_, initial_, matrices_, options_, response_] := Module[{stream},
  stream = OpenAppend[FileNameJoin[{base,"calls.txt"}]];
  WriteString[stream, stage, "\n"]; Close[stream];
  Block[{$Context="Global`", $ContextPath={"System`"}},
    Put[<|"variables"->variables, "sector_boundaries"->boundaries,
      "initial_transformation"->initial, "matrices"->matrices, "options"->options|>,
      FileNameJoin[{base,stage<>"-call.wl"}]];
    Put[With[{saved=response}, HoldComplete[saved]], FileNameJoin[{base,stage<>"-return.wl"}]]];
  response
];
TransformOffDiagonalBlock[v_, b_, t_, a_, o___Rule] := Module[{change, response},
  change = {{1,0},{First[v]/(1+eps First[v]),1}};
  response = If[mode === "off-diagonal-failure",
    {False, {17, "fixture off-diagonal return", TailDiagnosticFixture`pending[]}},
    {t.change, CanonMethodCard`GaugeTransform[a,v,change]}];
  record["TransformOffDiagonalBlock",v,b,t,a,{o},response]
];
TransformDlogToEpsForm[v_, b_, t_, a_, o___Rule] :=
  record["TransformDlogToEpsForm",v,b,t,a,{o},
    If[mode === "epsilon-failure", {False,{t,a}}, {t,a}]];
End[]; EndPackage[];
'''

READBACK = r'''{canon,base}=Take[$CommandLine,-2];
Get[FileNameJoin[{canon,"mma","lib","MethodCardCore.wl"}]];
facts=<||>; counter=0;
TailDiagnosticFixture`pending[] := ++counter;
read[path_] := CanonMethodCard`ReadWLData[FileNameJoin[{base,path}]];
Do[
  name=case[[1]]; stage=case[[2]];
  failure=read[name<>"/output/backend-failure.wl"];
  recorded=read[name<>"/"<>stage<>"-call.wl"];
  expected=read[name<>"/"<>stage<>"-return.wl"];
  AssociateTo[facts,name<>"/schema"->
    (failure["schema"]==="canon-neu/tail-backend-failure/v1")];
  AssociateTo[facts,name<>"/stage"->(failure["stage"]===stage)];
  AssociateTo[facts,name<>"/actual-return"->(failure["backend_return"]===expected)];
  AssociateTo[facts,name<>"/held-return"->(Head[failure["backend_return"]]===HoldComplete)];
  AssociateTo[facts,name<>"/actual-call"->
    (KeyTake[failure["call"],Keys[recorded]]===recorded)];
  AssociateTo[facts,name<>"/active-positions"->
    (failure["call","active_positions"]===If[name==="off-diagonal-failure",{1,3},{1,2,3}])];
  AssociateTo[facts,name<>"/backend-regulator"->(failure["call","regulator"]===CANONICA`eps)];
  AssociateTo[facts,name<>"/package-entry"->
    (failure["package_entry"]===FileNameJoin[{base,name,"CANONICA.m"}])];
  AssociateTo[facts,name<>"/candidate"->(failure["candidate_id"]==="fixture")],
  {case,{{"off-diagonal-failure","TransformOffDiagonalBlock"},
    {"epsilon-failure","TransformDlogToEpsForm"}}}];
AssociateTo[facts,"readback-is-inert"->(counter===0)];
With[{x=CANON`DEData`x,eps=CANON`DEData`eps},
  success=read["backend-success/output/sector-transform.wl"];
  AssociateTo[facts,"success/complete-transformation"->
    (success["transformation"]==={{1,0,0},{0,1,0},{x/(1+eps x),0,1}})];
  AssociateTo[facts,"success/zero-transformed-DE"->
    (success["transformed_matrices"]==={ConstantArray[0,{3,3}]})]];
already=read["already-ready/output/sector-transform.wl"];
AssociateTo[facts,"already-ready/identity"->(already["transformation"]===IdentityMatrix[3])];
Export[FileNameJoin[{base,"readback.json"}],<|"wolfram_version"->$Version,"checks"->facts|>,"RawJSON"];
Exit[If[And@@Values[facts],0,1]];
'''


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--canon", type=Path, required=True)
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--script", type=Path, help="staged SolveTail.wls; defaults to the checkout")
    args = parser.parse_args()
    canon, work = args.canon.resolve(), args.work.resolve()
    script = (args.script or canon / "mma/SolveTail.wls").resolve()
    kernel = os.environ.get("CANON_WOLFRAM_KERNEL") or shutil.which("WolframKernel")
    if not kernel:
        parser.error("requires CANON_WOLFRAM_KERNEL or WolframKernel on PATH")
    work.mkdir(parents=True, exist_ok=False)
    environment = dict(os.environ)
    environment.pop("CANON_COMPONENTS", None)
    environment["PYTHONDONTWRITEBYTECODE"] = "1"
    for key in ("OMP_NUM_THREADS", "MKL_NUM_THREADS", "OPENBLAS_NUM_THREADS",
                "NUMEXPR_NUM_THREADS", "VECLIB_MAXIMUM_THREADS"):
        environment[key] = "1"
    if hasattr(os, "sched_getaffinity"):
        os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    command_prefix = [str(Path(kernel).resolve()), "-noinit", "-noprompt", "-script"]
    manifest = work / "components.json"
    write_json(manifest, {"schema": "canon-neu/components/v1", "steps": {"SOLVE_TAIL": {
        "command": command_prefix + [str(script)],
        "instructions": str(script.parents[1] / "skills/canon-solve-tail/SKILL.md")}}})
    components = [canon / "components/profiles/custom-kira.json",
                  canon / "components/local-jobs/components.json", manifest]
    component_flags = [arg for path in components for arg in ("--components", str(path))]
    results = {}
    cases = {
        "off-diagonal-failure": "1/(1+eps x)^2",
        "epsilon-failure": "1/(1+eps x)^2",
        "backend-success": "1/(1+eps x)^2",
        "algebraic-unsolved": "eps/Sqrt[1+x+x^3]",
        "already-ready": "0",
    }
    for name, tail in cases.items():
        case = work / name
        case.mkdir()
        (case / "full.wl").write_text(FULL_DE.replace("TAIL", tail))
        (case / "core.wl").write_text('<|"candidate_id"->"fixture"|>\n')
        if name in ("off-diagonal-failure", "epsilon-failure", "backend-success"):
            (case / "CANONICA.m").write_text(BACKEND.replace("MODE", name))
        request = case / "request.json"
        write_json(request, {"schema": "canon-neu/script-input/v1", "step": "SOLVE_TAIL",
            "task_id": name, "sector": {"id": 7, "propagator_count": 3}, "payload": {
                "full_sector_de": {"type": "mathematica-expression", "path": "full.wl"},
                "core_transform": {"type": "mathematica-expression", "path": "core.wl"},
                "method_options": {"package_entry": "CANONICA.m"}}})
        command = [sys.executable, str(canon / "run_step.py"), str(request),
                   str(case / "output"), *component_flags]
        if not results:
            described = subprocess.run(command + ["--describe"], env=environment,
                capture_output=True, text=True, check=True)
            description = json.loads(described.stdout)
            assert description["components"] == list(map(str, components))
            assert description["workflows"] == [
                {"manifest": str(canon / "components" / package / "components.json"),
                 "instructions": str(canon / "components" / package / "WORKFLOW.md")}
                for package in ("parameterization", "reducers/kira", "local-jobs")]
            write_json(work / "selected-component.json", description)
        with (case / "process.log").open("w") as log:
            process = subprocess.run(command, env=environment, cwd=case, stdout=log, stderr=subprocess.STDOUT)
        assert process.returncode == 0, (name, process.returncode)
        result = json.loads((case / "output/result.json").read_text())
        calls = (case / "calls.txt").read_text().splitlines() if (case / "calls.txt").exists() else []
        expected_calls = ["TransformOffDiagonalBlock"] if name == "off-diagonal-failure" else (
            ["TransformOffDiagonalBlock", "TransformDlogToEpsForm"]
            if name in ("epsilon-failure", "backend-success") else [])
        assert calls == expected_calls, (name, calls)
        if name.endswith("failure"):
            assert (result["status"], result["code"], result["summary"]["reason"]) == (
                "INCONCLUSIVE", "TAIL_UNSOLVED", "backend_no_transformation"), result
            assert result["summary"]["backend_stage"] == expected_calls[-1], result
            assert result["artifacts"] == {"backend_failure": {
                "type": "mathematica-expression", "path": "backend-failure.wl"}}, result
        elif name == "algebraic-unsolved":
            assert (result["status"], result["code"], result["summary"]["reason"]) == (
                "INCONCLUSIVE", "TAIL_UNSOLVED",
                "remaining_algebraic_tail_outside_rational_CANONICA_domain"), result
            assert result["artifacts"] == {} and "backend_stage" not in result["summary"], result
        else:
            method = "canonica-off-diagonal" if name == "backend-success" else "candidate-completion"
            assert (result["status"], result["code"], result["summary"]) == (
                "PASS", "TAIL_READY", {"candidate_id": "fixture", "method": method}), result
            assert result["artifacts"] == {"sector_transform": {
                "type": "mathematica-expression", "path": "sector-transform.wl"}}, result
            assert not (case / "output/backend-failure.wl").exists()
        results[name] = {"returncode": process.returncode, "calls": calls, "result": result}
    readback = work / "readback.wls"
    readback.write_text(READBACK)
    with (work / "readback.log").open("w") as log:
        checked = subprocess.run(command_prefix + [str(readback), str(canon), str(work)],
            env=environment, cwd=work, stdout=log, stderr=subprocess.STDOUT)
    facts = json.loads((work / "readback.json").read_text())
    assert checked.returncode == 0 and all(facts["checks"].values()), facts
    receipt = {"status": "PASS", "scope": "injected-backend component fixtures; no family run",
        "kernel": command_prefix[0], "cpu_budget": 1, "computation_timeout": None,
        "components": list(map(str, components)),
        "script_sha256": hashlib.sha256(script.read_bytes()).hexdigest(),
        "test_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "cases": results, "readback": facts}
    write_json(work / "verification.json", receipt)
    print(json.dumps({"status": "PASS", "cases": len(results),
        "readback_checks": len(facts["checks"]), "receipt": str(work / "verification.json")}))


if __name__ == "__main__":
    main()
