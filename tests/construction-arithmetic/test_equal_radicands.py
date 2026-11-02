#!/usr/bin/env python3
"""Tiny public policy fixtures using the existing owned-group lifetime."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import resource
import sys
import time
sys.dont_write_bytecode=True

def read(path): return json.loads(Path(path).read_text())
def write(path,value):
    Path(path).parent.mkdir(parents=True,exist_ok=True)
    Path(path).write_text(json.dumps(value,indent=2)+"\n")
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def read_proc_status(pid):
    return {l.split(":",1)[0]:l.split(":",1)[1].strip() for l in (Path("/proc")/str(pid)/"status").read_text().splitlines() if ":" in l}

def main():
    parser=argparse.ArgumentParser();parser.add_argument("--work",type=Path,required=True)
    args=parser.parse_args();w=args.work.resolve();cfg=read(w/"test-config.json");root=Path(cfg["project_root"])
    os.sched_setaffinity(0,{cfg["cpu"]});environment=os.environ.copy();environment.update(cfg["environment"])
    source=root/"components/local-jobs/support.py"
    spec=importlib.util.spec_from_file_location("canon_owned",source);support=importlib.util.module_from_spec(spec);spec.loader.exec_module(support)
    before=read(w/"source-guard-before.json") if (w/"source-guard-before.json").exists() else {p:sha(p) for p in cfg["guarded_sources"]};write(w/"source-guard-before.json",before)
    cases=read(w/"cases.json");calls=read(w/"calls.json") if (w/"calls.json").exists() else []
    def public(request,output,extra_components=(),extra_environment=None):
        budget=w/"execution-budget.json"
        if not budget.exists():write(budget,{"first_launch_epoch":time.time(),"first_launch_utc":time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime()),"computation_seconds":cfg["allocation_seconds"],"collection_seconds":cfg["overall_collection_seconds"]})
        remaining=read(budget)["first_launch_epoch"]+cfg["allocation_seconds"]-time.time()
        assert remaining>=cfg["execution_timeout_seconds"]+cfg["cancellation_grace_seconds"],"Overall engineering allocation exhausted; no cap reset."
        argv=[cfg["python"],str(root/"run_step.py"),str(request),str(output)]
        for c in cfg["complete_components"]+list(extra_components):argv += ["--components",c]
        owner=None;peak=0;exceeded=False;native=None
        def launched(pid):
            nonlocal owner;owner=pid
        def cancelled():
            nonlocal peak,exceeded,native
            pending=[owner] if owner else [];total=0
            while pending:
                pid=pending.pop()
                try:
                    p=Path("/proc")/str(pid);d={l.split(":",1)[0]:l.split(":",1)[1].strip() for l in (p/"status").read_text().splitlines() if ":" in l}
                    rss=int(d.get("VmRSS","0 kB").split()[0])*1024;total+=rss
                    if d.get("Name")=="WolframKernel":native={"pid":pid,"group":os.getpgid(pid),"affinity":d["Cpus_allowed_list"],"rss_bytes":rss}
                    pending += [int(x) for x in (p/"task"/str(pid)/"children").read_text().split()]
                except (OSError,ValueError):pass
            peak=max(peak,total);exceeded=peak>cfg["rss_limit_bytes"];return exceeded
        call_environment=dict(environment);call_environment.update(extra_environment or {})
        start=time.monotonic();old=resource.getrusage(resource.RUSAGE_CHILDREN)
        logpath=w/"logs"/(output.parent.name+"-"+output.name+".log");logpath.parent.mkdir(exist_ok=True)
        with logpath.open("w") as log:
            code,reason=support.run_owned(argv,str(root),call_environment,log,cancelled=cancelled,
              timeout=cfg["execution_timeout_seconds"],grace=cfg["cancellation_grace_seconds"],launched=launched)
        usage=resource.getrusage(resource.RUSAGE_CHILDREN)
        try:os.killpg(owner,0);closed=False
        except ProcessLookupError:closed=True
        result=read(output/"result.json")
        row={"request":str(request),"output":str(output),"argv":argv,"returncode":code,"stop_reason":reason,
             "owned_group":owner,"group_closed":closed,"wall_seconds":time.monotonic()-start,
             "child_cpu_seconds":usage.ru_utime+usage.ru_stime-old.ru_utime-old.ru_stime,
             "suite_cumulative_reaped_peak_rss_bytes":usage.ru_maxrss*1024,"sampled_aggregate_rss_bytes":peak,
             "rss_limit_exceeded":exceeded,"native_observation":native,"status":result["status"],"code":result["code"],
             "execution_helper_sha256":sha(source)}
        calls.append(row);write(w/"calls.json",calls);print(json.dumps({"case":output.name,"status":result["status"],"code":result["code"],"closed":closed}),flush=True)
        assert closed and not exceeded and reason is None,row
        return result
    for operation in cfg.get("pre_calls",[]):
        if not Path(operation["output"]).joinpath("result.json").exists():
            assert public(operation["request"],Path(operation["output"]))["status"]=="PASS"
    for case in cases:
        if (w/"results"/case["name"]/"result.json").exists():
            result=read(w/"results"/case["name"]/"result.json");assert result["status"]==case["expected_status"],result
            continue
        bind=w/"bindings"/(case["name"]+".json")
        write(bind,{"schema":"canon-neu/script-input/v1","task_id":"T-026:bind:"+case["name"],"step":"PREPARE_REQUEST",
                    "payload":{"template":{"path":case["template"]}}})
        prepared=w/"prepared"/case["name"];assert public(bind,prepared)["status"]=="PASS"
        result=public(prepared/"request.json",w/"results"/case["name"],case.get("extra_components",()),case.get("environment",{}))
        assert result["status"]==case["expected_status"],(case,result)
        if case["expected_status"]=="ERROR":assert result["code"]==case["expected_code"],(case,result)
    if cfg.get("verify_tag"):
        runtime=read(cfg["normal_runtime"]);tag=cfg["verify_tag"];verify=w/("verify-"+tag+".json")
        payload={"fixture_directory":cfg["fixture_directory"],"result_directory":str(w/"results"),"cases":cases,
          "declared_native_library":runtime["finiteflow_library"]["path"],"declared_native_hash":runtime["finiteflow_library"]["sha256"],
          "declared_flint_executable":runtime["flint_executable"]["path"],"declared_flint_executable_hash":runtime["flint_executable"]["sha256"],"declared_flint_version":"3.4.0",
          "declared_fermat_entry":runtime["fermatica_entry"]["path"],"declared_fermat_entry_hash":runtime["fermatica_entry"]["sha256"],
          "declared_fermat_executable":runtime["fermat_executable"]["path"],"declared_fermat_executable_hash":runtime["fermat_executable"]["sha256"],
          "method_options":{"runtime_config":{"path":cfg["normal_runtime"],"sha256":sha(cfg["normal_runtime"])}}}
        write(verify,{"schema":"canon-neu/script-input/v1","task_id":"T-026:verify:"+tag,"step":"VERIFY_RADICAND_FIXTURES","payload":payload})
        result=public(verify,w/("verified-"+tag));assert result["status"]=="PASS",result
    after={p:sha(p) for p in cfg["guarded_sources"]};write(w/"source-guard-after.json",{"hashes":after,"unchanged":before==after})
    report={"all_pass":bool(cases) and bool(cfg.get("verify_tag")) and read(w/("verified-"+cfg["verify_tag"])/"checks.json")["all_pass"] is True and read(w/("verified-"+cfg["verify_tag"])/"checks.json")["check_count"]>0,"exact_policy_checks":read(w/("verified-"+cfg["verify_tag"])/"checks.json")["check_count"] if cfg.get("verify_tag") else 0,"cases":len(cases),"public_calls":len(calls),
         "all_groups_closed":all(x["group_closed"] for x in calls),"maximum_sampled_rss_bytes":max(x["sampled_aggregate_rss_bytes"] for x in calls),
         "all_observed_native_cpu21":all(x["native_observation"] is None or x["native_observation"]["affinity"]==str(cfg["cpu"]) for x in calls),
         "source_unchanged":before==after,"wall_seconds":sum(x["wall_seconds"] for x in calls),"child_cpu_seconds":sum(x["child_cpu_seconds"] for x in calls),
         "rss_scope":"sampled per-call aggregate; reaped maxRSS in calls is suite-cumulative","scope":"Tiny capability/phase-policy tests only; no physical or scientific acceptance claim"}
    write(w/"report.json",report);print(json.dumps(report),flush=True);assert report["source_unchanged"] and report["all_observed_native_cpu21"]
if __name__=="__main__":main()
