#!/usr/bin/env python3
"""Public structural-converter probe: literal bytes only, never Wolfram evaluation."""
import hashlib,json,os,subprocess,sys
from pathlib import Path
request,output=map(lambda p:Path(p).resolve(),sys.argv[1:]);task=json.loads(request.read_text());output.mkdir(parents=True,exist_ok=False)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def resolve(d):
 p=Path(d['path']);p=p if p.is_absolute() else request.parent/p
 if sha(p)!=d['sha256']:raise ValueError('Checked probe descriptor changed')
 return p.resolve()
try:
 rt=resolve(task['payload']['method_options']['runtime_config']);cfg=json.loads(rt.read_text());os.sched_setaffinity(0,{cfg['cpu']});env=os.environ.copy();env.update({k:'1' for k in ['OMP_NUM_THREADS','MKL_NUM_THREADS','OPENBLAS_NUM_THREADS']})
 spec=task['payload']['serializer'];exe=resolve(spec['executable']);source=resolve(spec['source']);literal=resolve(task['payload']['structural_input']);argv=[str(exe),str(literal),str(output/'matrix.postfix')]
 (output/'launch.json').write_text(json.dumps({'argv':argv,'pid':os.getpid(),'process_group':os.getpgrp(),'cpu_affinity':sorted(os.sched_getaffinity(0)),'runtime_config_sha256':sha(rt),'serializer_executable_sha256':sha(exe),'serializer_source_sha256':sha(source),'literal_input_sha256':sha(literal),'execution_owner':'Caller public group; subprocess inherits it, no detached group.'},indent=2)+'\n')
 r=subprocess.run(argv,env=env,capture_output=True);(output/'serializer.stdout').write_bytes(r.stdout);(output/'serializer.stderr').write_bytes(r.stderr)
 status='PASS' if r.returncode==0 else 'ERROR';code='STRUCTURAL_CONVERTED' if r.returncode==0 else 'STRUCTURAL_INPUT_REJECTED';summary={'converter_returncode':r.returncode,'postfix_exists':(output/'matrix.postfix').exists(),'scientific_acceptance':False,'native_arithmetic_started':False}
except (ValueError,KeyError,OSError) as e:status='ERROR';code='SERIALIZER_UNAVAILABLE';summary={'reason':str(e),'scientific_acceptance':False,'native_arithmetic_started':False}
(output/'result.json').write_text(json.dumps({'schema':'canon-neu/script-result/v1','task_id':task['task_id'],'step':task['step'],'status':status,'code':code,'artifacts':{},'summary':summary},indent=2)+'\n');sys.exit(0 if status=='PASS' else 2)
