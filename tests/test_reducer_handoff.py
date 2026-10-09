#!/usr/bin/env python3
"""Returned and reused reduction artifacts must satisfy the same bridge contract.

Runs a substitute REDUCE_IBP component that only copies a supplied artifact.
No native reducer, scientific family calculation, or research state is involved.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from test_workflow_boundaries import WL, wl

PROVIDER = '''import hashlib,json,shutil,sys
from pathlib import Path
request,output=map(Path,sys.argv[1:])
task=json.loads(request.read_text())
config_path=request.parent/task['payload']['backend']['path']
config=json.loads(config_path.read_text())
output.mkdir()
source=config_path.parent/config['source']
artifact=output/'rules.wl'
if not config.get('missing'):shutil.copyfile(source,artifact)
descriptor={'path':'rules.wl'}
if config.get('pin'):descriptor['sha256']=hashlib.sha256(artifact.read_bytes()).hexdigest().upper() if config['pin']=='valid' else '0'*64
if config.get('absolute'):descriptor['path']=str(artifact.resolve())
(output/'result.json').write_text(json.dumps(dict(schema='canon-neu/script-result/v1',
 task_id=task['task_id'],step='REDUCE_IBP',status='PASS',code='IBP_REDUCED',
 artifacts={'ibp_reduction':descriptor},summary={'scope':'fixture-copy-only'})))
'''


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--canon',required=True,type=Path)
    ap.add_argument('--work',required=True,type=Path)
    ap.add_argument('--observe',action='store_true')
    args=ap.parse_args();root=args.canon.resolve();work=args.work.resolve();work.mkdir(parents=True,exist_ok=False)
    def artifact(name,value):
        p=work/(name+'.wl');p.write_text(wl(value)+'\n');return {'path':str(p)}
    family=artifact('family',WL('<|"family_ref"->"handoff","basis_ref"->"source","topology"->"F","integral_head"->"B","parameters"->{d,x},"variables"->{x},"regulator"->eps,"dimension_rule"->(d->4-2eps),"index_order"->{"D1"},"sector_convention"->"positive indices"|>'))
    basis=artifact('masters',WL('<|"family_ref"->"handoff","basis_ref"->"source","index_order"->{"D1"},"masters"->{B[1]}|>'))
    candidates=artifact('candidates',WL('<|"proposal_id"->"fixture","candidate_pool"-><|"remaining"->0,"pool_exhausted"->True|>,"method_evidence"-><||>,"tool_provenance"-><||>,"candidates"->{<|"candidate_id"->"one","normalization"-><|"factor"->1|>,"exact_definition"->HoldComplete[j[F,1]]|>}|>'))
    derivatives=artifact('derivatives',WL('<|"schema"->"canon.prepared-derivatives/v2","denominator_count"->1,"variables"->{x},"operators"-><|x->{<|"constant"->1,"linear"->{}|>}|>,"exact_strategy"-><|"propagator_slots"->{1}|>|>'))
    provider=work/'provider.py';provider.write_text(PROVIDER)
    instructions=work/'provider.md';instructions.write_text('Copy a declared fixture artifact; no numerical or symbolic reduction.\n')
    manifest=work/'components.json';manifest.write_text(json.dumps(dict(schema='canon-neu/components/v1',steps={'REDUCE_IBP':dict(command=['{python}',str(provider)],instructions=str(instructions))})))
    common=dict(prepared_family=family,master_basis=basis,integral_candidates=candidates,prepared_derivatives=derivatives,derivative_operator_selection='prepared-affine')
    cases=[('exact','{B[2]->eps/x B[1]}','B[1]',None,'PASS','CANDIDATES_REDUCED'),
      ('nonlinear','{B[2]->B[1]^2}','B[1]',None,'INCONCLUSIVE','INCOMPLETE_REDUCTION'),
      ('offset','{B[2]->B[1]+1}','B[1]',None,'INCONCLUSIVE','INCOMPLETE_REDUCTION'),
      ('missing-target','{}','B[1]',None,'INCONCLUSIVE','INCOMPLETE_REDUCTION'),
      ('chain','{B[2]->B[3],B[3]->B[1]}','B[1]',None,'INCONCLUSIVE','INCOMPLETE_REDUCTION'),
      ('inexact','{B[2]->0.5 B[1]}','B[1]',None,'ERROR','INVALID_REDUCTION'),
      ('wrong-masters','{B[2]->eps/x B[1]}','B[3]',None,'ERROR','MASTER_BASIS_MISMATCH'),
      ('master-change','{B[1]->2B[1],B[2]->eps/x B[1]}','B[1]',None,'ERROR','MASTER_BASIS_MISMATCH'),
      ('duplicate','{B[2]->B[1],B[2]->2B[1]}','B[1]',None,'ERROR','INVALID_REDUCTION'),
      ('wrong-family','{B[2]->eps/x B[1]}','B[1]','elsewhere','ERROR','SOURCE_BASIS_MISMATCH'),
      ('cancelled-nonlinearity','{B[2]->((x+1)^2-x^2-2x-1)B[1]^2+eps/x B[1]}','B[1]',None,'PASS','CANDIDATES_REDUCED')]
    records=[]
    def run(name,payload,status,code,collision=None,before_targets=False):
        req=work/(name+'.json');dest=work/name
        if collision:
            dest.mkdir();(dest/collision).write_text('old output\n')
        req.write_text(json.dumps(dict(schema='canon-neu/script-input/v1',task_id=name,step='REDUCE_CANDIDATE_IBP',sector={'id':1,'propagator_count':1},payload={**common,**payload})))
        process=subprocess.run([sys.executable,str(root/'run_step.py'),str(req),str(dest),'--components',str(manifest)],env=os.environ.copy(),cwd=root,capture_output=True,text=True,timeout=60)
        dest.mkdir(exist_ok=True);(dest/'process.log').write_text(process.stdout+process.stderr)
        try:result=json.loads((dest/'result.json').read_text())
        except (FileNotFoundError,json.JSONDecodeError):result={}
        matched=(result.get('status'),result.get('code'))==(status,code) and process.returncode==int(status=='ERROR')
        if status!='PASS':
            matched = matched and set(result.get('artifacts',{}))==(set() if before_targets else {'reduction_targets'})
            if collision!='candidate-ibp-bridge.wl':matched = matched and not (dest/'candidate-ibp-bridge.wl').exists()
        if before_targets:matched = matched and not (dest/'ibp').exists() and not (dest/'ibp-input.json').exists()
        if collision:matched = matched and (dest/collision).read_text()=='old output\n'
        records.append(dict(case=name,result=result,returncode=process.returncode,expected=[status,code],matched=matched))
        (work/'evidence.json').write_text(json.dumps(dict(all_pass=all(r['matched'] for r in records),cases=records,scope='Copied reduction artifacts; no native IBP'),indent=2))
        print(name,result.get('status'),result.get('code'),flush=True)
        if not args.observe:assert matched,records[-1]
    for name,rules,masters,family_ref,status,code in cases:
        value=dict(masters=WL('{'+masters+'}'),rules=WL(rules))
        if family_ref:value['family_ref']=family_ref
        source=artifact('rules-'+name,value)
        config=work/('backend-'+name+'.json');config.write_text(json.dumps(dict(source=source['path'])))
        run(name+'-reuse',dict(ibp_reduction=source),status,code)
        run(name+'-returned',dict(backend={'path':str(config)}),status,code)
    for name,flag,code in [('pin','pin','SOURCE_HASH_MISMATCH'),('missing','missing','MISSING_ARTIFACT')]:
        config=work/('backend-'+name+'.json');config.write_text(json.dumps({'source':str(work/'rules-exact.wl'),flag:True}))
        run(name+'-returned',dict(backend={'path':str(config)}),'ERROR',code)
    for name,extra in [('valid-pin',{'pin':'valid'}),('absolute-reference',{'absolute':True})]:
        config=work/('backend-'+name+'.json');config.write_text(json.dumps({'source':str(work/'rules-exact.wl'),**extra}))
        run(name+'-returned',dict(backend={'path':str(config)}),'PASS','CANDIDATES_REDUCED')
    exact={'path':str(work/'rules-exact.wl')}
    run('input-pin-before-dispatch',dict(master_basis={**basis,'sha256':'0'*64},ibp_reduction=exact),'ERROR','SOURCE_HASH_MISMATCH',before_targets=True)
    run('target-write-before-dispatch',dict(backend={'path':str(work/'backend-exact.json')}),'ERROR','ARTIFACT_WRITE_FAILED',collision='reduction-targets.wl',before_targets=True)
    run('bridge-write-failure',dict(ibp_reduction=exact),'ERROR','ARTIFACT_WRITE_FAILED',collision='candidate-ibp-bridge.wl')
    print(json.dumps({'cases':len(records),'matched':sum(r['matched'] for r in records)}))


if __name__=='__main__':main()
