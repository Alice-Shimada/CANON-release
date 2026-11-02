#!/usr/bin/env python3
"""Bind caller-supplied accepted fixture data; generate no old mathematical data."""
from pathlib import Path
import argparse, copy, hashlib, json
parser=argparse.ArgumentParser();parser.add_argument('--work',type=Path,required=True);args=parser.parse_args()
w=args.work.resolve();cfg=json.loads((w/'test-config.json').read_text());root=Path(cfg['project_root'])
def read(p):return json.loads(Path(p).read_text())
def write(p,x):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(x,indent=2)+'\n')
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def desc(p):return {'path':str(p),'sha256':sha(p)}
bank=read(w/'fixture-bank.json');oldw=Path(bank['accepted_workspace_prefix']);by=read(w/'accepted-fixture-bindings.json')
def accepted(p):
    rel=str(Path(p).relative_to(oldw));record=by.get(rel)
    if not record:record=next((x for x in read(bank['artifact_catalog'])['files'] if x['path']==rel),None)
    if not record:
        assert str(p) in bank['installed_paths'],('No accepted descriptor for',str(p))
        return Path(p)
    return root/record['stored_path']
def rebind(x):
    if isinstance(x,dict):
        z={k:rebind(v) for k,v in x.items()}
        if 'path' in z and str(z['path']).startswith(str(oldw)+'/'):z['path']=str(accepted(z['path']))
        return z
    if isinstance(x,list):return [rebind(v) for v in x]
    return x
base=read(root/by['cases.json']['stored_path']);chosen=set(bank['selected_cases']);runtime=read(w/'runtime.json');cases=[]
for old in base:
    if old['name'] not in chosen:continue
    c=rebind(copy.deepcopy(old));name=c['name'];t=rebind(read(accepted(old['template'])));t['task_id']='T-037:'+name
    opts=t['payload'].setdefault('method_options',{});opts['runtime_config']=desc(w/('runtime-frozen.json' if c['kind']=='build' else 'runtime.json'))
    if c['kind']=='normalization':
        t['payload']['normalizer']=runtime['flint_helper']
        if c['expected_status']=='PASS':
            for field,suffix in [('baseline_postfix','normalization/matrix.postfix'),('baseline_stdout','normalization/native.stdout'),('baseline_matrix','normalized.wl')]:c[field]=desc(accepted(oldw/'results'/name/suffix))
            c.pop('baseline_case',None)
        c['writer']='coefficient-stream'
    if c['kind']=='final':opts['flint_normalization_helper']=runtime['flint_helper'];opts['progress']=name!='bad-basis';c['writer']='coefficient-stream'
    if c['kind']=='build':c['writer']='coefficient-stream'
    c['template']=str(w/'templates'/f'{name}.json');write(Path(c['template']),t);cases.append(c)
for mode in ['open_directory','write_failed','write_message','close_failed','abort_write']:
    b=next(x for x in cases if x['name']=='fast-rational-fixed');c=copy.deepcopy(b)
    c.update(name='io-'+mode,group='io',expected_status='ERROR',expected_code='EXPORT_ABORTED' if mode=='abort_write' else 'FLINT_NORMALIZATION_FAILED')
    t=read(b['template']);t['task_id']='T-037:'+c['name'];t['payload']['stream_fault']=mode
    c['template']=str(w/'templates'/f'{c["name"]}.json');write(Path(c['template']),t);cases.append(c)
for version in ['old','stream']:
    name='benchmark-'+version
    t={'schema':'canon-neu/script-input/v1','task_id':'T-037:'+name,'step':'NORMALIZE_FLINT_BOUNDARY','payload':{'matrix':desc(w/'fixture/matrix.wl'),'normalizer':bank['old_normalizer'] if version=='old' else runtime['flint_helper'],'native_executable':runtime['flint_executable'],'serializer':runtime['flint_serializer'],'method_options':{'runtime_config':desc(w/'runtime.json')}}}
    c={'name':name,'template':str(w/'templates'/f'{name}.json'),'kind':'normalization','group':'stream-benchmark','version':'fast','writer':'monolithic' if version=='old' else 'coefficient-stream','expected_status':'PASS','expected_matrix':desc(w/'fixture/expected.wl')}
    if version=='stream':c['baseline_case']='benchmark-old'
    write(Path(c['template']),t);cases.append(c)
write(w/'cases.json',cases);print(json.dumps({'cases':len(cases),'old_data_regenerated':False}))
