#!/usr/bin/env python3
"""Prepare fixed exact native inverse fixtures from caller runtime and template bindings."""
import argparse,copy,hashlib,json,pathlib
p=argparse.ArgumentParser();p.add_argument('--work',required=True,type=pathlib.Path);args=p.parse_args();w=args.work.resolve();cfg=json.loads((w/'test-config.json').read_text());root=pathlib.Path(cfg['project_root'])
def read(p):return json.loads(pathlib.Path(p).read_text())
def sha(p):return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
def put(p,x):p.parent.mkdir(exist_ok=True,parents=True);p.write_text(json.dumps(x,indent=2)+'\n')
def desc(p):return {'path':str(p),'sha256':sha(p)}
p0='(1+x+2*y+x*y+x^3+y^2)';q0='(2+x^2+3*y+x*y^2)';l='(1+x+y^2)';a='(1+x^2+y)';b='(2+x*y)';e=f'({a}+{b}*Sqrt[{l}])'
polynomial='+'.join(f'{i+1}*x^{i%17}*y^{i//17}*z^{(i*i+3*i)%19}' for i in range(256))
matrices={'rational':f'{{{{{p0}^-1,{p0}^-3,{q0}/{p0},({p0}/{q0})^-3}}}}',
'quadratic':f'{{{{{e}^-1,{l}^(-1/2),{e}^-3,-{l}^(-3/2)}}}}',
'constants':'{{-3,5/7,(-11/13)^-3,7^-1}}',
'zero-rational':'{{(x^2-(x-1)*(x+1)-1)^-1}}',
'zero-quadratic':'{{(x+Sqrt[x^2])^-1}}',
'benchmark':'{{('+polynomial+')^-1}}'}
for k,s in matrices.items():
 p=w/'fixtures'/(k+'.wl');p.parent.mkdir(exist_ok=True);p.write_text(s+'\n')
put(w/'benchmark-design.json',{'design':'Exactly one fixed 256-term three-variable polynomial inverse, no tuning or repeats. Exponents x=i mod17,y=floor(i/17),z=(i*i+3*i) mod19; coefficient i+1, i=0..255.','input':desc(w/'fixtures/benchmark.wl'),'input_bytes':(w/'fixtures/benchmark.wl').stat().st_size,'cpu':cfg['cpu'],'threads':1,'repetitions':1})
cases=[]
for name in matrices:
 for mode in ['old','new']:
  case=name+'-'+mode
  opts={'normalization_backend':'together','normalization_backends':{'candidate_lower_transform_reduce':'flint'},'runtime_config':desc(pathlib.Path(cfg[mode+'_runtime']))}
  payload={'matrix':desc(w/'fixtures'/(name+'.wl')),'arithmetic_helper':cfg['arithmetic_helper'],'method_options':opts}
  t=w/'templates'/(case+'.json');put(t,{'schema':'canon-neu/script-input/v1','task_id':'T-032:'+case,'step':'NORMALIZE_FLINT_FIXTURE','payload':payload})
  row={'name':case,'fixture':name,'kind':'normalize','mode':mode,'template':str(t),'expected_status':'ERROR' if name.startswith('zero-') else 'PASS'}
  if row['expected_status']=='ERROR':row['expected_code']='ARITHMETIC_NORMALIZATION_FAILED'
  cases.append(row)
for fixture,template in cfg['final_templates'].items():
 for mode in ['new','reference']:
  request=copy.deepcopy(template);case='final-'+fixture+'-'+mode;case=cfg.get('final_case_names',{}).get(case,case);request['task_id']='T-032:'+case
  opts=request['payload']['method_options'];opts['runtime_config']=desc(pathlib.Path(cfg['final_runtime']))
  opts['flint_executable']=cfg['new_executable']['path'];opts['flint_executable_sha256']=cfg['new_executable']['sha256'];opts['flint_source']=cfg['new_source']
  if mode=='reference':
   request['payload']['method_options']={'gauge_backend':'wolfram','progress':True,'runtime_config':desc(pathlib.Path(cfg['final_runtime']))}
  t=w/'templates'/(case+'.json');put(t,request)
  cases.append({'name':case,'fixture':fixture,'kind':'final','mode':mode,'template':str(t),'expected_status':'PASS'})
put(w/'cases.json',cases)
put(w/'verify.json',{'schema':'canon-neu/script-input/v1','task_id':'T-032:verify','step':'VERIFY_NATIVE_INVERSE','payload':{'cases':cases,'result_directory':str(w/'results'),'method_options':{'runtime_config':desc(pathlib.Path(cfg['final_runtime']))}}})
print(json.dumps({'cases':len(cases),'benchmark_terms':256}))
