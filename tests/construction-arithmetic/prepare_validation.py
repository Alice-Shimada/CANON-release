#!/usr/bin/env python3
"""Bind caller-owned literal fixture banks; never load physical DE or invent targets."""
import argparse
import hashlib
import json
from pathlib import Path

def read(p):return json.loads(Path(p).read_text())
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def descriptor(p):return {'path':str(Path(p).resolve()),'sha256':sha(p)}
def write(p,x):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(x,indent=2)+'\n')
def absolute_descriptor(d,base):
 p=Path(d['path']);p=p if p.is_absolute() else base.parent/p
 assert sha(p)==d['sha256'],('Caller fixture identity mismatch',p)
 return descriptor(p)
def resolve_tree(x,base):
 if isinstance(x,dict):
  if 'path' in x and 'sha256' in x:return absolute_descriptor(x,base)
  return {k:resolve_tree(v,base) for k,v in x.items()}
 if isinstance(x,list):return [resolve_tree(v,base) for v in x]
 return x

def main():
 p=argparse.ArgumentParser();p.add_argument('--work',type=Path,required=True);a=p.parse_args();w=a.work.resolve();cfg=read(w/'test-config.json')
 rt=read(cfg['normal_runtime']);fixtures=Path(cfg['fixture_directory']);cases=[]
 def normal(name,matrix,status='PASS',expected=None,code='UNSUPPORTED_FLINT_DOMAIN'):
  for version,key in [('old','legacy_normalizer'),('new','current_normalizer')]:
   n=version+'-'+name;t=w/'templates'/(n+'.json')
   write(t,{'schema':'canon-neu/script-input/v1','task_id':'validation:'+n,'step':'NORMALIZE_FLINT_BOUNDARY','payload':{'matrix':matrix,'normalizer':cfg[key],'native_executable':rt['flint_executable'],'method_options':{'runtime_config':descriptor(cfg['normal_runtime'])}}})
   c={'name':n,'kind':'normalization','group':name,'version':version,'template':str(t),'expected_status':status,'expected_code':code}
   if expected:c['expected_matrix']=expected
   cases.append(c)
 for item in read(fixtures/'index.json')['cases']:
  name=item['name'];normal(name,descriptor(fixtures/item['path']),'PASS' if name in ['rational','quadratic','constants','numeric-root'] else 'ERROR',code='FLINT_NORMALIZATION_FAILED' if name=='Indeterminate' else 'UNSUPPORTED_FLINT_DOMAIN')
 for item in cfg.get('retained_normalization_cases',[]):normal(item['name'],item['input'],item.get('expected_status','PASS'),item.get('expected_matrix'),item.get('expected_code','UNSUPPORTED_FLINT_DOMAIN'))
 normal('synthetic',descriptor(fixtures/'synthetic.wl'))
 for item in cfg['final_cases']:
  template=Path(item['template']);t=resolve_tree(read(template),template);t['task_id']='validation:'+item['name'];opts=t['payload']['method_options'];opts['runtime_config']=descriptor(cfg['normal_runtime']);opts['flint_normalization_helper']=cfg['current_normalizer']
  for key in ['flint_gauge_helper','flint_source']:
   if key in cfg:opts[key]=cfg[key]
  path=w/'templates'/(item['name']+'.json');write(path,t);cases.append({**item,'kind':'final','template':str(path)})
 write(w/'cases.json',cases)
if __name__=='__main__':main()
