#!/usr/bin/env python3
"""Validate caller source pins, then exec native in the public owner's group."""
import hashlib
import json
import os
from pathlib import Path
import sys

script, request, output = map(lambda s: Path(s).resolve(), sys.argv[1:])
task = json.loads(request.read_text())
output.mkdir(parents=True, exist_ok=False)
def sha(path):
    with Path(path).open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()
def descriptor(base, value):
    path = Path(value['path'])
    path = path if path.is_absolute() else base.parent / path
    if sha(path) != value['sha256']:
        raise ValueError('Declared runtime hash mismatch')
    return path.resolve()
try:
    runtime_file = descriptor(request, task['payload']['method_options']['runtime_config'])
    cfg = json.loads(runtime_file.read_text())
    def configured_path(value):
        path = Path(value)
        return path if path.is_absolute() else runtime_file.parent / path
    for source in cfg['source_identity']:
        if sha(configured_path(source['path'])) != source['sha256']:
            raise ValueError('Original provider/library bytes changed')
    os.sched_setaffinity(0, {cfg['cpu']})
    env = os.environ.copy()
    env.update({k:'1' for k in ('OMP_NUM_THREADS','MKL_NUM_THREADS','OPENBLAS_NUM_THREADS')})
    argv = [*cfg['kernel_command'], str(script), str(request), str(output)]
    (output/'launch.json').write_text(json.dumps({'argv':argv,'pid':os.getpid(),
        'process_group':os.getpgrp(),'cpu_affinity':sorted(os.sched_getaffinity(0)),
        'thread_environment':{k:env[k] for k in ('OMP_NUM_THREADS','MKL_NUM_THREADS','OPENBLAS_NUM_THREADS')},
        'runtime_config_sha256':sha(runtime_file),'source_identity':cfg['source_identity'],
        'script_sha256':sha(script),'execution_owner':'Calling public execution owner; exec inherits its process group. No extra native session.',
        'declared_fixture_timeout_seconds':cfg['execution_timeout_seconds'],
        'declared_fixture_grace_seconds':cfg['cancellation_grace_seconds'],
        'declared_sampled_rss_limit_bytes':cfg['rss_limit_bytes']},indent=2)+'\n')
    os.execve(argv[0], argv, env)
except (KeyError,ValueError,OSError) as exc:
    (output/'result.json').write_text(json.dumps({'schema':'canon-neu/script-result/v1',
        'task_id':task['task_id'],'step':task['step'],'status':'ERROR','code':'INVALID_ARITHMETIC_RUNTIME',
        'artifacts':{},'summary':{'reason':str(exc),'scientific_acceptance':False}},indent=2)+'\n')
    sys.exit(1)
