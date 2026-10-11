#!/usr/bin/env python3
"""Verify native Blade template symbol bindings with a counted package fixture.

Runs the actual adapter/driver/normalizer, but no native scientific engine.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

PACKAGE = r'''BeginPackage["Blade`"];
BLFamilyDefine; BLReduce; BLDifferentialEquation; BLFamilyInf; BL;
Begin["`Private`"];
require[q_] := If[!TrueQ[q], Print["Native symbol frame mismatch"]; Exit[9]];
BLFamilyDefine[family_,dimension_,propagators_,loops_,external_,conservation_,kinematics_,top_,point_] := (
 require[family===Global`toy && dimension===4-2 Global`eps && loops==={Global`l} &&
  external==={Global`p,Global`q} && kinematics==={Global`p^2->Global`x,Global`q^2->Global`y,Global`p Global`q->0} && point==={}];
 Export["family-binding.json",<|"passed"->True|>,"RawJSON"]
);
BLReduce[targets_,preferred_,name_,opts___] := (
 require[AllTrue[Join[targets,preferred], Head[#]===Blade`BL && First[#]===Global`toy &]];
 storedMasters=preferred;
 If[MemberQ[preferred,#],#,0]&/@targets
);
BLFamilyInf[family_] := <|"Masters"->storedMasters,"MastersRules"->{}|>;
BLDifferentialEquation[variables_,preferred_,name_,opts___] := (
 require[variables==={Global`x,Global`y} && AllTrue[preferred,First[#]===Global`toy &]];
 Export["derivative-binding.json",<|"passed"->True|>,"RawJSON"];
 {preferred,variables,{Global`eps/Global`x IdentityMatrix[Length[preferred]],Global`eps/Global`y IdentityMatrix[Length[preferred]]}}
);
End[];EndPackage[];
'''


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--canon',type=Path,required=True)
    ap.add_argument('--work',type=Path,required=True)
    args=ap.parse_args();root=args.canon.resolve();work=args.work.resolve();work.mkdir(parents=True,exist_ok=False)
    runtime=os.environ.get('CANON_WOLFRAMSCRIPT','wolframscript')
    package=root/'components/reducers/native-adapter'
    proc=subprocess.run([runtime,'-file',str(package/'tests/PrepareCases.wls'),str(package),str(work)],capture_output=True,text=True,timeout=60)
    (work/'prepare.log').write_text(proc.stdout+proc.stderr)
    assert proc.returncode==0, proc.stdout+proc.stderr
    base=work/'base';backend=base/'blade/backend.json';cfg=json.loads(backend.read_text())
    (backend.parent/'FixtureBlade.wl').write_text(PACKAGE)
    (backend.parent/'settings.wl').write_text('<||>')
    cfg.update(package_entry='FixtureBlade.wl',settings='settings.wl',threads=1,software_revision='synthetic-frame-fixture')
    for step,exports in [('REDUCE_IBP',{'masters':'masters.wl','rules':'rules.wl'}),('BUILD_CUT_DE',{'de':'de.wl'})]:
        cfg['operations'][step].update(mode='command',argv=['{wolframscript}','-file','{package}/native.wls','{context}'],exports=exports)
    backend.write_text(json.dumps(cfg,indent=2))
    facts={}
    for step in ('REDUCE_IBP','BUILD_CUT_DE'):
        output=base/('native-frame-'+step.lower())
        cmd=[sys.executable,str(root/'run_step.py'),str(base/('blade-'+step+'.json')),str(output),'--components',str(root/'components/reducers/blade/components.json')]
        proc=subprocess.run(cmd,capture_output=True,text=True,timeout=60)
        result=json.loads((output/'result.json').read_text());facts[step]=result['status']=='PASS' and proc.returncode==0
        (work/(step+'.log')).write_text(proc.stdout+proc.stderr)
        assert facts[step],result
        assert json.loads((output/'native/family-binding.json').read_text())['passed']
        if step=='BUILD_CUT_DE':assert json.loads((output/'native/derivative-binding.json').read_text())['passed']
    (work/'evidence.json').write_text(json.dumps({'all_pass':all(facts.values()),'checks':facts,'native_engine_executed':False},indent=2))
    print(json.dumps(facts))


if __name__=='__main__':main()
