#!/usr/bin/env python3
"""Build only a caller-selected FLINT utility and record compiler/runtime identity."""
import argparse,hashlib,json,os,pathlib,re,resource,shlex,shutil,subprocess,time
p=argparse.ArgumentParser();p.add_argument('config',type=pathlib.Path);a=p.parse_args();cfg=json.loads(a.config.read_text());w=a.config.parent.resolve()
def sha(p):
 with pathlib.Path(p).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def ident(p):return {'path':str(p),'resolved_path':str(pathlib.Path(p).resolve()),'sha256':sha(p)}
os.sched_setaffinity(0,{cfg['cpu']});env=dict(os.environ,**cfg['environment']);env['TMPDIR']=str(w/'tmp');pathlib.Path(env['TMPDIR']).mkdir(exist_ok=True)
cmd=[shutil.which(cfg['compiler']),*cfg['flags'],str(w/'native/flint_pair.cpp'),*cfg['link_flags'],'-o',str(w/'native/flint_pair')]
start=time.monotonic();r=subprocess.run(cmd,cwd=w,env=env,capture_output=True,text=True,timeout=cfg['timeout_seconds']);usage=resource.getrusage(resource.RUSAGE_CHILDREN)
(w/'build.stdout').write_text(r.stdout);(w/'build.stderr').write_text(r.stderr)
assert r.returncode==0,r.stderr
exe=w/'native/flint_pair';ldd=subprocess.check_output(['ldd',str(exe)],text=True,env=env)
libs=re.findall(r'=> (/\S+)',ldd)
record={'command':cmd,'returncode':r.returncode,'wall_seconds':time.monotonic()-start,'compiler':ident(cmd[0]),'compiler_version':subprocess.check_output([cmd[0],'--version'],text=True),'source':ident(w/'native/flint_pair.cpp'),'executable':ident(exe),'versions':subprocess.check_output([str(exe),'--version'],text=True).splitlines(),'ldd':ldd,'runtime_libraries':[ident(x) for x in libs],'headers':[ident(x) for x in cfg['headers']],'cpu':cfg['cpu'],'environment':cfg['environment'],'compile_peak_rss_bytes':usage.ru_maxrss*1024,'dependency_builds':False}
(w/'build-provenance.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({k:record[k] for k in ['wall_seconds','source','executable','versions','compile_peak_rss_bytes']}))
