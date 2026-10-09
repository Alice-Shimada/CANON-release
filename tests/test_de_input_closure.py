#!/usr/bin/env python3
"""Reject malformed supplied IBP before unit-vector substitution in the DE builder."""
import argparse,json,os,subprocess,sys
from pathlib import Path
from test_workflow_boundaries import WL,wl

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--canon',type=Path,required=True);ap.add_argument('--work',type=Path,required=True);ap.add_argument('--observe',action='store_true');args=ap.parse_args()
 root=args.canon.resolve();out=args.work.resolve();out.mkdir(parents=True,exist_ok=False)
 def artifact(name,expr):
  p=out/(name+'.wl');p.write_text(wl(expr));return {'path':str(p)}
 prepared=artifact('prepared',WL('<|"family_ref"->"linear-fixture","basis_ref"->"raw","dimension"->d,"regulator"->eps,"parameters"->{d,x},"variables"->{x},"dimension_rule"->(d->4-2eps),"index_order"->{"D1"}|>'))
 masters=artifact('masters',WL('<|"family_ref"->"linear-fixture","basis_ref"->"raw","masters"->{B[1]}|>'))
 sectors=artifact('sectors',WL('<|"family_ref"->"linear-fixture","propagator_slots"->{1},"sectors"->{<|"id"->1,"propagator_count"->1,"sector_bits"->{1}|>}|>'))
 derivatives=artifact('derivatives',WL('<|"schema"->"canon.prepared-derivatives/v2","variables"->{x},"denominator_count"->1,"operators"-><|x->{<|"constant"->1,"linear"->{}|>}|>|>'))
 records=[]
 for name,rules in [('exact','{B[2]->eps/x B[1]}'),('nonlinear','{B[2]->B[1]^2}'),('constant-offset','{B[2]->B[1]+1}'),('unclosed','{B[2]->B[3]}'),('duplicate','{B[2]->eps/x B[1],B[2]->0}'),('source-rewrite','{B[2]->eps/x B[1],B[1]->2 B[1]}')]:
  red=artifact('reduction-'+name,WL('<|"masters"->{B[1]},"rules"->'+rules+'|>'))
  request=out/(name+'.json');request.write_text(json.dumps(dict(schema='canon-neu/script-input/v1',task_id=name,step='BUILD_CUT_DE',sector={'id':1,'propagator_count':1},payload=dict(prepared_family=prepared,master_basis=masters,sector_manifest=sectors,prepared_derivatives=derivatives,ibp_reduction=red))))
  dest=out/name;p=subprocess.run([sys.executable,str(root/'run_step.py'),'--defaults',str(request),str(dest)],cwd=root,env=os.environ.copy(),capture_output=True,text=True,timeout=60)
  result=json.loads((dest/'result.json').read_text());(dest/'process.log').write_text(p.stdout+p.stderr)
  expected=('PASS','OK') if name=='exact' else ('ERROR','INVALID_DIFFERENTIAL_EQUATION')
  matched=(result['status'],result['code'])==expected and p.returncode==(0 if name=='exact' else 1)
  records.append(dict(case=name,result=result,matched=matched,exit_code=p.returncode));(out/'evidence.json').write_text(json.dumps(dict(all_pass=all(r['matched'] for r in records),cases=records),indent=2))
  print(name,result['status'],result['code'],flush=True)
  if not args.observe:assert matched,records[-1]
if __name__=='__main__':main()
