#!/usr/bin/env python3
"""Run fixed public fixtures with caller limits and retained local-jobs ownership."""
import argparse,hashlib,importlib.util,json,os,pathlib,resource,sys,time
sys.dont_write_bytecode=True
p=argparse.ArgumentParser();p.add_argument('--work',required=True,type=pathlib.Path);args=p.parse_args();w=args.work.resolve()
def read(p):return json.loads(pathlib.Path(p).read_text())
def write(p,x):p.parent.mkdir(exist_ok=True,parents=True);p.write_text(json.dumps(x,indent=2)+'\n')
def sha(p):return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
cfg=read(w/'test-config.json');root=pathlib.Path(cfg['project_root']);os.sched_setaffinity(0,{cfg['cpu']});env=dict(os.environ,**cfg['environment']);supportpath=root/'components/local-jobs/support.py';spec=importlib.util.spec_from_file_location('owned',supportpath);owned=importlib.util.module_from_spec(spec);spec.loader.exec_module(owned)
before=read(w/'source-guard-before.json') if (w/'source-guard-before.json').exists() else {p:sha(p) for p in cfg['guarded_sources']};write(w/'source-guard-before.json',before);calls=read(w/'calls.json') if (w/'calls.json').exists() else []
def public(request,output):
 if output.joinpath('result.json').exists():
  assert any(c['output']==str(output) and c['group_closed'] for c in calls),'Unrecorded result; no silent replay'
  return read(output/'result.json')
 budget=w/'execution-budget.json'
 if not budget.exists():write(budget,{'first_launch_epoch':time.time(),'first_launch_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'computation_seconds':cfg['allocation_seconds'],'collection_seconds':cfg['overall_collection_seconds']})
 remaining=read(budget)['first_launch_epoch']+cfg['allocation_seconds']-time.time()
 assert remaining>=cfg['execution_timeout_seconds']+cfg['cancellation_grace_seconds'],'Budget exhausted; no reset'
 argv=[cfg['python'],str(root/'run_step.py'),str(request),str(output)]
 for c in cfg['complete_components']:argv+=['--components',c]
 owner=None;peak=0;exceeded=False;observations={}
 def launched(pid):
  nonlocal owner;owner=pid
 def cancelled():
  nonlocal peak,exceeded
  pending=[owner] if owner else [];total=0
  while pending:
   pid=pending.pop()
   try:
    proc=pathlib.Path('/proc')/str(pid);d=dict(l.split(':',1) for l in (proc/'status').read_text().splitlines() if ':' in l);rss=int(d.get('VmRSS','0 kB').split()[0])*1024;total+=rss;cmd=(proc/'cmdline').read_bytes().replace(b'\0',b' ').decode(errors='replace')
    observations[pid]={'pid':pid,'group':os.getpgid(pid),'name':d['Name'].strip(),'affinity':d['Cpus_allowed_list'].strip(),'command':cmd,'rss_bytes':rss}
    pending.extend(map(int,(proc/'task'/str(pid)/'children').read_text().split()))
   except (OSError,ValueError):pass
  peak=max(peak,total);exceeded=peak>cfg['rss_limit_bytes'];return exceeded
 start=time.monotonic();old=resource.getrusage(resource.RUSAGE_CHILDREN);logpath=w/'logs'/(output.parent.name+'-'+output.name+'.log');logpath.parent.mkdir(exist_ok=True)
 with logpath.open('w') as log:code,reason=owned.run_owned(argv,str(root),env,log,cancelled=cancelled,timeout=cfg['execution_timeout_seconds'],grace=cfg['cancellation_grace_seconds'],launched=launched)
 usage=resource.getrusage(resource.RUSAGE_CHILDREN)
 try:os.killpg(owner,0);closed=False
 except ProcessLookupError:closed=True
 result=read(output/'result.json') if (output/'result.json').exists() else None
 row={'request':str(request),'output':str(output),'argv':argv,'returncode':code,'stop_reason':reason,'owned_group':owner,'group_closed':closed,'wall_seconds':time.monotonic()-start,'child_cpu_seconds':usage.ru_utime+usage.ru_stime-old.ru_utime-old.ru_stime,'suite_cumulative_peak_rss_bytes':usage.ru_maxrss*1024,'sampled_aggregate_rss_bytes':peak,'rss_limit_exceeded':exceeded,'process_observations':list(observations.values()),'status':result['status'] if result else None,'code':result['code'] if result else None,'ownership_helper_sha256':sha(supportpath)}
 calls.append(row);write(w/'calls.json',calls);print(json.dumps({k:row[k] for k in ['output','status','code','wall_seconds','group_closed']}),flush=True)
 assert closed and not exceeded and reason is None and result is not None,row
 return result
for case in read(w/'cases.json'):
 bind=w/'bindings'/(case['name']+'.json');write(bind,{'schema':'canon-neu/script-input/v1','task_id':'T-032:bind:'+case['name'],'step':'PREPARE_REQUEST','payload':{'template':{'path':case['template']}}});prepared=w/'prepared'/case['name'];assert public(bind,prepared)['status']=='PASS'
 r=public(prepared/'request.json',w/'results'/case['name']);assert r['status']==case['expected_status'],(case,r)
 if case['expected_status']=='ERROR':assert r['code']==case['expected_code']
r=public(w/'verify.json',w/'verified');after={p:sha(p) for p in cfg['guarded_sources']};write(w/'source-guard-after.json',{'hashes':after,'unchanged':before==after});assert r['status']=='PASS',r
report={'all_pass':read(w/'verified/checks.json')['all_pass'],'checks':read(w/'verified/checks.json')['check_count'],'all_groups_closed':all(c['group_closed'] for c in calls),'public_calls':len(calls),'wall_seconds':sum(c['wall_seconds'] for c in calls),'child_cpu_seconds':sum(c['child_cpu_seconds'] for c in calls),'maximum_sampled_aggregate_rss_bytes':max(c['sampled_aggregate_rss_bytes'] for c in calls),'source_unchanged':before==after,'all_observed_cpu22':all(o['affinity']==str(cfg['cpu']) for c in calls for o in c['process_observations']),'no_observed_Fermat':not any(o['name'] in ['fer64','fermat'] for c in calls for o in c['process_observations']),'scientific_acceptance':False}
write(w/'report.json',report);print(json.dumps(report),flush=True);assert all(report[k] for k in ['all_pass','all_groups_closed','source_unchanged','all_observed_cpu22','no_observed_Fermat'])
