import json, os, signal, subprocess, sys, time
from pathlib import Path
canon, wolfram, inp, out = sys.argv[1:]
p=Path(out); p.mkdir(parents=True,exist_ok=True)
request=json.loads(Path(inp).read_text()); opts=request['payload']
start=time.monotonic(); cap=float(opts['wall_seconds']); limit=int(opts['memory_bytes'])
env=os.environ.copy(); env.update(OMP_NUM_THREADS='1',MKL_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1')
command=[wolfram,'-file',str(Path(__file__).with_name('profile.wls')),canon,inp,out]
with p.joinpath('kernel.log').open('w') as log:
 child=subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT,env=env,start_new_session=True)
 os.sched_setaffinity(child.pid,{int(opts['cpu'])})
 reason=None; peak=0
 while child.poll() is None:
  rss=0
  pending=[child.pid]
  while pending:
   pid=pending.pop(); q=Path('/proc')/str(pid)
   try:
    pending.extend(map(int,(q/'task'/str(pid)/'children').read_text().split()))
    status=(q/'status').read_text()
    rss+=int(next(x.split()[1] for x in status.splitlines() if x.startswith('VmRSS:')))*1024
   except (OSError,StopIteration,ProcessLookupError): pass
  peak=max(peak,rss)
  if time.monotonic()-start>cap: reason='wall_timeout'
  if rss>limit: reason='resident_memory_limit'
  if reason:
   os.killpg(child.pid,signal.SIGTERM)
   try: child.wait(timeout=2)
   except subprocess.TimeoutExpired: os.killpg(child.pid,signal.SIGKILL); child.wait()
   break
  time.sleep(.1)
 rc=child.wait()
closed=False
for attempt in range(20):
 try: os.killpg(child.pid,0)
 except ProcessLookupError: closed=True; break
 time.sleep(.1)
receipt=dict(command=command,pid=child.pid,elapsed_seconds=time.monotonic()-start,returncode=rc,reason=reason,peak_group_rss_bytes=peak,group_closed=closed,cpu=opts['cpu'],threads=1,wall_seconds=cap,memory_bytes=limit)
p.joinpath('process-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
if not p.joinpath('result.json').exists():
 p.joinpath('result.json').write_text(json.dumps({'status':'INCONCLUSIVE','code':reason or 'PROCESS_INCOMPLETE','scientific_acceptance':False},indent=2)+'\n')
print(json.dumps(receipt))
