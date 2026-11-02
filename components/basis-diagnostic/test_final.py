import json,os,signal,subprocess,sys,time
from pathlib import Path
canon=Path(sys.argv[1]);inp,out=map(Path,sys.argv[-2:]);out.mkdir(parents=True,exist_ok=True)
opts=json.loads(inp.read_text())['payload'];fixtures=Path(opts['fixtures']);exe=opts['executable'];selection=json.loads(os.environ['CANON_COMPONENTS'])
env=os.environ.copy();env.update(OMP_NUM_THREADS='1',MKL_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1')
runs={}
cases=[('original','positive',False,None),('default','positive',True,None),('flint','positive',True,'flint'),('unresolved','unresolved',True,'flint'),('nonzero','nonzero',True,'flint'),('unsupported','unsupported',True,'flint'),('missing_executable','positive',True,'flint')]
for name,fixture,patched,backend in cases:
 req=json.loads((fixtures/(fixture+'.json')).read_text())
 if backend: req['payload']['method_options']={'basis_backend':backend,'flint_executable':exe,'progress':True}
 if name=='missing_executable':req['payload']['method_options']['flint_executable']=str(out/'missing-program')
 request=out/(name+'.json');request.write_text(json.dumps(req,indent=2)+'\n');dest=out/name
 cmd=[sys.executable,str(canon/'run_step.py'),str(request),str(dest)]
 for component in selection:cmd+=['--components',component]
 if patched:cmd+=['--components',opts['patched_manifest']]
 start=time.monotonic()
 with (out/(name+'.log')).open('w') as log:
  child=subprocess.Popen(['taskset','-c',str(opts['cpu'])]+cmd,stdout=log,stderr=subprocess.STDOUT,env=env,start_new_session=True)
  reason=None
  try:child.wait(timeout=12)
  except subprocess.TimeoutExpired:
   reason='timeout';os.killpg(child.pid,signal.SIGKILL);child.wait()
 result=json.loads((dest/'result.json').read_text()) if (dest/'result.json').exists() else None
 runs[name]={'returncode':child.returncode,'reason':reason,'elapsed_seconds':time.monotonic()-start,'result':result,'pid':child.pid}
 try:os.killpg(child.pid,0);runs[name]['group_closed']=False
 except ProcessLookupError:runs[name]['group_closed']=True
checks={}
def code(name):return runs[name]['result']['code'] if runs[name]['result'] else None
for name in ['original','default','flint']:
 checks[name+'_all14']=code(name)=='ALL_PASS' and len(runs[name]['result']['summary']['checks'])==14 and all(runs[name]['result']['summary']['checks'].values())
checks['default_checks_equal']=runs['original']['result']['summary']['checks']==runs['default']['result']['summary']['checks']
for name in ['unresolved','nonzero']:
 r=runs[name]['result'];checks[name+'_independent_basis_gate']=code(name)=='FULL_SYSTEM_FAIL' and not r['summary']['checks']['basis_definition'] and r['summary']['checks']['exact_global_gauge']
for name in ['unsupported','missing_executable']:
 checks[name+'_operational_error']=code(name)=='UNSUPPORTED_BASIS_ARITHMETIC'
events=[json.loads(x) for x in (out/'flint/final-progress.jsonl').read_text().splitlines()]
checks['progress_records']=all(any(x['phase']==p and x['state']=='end' for x in events) for p in ['dlog_residues','basis_coefficients','basis_product','basis_zero_flint','flat_connection'])
checks['all_children_closed']=all(x['group_closed'] for x in runs.values())
result={'status':'INCONCLUSIVE','code':'FIXTURES_FINISHED','scientific_acceptance':False,'all_pass':all(checks.values()),'checks':checks,'runs':runs}
(out/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'all_pass':result['all_pass'],'checks':checks}))
