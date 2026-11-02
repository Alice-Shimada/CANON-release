#!/usr/bin/env python3
"""Bind independent FINAL fixture outputs to caller-provided runtime/backend paths."""
import argparse,copy,hashlib,json
from pathlib import Path

def read(p):return json.loads(Path(p).read_text())
def write(p,v):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(v,indent=2)+"\n")
def prepare(w):
    cfg=read(w/'test-config.json');fixtures=Path(cfg['fixture_directory']).resolve()
    def path(p):return (w/Path(p)).resolve()
    def ref(p):
        p=path(p);return {'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
    def bind_options(v):
        if isinstance(v,dict):
            if 'path' in v:
                checked=ref(v['path'])
                if 'sha256' in v:assert checked['sha256']==v['sha256']
                return {**v,**checked}
            return {k:bind_options(x) for k,x in v.items()}
        if isinstance(v,list):return [bind_options(x) for x in v]
        return v
    options=bind_options(cfg['gauge_options']);options['runtime_config']=ref(cfg['normal_runtime'])
    options['flint_executable']=str(path(options['flint_executable']))
    cases=[]
    def add(name,task,status,kind,fixture,**extra):
        task['task_id']=cfg.get('task_id','final-flint-regression')+':'+name
        p=w/'templates'/(name+'.json');write(p,task)
        cases.append({'name':name,'template':str(p),'expected_status':status,'kind':kind,'fixture':fixture,**extra})
    def final(fixture):
        task=read(fixtures/(fixture+'.json'))
        for k,v in task['payload'].items():task['payload'][k]=ref(fixtures/v['path'])
        task['payload']['method_options']=copy.deepcopy(options);return task
    for name,fixture,status in [('rational-new-basis','rational','PASS'),('quadratic-mixed-gauge','quadratic','PASS'),('bad-gauge','bad-gauge','FAIL'),('bad-basis','bad-basis','FAIL')]:
        add(name,final(fixture),status,'final',fixture,expected_code='FULL_SYSTEM_FAIL' if status=='FAIL' else 'ALL_PASS')
    for fixture in ['rational','quadratic']:
        task=final(fixture);task['payload']['method_options'].update(gauge_backend='wolfram',basis_backend='wolfram')
        add(fixture+'-reference',task,'PASS','final',fixture,expected_code='ALL_PASS')
    for fixture in ['unequal','nested','inexact']:
        task={'schema':'canon-neu/script-input/v1','step':'PROBE_FINAL_GAUGE','payload':{'gauge_input':ref(fixtures/(fixture+'-probe.wl')),'method_options':copy.deepcopy(options)}}
        add('domain-'+fixture,task,'ERROR','domain',fixture,expected_code='UNSUPPORTED_GAUGE_ARITHMETIC')
    if cfg.get('fault_native'):
        task=final('rational');fault=ref(cfg['fault_native']);task['payload']['method_options'].update(flint_executable=fault['path'],flint_executable_sha256=fault['sha256'])
        add('native-error',task,'ERROR','final','rational',expected_code='GAUGE_ARITHMETIC_FAILED',environment={'CANON_TEST_FLINT_REAL_EXE':options['flint_executable'],'CANON_TEST_FLINT_FAULT':'native-error'})
    task=final('rational');task['payload']['method_options']['flint_executable_sha256']='0'*64
    add('native-pin-mismatch',task,'ERROR','final','rational',expected_code='GAUGE_BACKEND_UNAVAILABLE')
    task=final('rational');task['payload']['method_options']['flint_executable']=str(w/'ABSENT_NATIVE')
    add('native-unavailable',task,'ERROR','final','rational',expected_code='GAUGE_BACKEND_UNAVAILABLE')
    if cfg.get('empty_gauge_helper'):
        task=final('rational');task['payload']['method_options']['flint_gauge_helper']=ref(cfg['empty_gauge_helper'])
        add('helper-init-failure',task,'ERROR','final','rational',expected_code='GAUGE_BACKEND_UNAVAILABLE')
    write(w/'cases.json',cases);return cases
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--work',type=Path,required=True);prepare(p.parse_args().work.resolve())
