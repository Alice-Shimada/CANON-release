#!/usr/bin/env python3
"""Exercise the candidate bridge with independent and legacy reducer adapters."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


FAMILY = '''<|"family_ref"->"bridge-fixture", "basis_ref"->"source-basis",
"topology"->"sampleFamily", "integral_head"->"G", "parameters"->{d,x},
"variables"->{x}, "dimension_rule"->(d->4-2 eps),
"sector_convention"->"positive index", "index_order"->{"D1"}|>'''
MASTERS = '''<|"schema"->"canon-neu/master-basis/v1", "family_ref"->"bridge-fixture",
"basis_ref"->"source-basis", "index_order"->{"D1"}, "masters"->{G[1]}|>'''
CANDIDATES = '''<|"proposal_id"->"supplied-tadpole",
"candidate_pool"-><|"remaining"->0,"pool_exhausted"->True|>,
"method_evidence"-><||>, "tool_provenance"-><|"tool"->"analytic fixture"|>,
"candidates"->{<|"candidate_id"->"x-times-master", "normalization"-><|"factor"->x|>,
"exact_definition"->HoldComplete[j[sampleFamily,1]]|>,
<|"candidate_id"->"legacy-head-tag", "normalization"-><|"factor"->x|>,
"exact_definition"->HoldComplete[j[G,1]]|>,
<|"candidate_id"->"direct-integral-head", "normalization"-><|"factor"->x|>,
"exact_definition"->HoldComplete[G[1]]|>}|>'''
DERIVATIVES = '''<|"schema"->"canon.prepared-derivatives/v2", "variables"->{x},
"denominator_count"->1, "operators"-><|x->{<|"constant"->1,"linear"->{}|>}|>,
"exact_strategy"-><|"baikov_variables"->{z},"propagator_slots"->{1},
"loop_count"->1,"independent_external_count"->0,"fixed_scale_substitutions"->{},
"external_gram_determinant"->1,"baikov_polynomial"->z-x,"search_max_total_degree"->0|>|>'''
REDUCTION = '<|"masters"->{G[1]},"rules"->{G[2]->(1-d/2)/x G[1]}|>'
FORBIDDEN_REDUCER = '''import pathlib,sys
pathlib.Path(__file__).with_name('forbidden-reducer-called').write_text('unexpected reducer launch')
sys.exit(99)
'''

FAKE_KIRA = '''import pathlib,sys
project=pathlib.Path.cwd()
assert 'G[2]' in (project/'targets').read_text()
result=project/'results/G'; result.mkdir(parents=True)
mode=sys.argv[1]
(result/'masters.final').write_text('G[3]\\n' if mode=='basis' else 'G[1]\\n')
(result/'kira_targets.m').write_text('{}' if mode=='missing' else '{G[2]->(1-d/2)/x G[1]}')
'''
FAKE_ADAPTER = '''import json,pathlib,sys
source,output=map(pathlib.Path,sys.argv[1:])
task=json.loads(source.read_text()); payload=task['payload']
config=json.loads((source.parent/payload['backend']['path']).read_text())
assert config['adapter']=='independent-fixture'
assert 'G[2]' in (source.parent/payload['reduction_targets']['path']).read_text()
assert 'reduction' not in payload and 'project' not in payload
output.mkdir()
(output/'ibp-reduction.wl').write_text('<|"masters"->{G[1]},"rules"->{G[2]->(1-d/2)/x G[1]}|>')
(output/'seen-request.json').write_text(json.dumps(task,indent=2))
(output/'result.json').write_text(json.dumps({'schema':'canon-neu/script-result/v1',
'task_id':task['task_id'],'step':'REDUCE_IBP',
'status':'INCONCLUSIVE' if config.get('incomplete') else 'PASS',
'code':'EXPLICIT_CONVERSION_NEEDED' if config.get('incomplete') else 'IBP_REDUCED',
'artifacts':{'ibp_reduction':{'type':'mathematica-expression','path':'ibp-reduction.wl'}},
'summary':{'scope':'synthetic adapter boundary; supplied analytic tadpole rule'}}))
sys.exit(config.get('exit_code',0))
'''
CHECK = '''{canon,base} = Rest[$ScriptCommandLine];
Get[FileNameJoin[{canon,"mma","lib","MethodCardCore.wl"}]];
facts = <||>;
Do[
  b = CanonMethodCard`ReadWLData[FileNameJoin[{base,mode,"candidate-ibp-bridge.wl"}]];
  targets = CanonMethodCard`ReadWLData[FileNameJoin[{base,mode,"reduction-targets.wl"}]];
  g = Head[First[b["masters"]]]; d = Symbol["CANON`DEData`d"]; x = First[b["variables"]];
  facts[mode<>"/metadata"] = b["topology"]==="G" && b["masters"]==={g[1]};
  facts[mode<>"/ids"] = Lookup[b["candidates"],"candidate_id"]===
    {"x-times-master","legacy-head-tag","direct-integral-head"};
  facts[mode<>"/reduction_targets"] = targets["targets"]==={g[2]} &&
    Lookup[b["reducer_targets"],"integral"]==={g[2]};
  affine = MemberQ[{"custom-affine","reuse"},mode];
  facts[mode<>"/operator"] = If[affine,
    b["operators",x,"kind"]==="prepared-affine" &&
      b["operators",x,"enhanced_search_attempted"]===False,
    b["operators",x,"kind"]==="enhanced-baikov"];
  Do[
    key = mode<>"/"<>c["candidate_id"]<>"/";
    facts[key<>"expression"] = Together[c["expression"]-x g[1]]===0;
    facts[key<>"derivative"] = Together[c["derivatives"][x]-
      If[affine,g[1]-x g[2],d/2 g[1]]]===0;
    facts[key<>"reduced_expression"] = Together[c["reduced_expression"]-x g[1]]===0;
    facts[key<>"reduced_derivative"] = Together[c["reduced_derivatives"][x]-d/2 g[1]]===0;
    facts[key<>"candidate_targets"] = Lookup[c["targets"],"integral"]===
      If[affine,{g[1],g[2]},{g[1]}],
    {c,b["candidates"]}],
  {mode,{"custom","legacy","custom-affine","reuse"}}];
b = CanonMethodCard`ReadWLData[FileNameJoin[{base,"reuse-tail","candidate-ibp-bridge.wl"}]];
g=Head[First[b["masters"]]]; x=First[b["variables"]]; d=Symbol["CANON`DEData`d"];
c=First[b["candidates"]];
facts["reuse-tail/master-order"] = b["masters"]==={g[1],g[0]};
facts["reuse-tail/ids"] = Lookup[b["candidates"],"candidate_id"]===
  {"x-times-master","legacy-head-tag","direct-integral-head"};
facts["reuse-tail/full-expression"] = Together[c["reduced_expression"]-x(g[1]+g[0])]===0;
facts["reuse-tail/full-derivative"] = Together[c["reduced_derivatives"][x]-d/2 g[1]-(1-x) g[0]]===0;
facts["reuse-tail/targets"] = Lookup[b["reducer_targets"],"integral"]==={g[2]};
Export[FileNameJoin[{base,"facts.json"}],facts,"RawJSON"];
Exit[If[AllTrue[Values[facts],TrueQ],0,1]];
'''


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--canon", type=Path, required=True)
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--components", type=Path, action="append", default=[],
                        help="Ordered component stack to preserve before the test reducer override")
    args = parser.parse_args()
    canon, work = args.canon.resolve(), args.work.resolve()
    work.mkdir(parents=True, exist_ok=False)
    tree = work / "source tree with spaces"
    tree.mkdir()
    for name, content in (("family.wl", FAMILY), ("masters.wl", MASTERS),
                          ("candidates.wl", CANDIDATES), ("derivatives.wl", DERIVATIVES),
                          ("fake_kira.py", FAKE_KIRA), ("fake_adapter.py", FAKE_ADAPTER),
                          ("forbidden_reducer.py", FORBIDDEN_REDUCER)):
        (tree / name).write_text(content)
    (tree / "instructions.md").write_text("Synthetic independent reducer fixture.\n")
    write_json(tree / "backend.json", {"adapter": "independent-fixture"})
    write_json(tree / "backend-incomplete.json", {"adapter": "independent-fixture", "incomplete": True, "exit_code": 3})
    write_json(tree / "backend-invalid-exit.json", {"adapter": "independent-fixture", "exit_code": 3})
    write_json(tree / "adapter.json", {"schema": "canon-neu/components/v1", "steps": {
        "REDUCE_IBP": {"command": ["{python}", "{package}/fake_adapter.py"],
                       "instructions": "instructions.md"}}})
    write_json(tree / "selection.json", {"schema": "canon-neu/components/v1", "steps": {
        "REDUCE_IBP": {"from": "adapter.json"}}})
    write_json(tree / "reuse-selection.json", {"schema": "canon-neu/components/v1", "steps": {
        "REDUCE_IBP": {"command": ["{python}", "{package}/forbidden_reducer.py"],
                       "instructions": "instructions.md"}}})
    # Keep the evaluated profile, then override only REDUCE_IBP for this fixture.
    write_json(tree / "legacy-selection.json", {"schema": "canon-neu/components/v1", "steps": {
        "REDUCE_IBP": {"from": str(canon / "components/default.json")}}})
    project = tree / "native project"
    project.mkdir()
    (project / "job.yaml").write_text("jobs: []\n")
    (project / "targets").write_text("unchanged original target file\n")
    payload = {key: {"path": name} for key, name in (
        ("prepared_family", "family.wl"), ("master_basis", "masters.wl"),
        ("integral_candidates", "candidates.wl"), ("prepared_derivatives", "derivatives.wl"))}
    for mode in ("custom", "legacy", "basis", "missing", "custom-incomplete", "custom-invalid-exit",
                 "custom-affine", "custom-invalid-selection", "custom-invalid-selection-type"):
        selected = dict(payload)
        if mode.startswith("custom"):
            suffix = mode.removeprefix("custom") if mode in (
                "custom-incomplete", "custom-invalid-exit") else ""
            selected["backend"] = {"path": "backend" + suffix + ".json"}
        else:
            selected["reduction"] = {"executable": sys.executable, "project": "native project",
                "jobs": ["job.yaml"], "topology": "G", "targets": "targets",
                "output": f"native-{mode}", "options": [str(tree / "fake_kira.py"), mode]}
        if mode == "custom-affine":
            selected["derivative_operator_selection"] = "prepared-affine"
        elif mode == "custom-invalid-selection":
            selected["derivative_operator_selection"] = "unknown-operator"
        elif mode == "custom-invalid-selection-type":
            selected["derivative_operator_selection"] = 7
        write_json(tree / f"{mode}.json", {"schema": "canon-neu/script-input/v1", "task_id": mode,
            "step": "REDUCE_CANDIDATE_IBP", "sector": {"id": 1, "propagator_count": 1}, "payload": selected})
    reuse_rules = {
        "reuse": REDUCTION,
        "reuse-missing": '<|"masters"->{G[1]},"rules"->{}|>',
        "reuse-unreduced": '<|"masters"->{G[1]},"rules"->{G[2]->G[3],G[3]->G[1]}|>',
        "reuse-nonlinear": '<|"masters"->{G[1]},"rules"->{G[2]->G[1]^2}|>',
        "reuse-master-change": REDUCTION.replace('G[2]->', 'G[1]->2 G[1],G[2]->'),
        "reuse-identity": REDUCTION.replace('<|', '<|"family_ref"->"wrong","basis_ref"->"wrong",', 1),
        "reuse-invalid-rules": REDUCTION.replace('G[2]->', 'G[2]->0,G[2]->'),
        "reuse-order": REDUCTION.replace('{G[1]}', '{G[0],G[1]}'),
        "reuse-tail": REDUCTION.replace('{G[1]}', '{G[1],G[0]}').replace(
            '(1-d/2)/x G[1]', '(1-d/2)/x G[1]+G[0]').replace(
            '<|', '<|"family_ref"->"bridge-fixture","basis_ref"->"source-basis",', 1),
    }
    (tree / "two-masters.wl").write_text(MASTERS.replace('{G[1]}', '{G[1],G[0]}'))
    (tree / "tail-candidates.wl").write_text(CANDIDATES.replace(
        'HoldComplete[j[sampleFamily,1]]', 'HoldComplete[j[sampleFamily,1]+j[sampleFamily,0]]', 1))
    for mode, rules in reuse_rules.items():
        (tree / (mode + "-rules.wl")).write_text(rules)
        selected = {**payload, "derivative_operator_selection": "prepared-affine",
                    "ibp_reduction": {"path": mode + "-rules.wl"}}
        if mode in ("reuse-order", "reuse-tail"):
            selected["master_basis"] = {"path": "two-masters.wl"}
        if mode == "reuse-tail":
            selected["integral_candidates"] = {"path": "tail-candidates.wl"}
        write_json(tree / f"{mode}.json", {"schema": "canon-neu/script-input/v1", "task_id": mode,
            "step": "REDUCE_CANDIDATE_IBP", "sector": {"id": 1, "propagator_count": 1}, "payload": selected})
    # Move the custom selection and backend config before their first use.
    moved = work / "relocated tree with spaces"
    tree.rename(moved)
    for mode in ("legacy", "basis", "missing"):
        task = json.loads((moved / f"{mode}.json").read_text())
        task["payload"]["reduction"]["options"][0] = str(moved / "fake_kira.py")
        write_json(moved / f"{mode}.json", task)
    environment = dict(os.environ)
    environment.pop("CANON_COMPONENTS", None)
    expected = {"custom": "CANDIDATES_REDUCED", "legacy": "CANDIDATES_REDUCED",
                "basis": "MASTER_BASIS_MISMATCH", "missing": "INCOMPLETE_REDUCTION",
                "custom-incomplete": "EXPLICIT_CONVERSION_NEEDED", "custom-invalid-exit": "REDUCTION_FAILED",
                "custom-affine": "CANDIDATES_REDUCED",
                "custom-invalid-selection": "DERIVATIVE_OPERATOR_INVALID",
                "custom-invalid-selection-type": "DERIVATIVE_OPERATOR_INVALID",
                "reuse": "CANDIDATES_REDUCED", "reuse-tail": "CANDIDATES_REDUCED",
                "reuse-missing": "INCOMPLETE_REDUCTION", "reuse-unreduced": "INCOMPLETE_REDUCTION",
                "reuse-nonlinear": "INCOMPLETE_REDUCTION", "reuse-master-change": "MASTER_BASIS_MISMATCH",
                "reuse-identity": "SOURCE_BASIS_MISMATCH", "reuse-order": "MASTER_BASIS_MISMATCH",
                "reuse-invalid-rules": "INVALID_REDUCTION"}
    components = [path.resolve() for path in args.components] or [canon / "components/profiles/custom-kira.json"]
    results = {}
    for mode, code in expected.items():
        output = moved / mode
        command = [sys.executable, str(canon / "run_step.py"), str(moved / f"{mode}.json"), str(output)]
        for manifest in components:
            command += ["--components", str(manifest)]
        is_reuse = mode.startswith("reuse")
        selection = "reuse-selection.json" if is_reuse else "selection.json" if mode.startswith("custom") else "legacy-selection.json"
        command += ["--components", str(moved / selection)]
        with (work / f"{mode}.log").open("w") as log:
            process = subprocess.run(command, env=environment, stdout=log, stderr=subprocess.STDOUT)
        result = json.loads((output / "result.json").read_text())
        invalid_selection = mode.startswith("custom-invalid-selection")
        error = mode == "custom-invalid-exit" or invalid_selection or (
            is_reuse and code not in ("CANDIDATES_REDUCED", "INCOMPLETE_REDUCTION"))
        assert process.returncode == (1 if error else 0) and result["code"] == code, (mode, process.returncode, result)
        if is_reuse:
            assert not (moved / "forbidden-reducer-called").exists()
            assert not (output / "ibp-input.json").exists() and not (output / "ibp").exists()
            assert (output / "reduction-targets.wl").is_file()
            if code != "CANDIDATES_REDUCED":
                assert set(result["artifacts"]) == {"reduction_targets"}
                assert not (output / "candidate-ibp-bridge.wl").exists()
            if code == "INCOMPLETE_REDUCTION":
                assert result["status"] == "INCONCLUSIVE"
                assert len(result["summary"]["unresolved_targets"]) == 1
                assert 'G[2]' in result["summary"]["unresolved_targets"][0]
            if mode == "reuse-unreduced":
                assert 'G[3]' in result["summary"]["target_images"][0]
            if mode == "reuse-identity":
                assert result["summary"]["mismatched_fields"] == ["family_ref", "basis_ref"]
        if invalid_selection:
            assert result["status"] == "ERROR" and result["artifacts"] == {}
            assert not (output / "ibp-input.json").exists()
            assert not (output / "reduction-targets.wl").exists()
            assert not (output / "ibp").exists()
        results[mode] = {"status": result["status"], "code": result["code"]}
    assert (moved / "native project/targets").read_text() == "unchanged original target file\n"
    assert not tree.exists()
    check = work / "Check.wls"
    check.write_text(CHECK)
    runtime = shutil.which(os.environ.get("CANON_WOLFRAMSCRIPT", "wolframscript"))
    with (work / "check.log").open("w") as log:
        subprocess.run([runtime, "-file", str(check), str(canon), str(moved)], stdout=log,
                       stderr=subprocess.STDOUT, check=True)
    facts = json.loads((moved / "facts.json").read_text())
    assert all(facts.values())
    write_json(work / "evidence.json", {"all_expected": True, "results": results, "facts": facts,
        "components": [str(path) for path in components], "invalid_selection_stopped_before_reducer": True,
        "native_project_untouched": True, "relocated_custom_selection": True,
        "reuse_never_dispatched_reducer": True, "reuse_failure_preserves_targets": True,
        "scope": "candidate bridge live dispatch and supplied-reduction boundary with synthetic rules"})
    print(json.dumps({"results": results, "facts": facts}, indent=2))


if __name__ == "__main__":
    main()
