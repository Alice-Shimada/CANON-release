#!/usr/bin/env python3
"""Kira adapter symbol contexts using the existing synthetic native-format fixture."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


CHECK = r'''{canon,base}=Rest[$ScriptCommandLine];
Get[FileNameJoin[{canon,"mma","lib","MethodCardCore.wl"}]];
read[name_]:=CanonMethodCard`ReadWLData[FileNameJoin[{base,name,"ibp-reduction.wl"}]];
normal=read["normal"]; numeric=read["numeric-point"];
dimension=read["dimension"]; foreign=read["foreign-dimension"];
facts=<|
"source_order"->(normal["masters"]==={CANON`DEData`B[1,1],CANON`DEData`B[1,0]}),
"kinematic_coefficient"->(normal["rules"]==={CANON`DEData`B[2,1]->CANON`DEData`s CANON`DEData`B[1,0]+2 CANON`DEData`B[1,1]}),
"numeric_binding"->(numeric["rules"]==={CANON`DEData`B[2,1]->7 CANON`DEData`B[1,0]+2 CANON`DEData`B[1,1]}),
"canonical_native_dimension"->(dimension["rules"]==={CANON`DEData`B[2,1]->CANON`DEData`s CANON`DEData`B[1,0]+CANON`DEData`d CANON`DEData`B[1,1]}),
"dimension_substitution"->(First[dimension["rules"]][[2]]/.(CANON`DEData`d->4-2 CANON`DEData`eps))===(CANON`DEData`s CANON`DEData`B[1,0]+(4-2 CANON`DEData`eps) CANON`DEData`B[1,1]),
"explicit_foreign_dimension_preserved"->(foreign["rules"]==={CANON`DEData`B[2,1]->CANON`DEData`s CANON`DEData`B[1,0]+Foreign`dim CANON`DEData`B[1,1]})|>;
Export[FileNameJoin[{base,"facts.json"}],facts,"RawJSON"];
Exit[If[And@@Values[facts],0,1]];
'''


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--canon", type=Path, required=True)
    p.add_argument("--work", type=Path, required=True)
    p.add_argument("--components", type=Path, action="append", default=[])
    args = p.parse_args()
    canon, work = args.canon.resolve(), args.work.resolve()
    work.mkdir(parents=True)
    fixture = canon / "components/reducers/kira/tests/run.py"
    spec = importlib.util.spec_from_file_location("kira_context_fixture", fixture)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    fake = module.FAKE.replace('(out/"kira_targets.m").write_text(rule)',
        'if mode in ("dimension","foreign-dimension"): rule="{native_family[2,1] -> d native_family[1,1]+s native_family[1,0]}"\n(out/"kira_targets.m").write_text(rule)')
    (work / "fixture.py").write_text(fake)
    family = {"schema":"canon-neu/reducer-family/v1","family_ref":"context-fixture","basis_ref":"context-source",
        "topology":"native_family","integral_head":"B","index_order":["D1","D2"],"propagator_slots":[1,2],
        "top_level_sectors":[3],"loop_momenta":["l"],"external_momenta":["p"],
        "propagators":[{"momentum":"l","mass_squared":"0"},{"momentum":"l-p","mass_squared":"0"}],
        "scalar_products":[{"momenta":["p","p"],"value":"s"}],"invariants":[{"name":"s","mass_dimension":2}],
        "point":[],"dimension":"d","variables":["s"],"regulator":"eps","dimension_rule":"d->4-2*eps"}
    targets='<|"schema"->"canon-neu/reduction-targets/v1","family_ref"->"context-fixture","basis_ref"->"context-source","targets"->{B[2,1]},"masters"->{B[1,1],B[1,0]},"point"->POINT|>'
    (work / "basis.wl").write_text('<|"family_ref"->"context-fixture","basis_ref"->"context-source","masters"->{B[1,1],B[1,0]}|>')
    cases={"normal":("PASS","IBP_REDUCED"),"numeric-point":("PASS","IBP_REDUCED"),
        "dimension":("PASS","IBP_REDUCED"),"foreign-dimension":("PASS","IBP_REDUCED"),
        "different-basis":("INCONCLUSIVE","NATIVE_BASIS_MISMATCH"),
        "unreduced":("INCONCLUSIVE","UNREDUCED_NATIVE_OUTPUT"),"nonlinear":("ERROR","NATIVE_RULES_NOT_LINEAR")}
    results={}
    environment=dict(os.environ)
    environment.pop("CANON_COMPONENTS",None)
    components=[str(x.resolve()) for x in args.components]+[str(canon/"components/reducers/kira/components.json")]
    for name,expected in cases.items():
        declared=dict(family)
        point="{}"
        if name=="numeric-point":
            declared.update(invariants=[],point=[{"variable":"s","value":"7"}],scalar_products=[{"momenta":["p","p"],"value":"7"}])
            point="{s->7}"
        if name=="foreign-dimension": declared["dimension"]="Foreign`dim"
        write(work/(name+"-family.json"),declared)
        (work/(name+"-targets.wl")).write_text(targets.replace("POINT",point))
        write(work/(name+"-backend.json"),{"schema":"canon-neu/kira-backend/v1","executable":sys.executable,
            "options":[str(work/"fixture.py"),name],"seed":{"r":3,"s":0,"d":1},"timeout_seconds":5})
        payload={"reducer_family":{"path":name+"-family.json"},"backend":{"path":name+"-backend.json"},
            "master_basis":{"path":"basis.wl"},"reduction_targets":{"path":name+"-targets.wl"}}
        write(work/(name+".json"),{"schema":"canon-neu/script-input/v1","task_id":name,"step":"REDUCE_IBP","sector":None,"payload":payload})
        command=[sys.executable,str(canon/"run_step.py"),str(work/(name+".json")),str(work/name)]
        for c in components:command += ["--components",c]
        with (work/(name+".log")).open("w") as log:
            result=subprocess.run(command,env=environment,stdout=log,stderr=subprocess.STDOUT,timeout=60)
        receipt=json.loads((work/name/"result.json").read_text())
        assert (receipt["status"],receipt["code"])==expected,(name,receipt)
        assert (result.returncode==0)==(expected[0]=="PASS")
        results[name]={"returncode":result.returncode,"status":receipt["status"],"code":receipt["code"]}
    (work/"Checks.wls").write_text(CHECK)
    runtime=shutil.which(os.environ.get("CANON_WOLFRAMSCRIPT","wolframscript"))
    with (work/"checks.log").open("w") as log:
        subprocess.run([runtime,"-file",str(work/"Checks.wls"),str(canon),str(work)],check=True,stdout=log,stderr=subprocess.STDOUT,timeout=30)
    facts=json.loads((work/"facts.json").read_text())
    assert all(facts.values())
    write(work/"evidence.json",{"scope":"selected Kira adapter with synthetic native-format fixture; no native Kira",
        "components":components,"all_expected":True,"results":results,"facts":facts})
    print(json.dumps({"results":results,"facts":facts},indent=2))


if __name__=="__main__":main()
