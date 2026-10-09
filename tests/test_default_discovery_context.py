#!/usr/bin/env python3
"""Default discovery/native-import symbol identity, using mock native output."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys


SOURCE_INDICES = [(1, 0, 1, -1), (0, 0, 1, 0), (2, 0, 1, -2),
                  (1, -3, 0, -2), (1, 0, 0, 0)]
ORDERED_INDICES = [SOURCE_INDICES[i] for i in (3, 4, 1, 0, 2)]
TARGET = (2, -3, 0, -2)
MOCK = r'''import sys
from pathlib import Path
head, mode = sys.argv[1:3]
def integral(a): return head + "[" + ",".join(map(str,a)) + "]"
indices = [(1,0,1,-1),(0,0,1,0),(2,0,1,-2),(1,-3,0,-2),(1,0,0,0)]
masters = list(reversed(indices))
if mode == "different-set": masters = masters[:-1]
out = Path("results/F");out.mkdir(parents=True)
(out / "masters.final").write_text("\n".join(map(integral,masters)) + "\n")
rules = [integral(a) + " -> " + integral(a) for a in indices]
rules += [integral((2,-3,0,-2)) + " -> (d-4)/x " + integral(indices[3]) + " + 2 " + integral(indices[0])]
(out / "kira_targets.m").write_text("{" + ",".join(rules) + "}\n")
'''
READBACK = r'''{canon,base,headText,expectedCode}=Rest[$ScriptCommandLine];
Get[FileNameJoin[{canon,"mma","lib","MethodCardCore.wl"}]];
read[name_]:=CanonMethodCard`ReadWLData[FileNameJoin[{base,name}]];
head=Block[{$Context="CANON`DEData`",$ContextPath={"System`"}},ToExpression[headText,InputForm]];
basis=read["discover/master-basis.wl"];manifest=read["discover/sector-manifest.wl"];
expected=head@@@{{1,-3,0,-2},{1,0,0,0},{0,0,1,0},{1,0,1,-1},{2,0,1,-2}};
facts=<|"resident_source_order"->(basis["masters"]===expected),
"full_index_order"->AllTrue[basis["masters"],Length[#]===4&],
"noncontiguous_physical_slots"->(manifest["propagator_slots"]==={1,3}),
"sector_order_and_ISP_mask"->(Lookup[manifest["sectors"],"id"]==={1,4,5}&&Lookup[manifest["sectors"],"sector_bits"]==={{1,0,0,0},{0,0,1,0},{1,0,1,0}}),
"master_counts"->(Lookup[manifest["sectors"],"master_count"]==={2,1,2}),
"native_text_source_hash"->(basis["source_sha256"]===FileHash[FileNameJoin[{base,"source-masters"}],"SHA256","HexString"]),
"explicit_context_identity"->(Head[First[basis["masters"]]]===head)|>;
If[expectedCode==="IBP_REDUCED",
 reduction=read["reduce/ibp-reduction.wl"];
 image=Apply[head,{2,-3,0,-2}]/.reduction["rules"];
 target=(CANON`DEData`d-4)/CANON`DEData`x Apply[head,{1,-3,0,-2}]+2 Apply[head,{1,0,1,-1}];
 facts=Join[facts,<|"reduction_preserves_discovery_order"->(reduction["masters"]===basis["masters"]),
 "target_closure_and_coefficients"->(Together[image-target]===0)|>]];
Export[FileNameJoin[{base,"facts.json"}],facts,"RawJSON"];
Exit[If[And@@Values[facts],0,1]];
'''


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--canon", required=True, type=Path)
    p.add_argument("--work", required=True, type=Path)
    p.add_argument("--discover-entry", type=Path)
    p.add_argument("--baseline-entry", type=Path)
    p.add_argument("--components", type=Path, action="append", default=[])
    args = p.parse_args()
    canon, work = args.canon.resolve(), args.work.resolve()
    work.mkdir(parents=True, exist_ok=False)
    entry = (args.discover_entry or canon / "mma/DiscoverSectors.wls").resolve()
    runtime = os.environ.get("CANON_WOLFRAMSCRIPT", "wolframscript")
    env = {**os.environ, "PYTHONDONTWRITEBYTECODE": "1"}
    env.pop("CANON_COMPONENTS", None)
    components = [str(x.resolve()) for x in args.components]
    (work / "mock-native.py").write_text(MOCK, encoding="utf-8")
    (work / "Readback.wls").write_text(READBACK, encoding="utf-8")
    results = {}

    def case(name, typed, source_head, native_head, mode, expected_code, baseline=False):
        base = work / name
        base.mkdir()
        source = "# generic native source list\n" + "\n".join(
            source_head + "[" + ",".join(map(str,a)) + "] # source order" for a in SOURCE_INDICES) + "\n"
        (base / "source-masters").write_text(source)
        family = '''<|"schema"->"canon-neu/prepared-family/v1","family_ref"->"generic-default-discovery",
"basis_ref"->"source","topology"->"F","parameters"->{d,x},"variables"->{x},"regulator"->eps,
"dimension_rule"->(d->4-2 eps),"index_order"->{"D1","N2","D3","N4"},"propagator_slots"->{1,3},
"sector_convention"->"positive physical slots; full index order and zero ISP bits",
"ordered_masters"-><|"path"->"source-masters","sha256"->"SHA"|>HEAD|>'''
        family = family.replace("SHA", sha(base / "source-masters"))
        family = family.replace("HEAD", ',"integral_head"->"' + source_head + '"' if typed else "")
        (base / "family.wl").write_text(family)
        selected = args.baseline_entry.resolve() if baseline else entry
        manifest = {"schema":"canon-neu/components/v1", "steps":{
            "DISCOVER":{"command":["{wolframscript}","-file",str(selected)],
                        "instructions":str(canon/"skills/canon-discover-sectors/SKILL.md")},
            "REDUCE_IBP":{"from":str(canon/"components/default.json")}}}
        write(base / "test-default-components.json",manifest)
        stack = components + [str(base / "test-default-components.json")]

        def run(step, payload, output):
            request = base / (output + ".json")
            write(request,{"schema":"canon-neu/script-input/v1","task_id":name+"-"+step,
                "step":step,"sector":None,"payload":payload})
            cmd=[sys.executable,str(canon/"run_step.py"),str(request),str(base/output)]
            for path in stack: cmd += ["--components",path]
            description=subprocess.run(cmd+["--describe"],env=env,text=True,capture_output=True,check=True)
            desc=json.loads(description.stdout)
            assert desc["components"]==stack
            write(base/(output+"-describe.json"),desc)
            with (base/(output+".log")).open("w") as log:
                process=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=60)
            result=json.loads((base/output/"result.json").read_text())
            assert process.returncode==0,(name,output,result)
            return result,desc

        discover, desc = run("DISCOVER",{"prepared_family":{"path":"family.wl"}},"discover")
        assert (discover["status"],discover["code"])==("PASS","SECTORS_READY")
        # The supplied source vector is discovered, not written by this test.
        basis=str(base/"discover/master-basis.wl")
        (base / "targets.wl").write_text('<|"schema"->"canon-neu/reduction-targets/v1",'
            '"family_ref"->"generic-default-discovery","basis_ref"->"source",'
            '"targets"->{'+source_head+'[2,-3,0,-2]},"masters"->CanonMethodCard`ReadWLData['+
            json.dumps(basis)+']["masters"],"point"->{}|>\n')
        (base / "mock-project").mkdir()
        payload={"reduction":{"project":"mock-project","output":"mock-native-output",
            "executable":sys.executable,"options":[str(work/"mock-native.py"),native_head,mode],
            "jobs":["mock"],"topology":"F","targets":"targets"},
            "reduction_targets":{"path":"targets.wl"},"master_basis":{"path":basis}}
        reduction, rd = run("REDUCE_IBP",payload,"reduce")
        wanted="PASS" if expected_code=="IBP_REDUCED" else "INCONCLUSIVE"
        assert (reduction["status"],reduction["code"])==(wanted,expected_code),(name,reduction)
        facts={}
        if not baseline:
            with (base / "readback.log").open("w") as log:
                subprocess.run([runtime,"-file",str(work/"Readback.wls"),str(canon),str(base),
                    source_head,expected_code],env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=45)
            facts=json.loads((base/"facts.json").read_text())
        results[name]={"discover":{"status":discover["status"],"code":discover["code"]},
            "reduce":{"status":reduction["status"],"code":reduction["code"]},"facts":facts,
            "tested_component_stack":stack,"discovery_entry":str(selected),
            "discovery_entry_sha256":sha(selected),"default_reduction_manifest":rd["manifest"],
            "public_native_import_mock":True,"real_native_Kira":False}

    if args.baseline_entry:
        case("baseline-typed",True,"F","F","normal","MASTER_BASIS_MISMATCH",True)
    case("typed",True,"F","F","normal","IBP_REDUCED")
    case("legacy",False,"F","F","normal","IBP_REDUCED")
    case("explicit-global",True,"Global`F","Global`F","normal","IBP_REDUCED")
    case("explicit-foreign",True,"Foreign`F","Foreign`F","normal","IBP_REDUCED")
    case("context-mismatch",True,"Foreign`F","F","normal","MASTER_BASIS_MISMATCH")
    case("different-master-set",True,"F","F","different-set","MASTER_BASIS_MISMATCH")
    evidence={"schema":"canon.default-discovery-context-regression/v1","all_expected":True,
        "scope":"Public default discovery -> mock legacy reduction, with exact IO readback; no native Kira or physical family calculation",
        "task_components":components,"test_additional_components":"explicit default-entry fixture overrides only DISCOVER and REDUCE_IBP",
        "results":results,"case_count":len(results),"test_source_sha256":sha(Path(__file__)),
        "changed_discovery_entry_sha256":sha(entry),"real_native_Kira":False}
    write(work/"evidence.json",evidence)
    print(json.dumps({"all_expected":True,"case_count":len(results),"evidence":str(work/"evidence.json")}))


if __name__=="__main__":
    main()
