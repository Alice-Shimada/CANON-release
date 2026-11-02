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
        write(bind,{"schema":"canon-neu/script-input/v1","task_id":"T-024:bind:"+case["name"],"step":"PREPARE_REQUEST",
                    "payload":{"template":{"path":case["template"]}}})
        prepared=w/"prepared"/case["name"];assert public(bind,prepared)["status"]=="PASS"
        result=public(prepared/"request.json",w/"results"/case["name"],case.get("extra_components",()),case.get("environment",{}))
        assert result["status"]==case["expected_status"],(case,result)
        if case["expected_status"]=="ERROR":assert result["code"]==case["expected_code"],(case,result)
    if cfg.get("cancel_test") and not (w/"cancellation-checks.json").exists():
        bind=w/"cancel-v3-bind.json"
        write(bind,{"schema":"canon-neu/script-input/v1","task_id":"T-024:cancel-bind","step":"PREPARE_REQUEST","payload":{"template":{"path":str(w/"templates/cancel.json")}}})
        assert public(bind,w/"cancel-v3-prepared")["status"]=="PASS"
        native_receipt=w/"cancel-v3-native.json";env=dict(cfg["environment"]);env["CANON_TEST_NATIVE_RECEIPT"]=str(native_receipt);env["CANON_TEST_FLINT_FAULT"]="cancel"
        request=w/"cancel-v3-submit.json"
        write(request,{"schema":"canon-neu/script-input/v1","task_id":"T-024:cancel-submit","step":"SUBMIT_JOB",
         "payload":{"request":{"path":str(w/"cancel-v3-prepared/request.json")},"run_id":"T022-native-cancel-v3",
         "components":cfg["complete_components"],"environment":env,"cancel_grace_seconds":cfg["cancellation_grace_seconds"]}})
        started=time.monotonic();result=public(request,w/"cancel-v3-submitted");assert result["code"]=="JOB_SUBMITTED"
        handle=(w/"cancel-v3-submitted"/result["artifacts"]["job"]["path"]).resolve();job=read(handle);native=None;observation=None;peak=0
        deadline=started+cfg["execution_timeout_seconds"]
        owner_record=None
        while time.monotonic()<deadline and not (handle.parent/"terminal.json").exists():
            if (handle.parent/"owner.json").exists():
                owner_record=read(handle.parent/"owner.json")
                pending=[owner_record["child_pid"]]
                while pending:
                    pid=pending.pop();p=Path("/proc")/str(pid)
                    try:
                        status=read_proc_status(pid)
                        pending += [int(x) for x in (p/"task"/str(pid)/"children").read_text().split()]
                        if (p/"exe").resolve()==Path(cfg["cancel_native_executable"]).resolve() and not status["State"].startswith("Z"):
                            native={"pid":pid};observation={"pid":pid,"group":os.getpgid(pid),"affinity":status["Cpus_allowed_list"],
                             "rss_bytes":int(status.get("VmRSS","0 kB").split()[0])*1024,"state":status["State"]};break
                    except (OSError,ValueError,KeyError):pass
            if native and native_receipt.exists():break
            time.sleep(.2)
        owner_record=read(handle.parent/"owner.json");owned_group=owner_record["process_group"]
        cancel=w/"cancel-v3-action.json";write(cancel,{"schema":"canon-neu/script-input/v1","task_id":"T-024:cancel-action","step":"CANCEL_JOB","payload":{"job":{"path":str(handle)}}})
        action=public(cancel,w/"cancel-v3-requested")
        collect=w/"cancel-v3-collect.json";write(collect,{"schema":"canon-neu/script-input/v1","task_id":"T-024:cancel-collect","step":"COLLECT_JOB","payload":{"job":{"path":str(handle)}}})
        end=time.monotonic()+cfg["cancellation_grace_seconds"]+cfg["collection_reserve_seconds"];n=0;terminal=None
        while time.monotonic()<end:
            n+=1;collected=public(collect,w/("cancel-v3-collected-"+str(n)))
            if (handle.parent/"terminal.json").exists():terminal=read(handle.parent/"terminal.json");break
            time.sleep(.5)
        try:os.killpg(owned_group,0);closed=False
        except ProcessLookupError:closed=True
        native_closed=bool(native) and not (Path("/proc")/str(native["pid"])).exists()
        checks={"terminal_cancelled":bool(terminal) and terminal["terminal"] and terminal["status"]=="cancelled",
          "owned_group_closed":closed,"actual_native_observed":bool(native),"native_same_owned_group":bool(observation) and observation["group"]==owned_group,
          "native_cpu21":bool(observation) and observation["affinity"]==str(cfg["cpu"]),"native_process_closed":native_closed,
          "no_mathematical_output":not (handle.parent/"science/full-sector-de.wl").exists(),"bounded":time.monotonic()-started<cfg["execution_timeout_seconds"]+cfg["cancellation_grace_seconds"]+cfg["collection_reserve_seconds"]}
        write(w/"cancellation-checks.json",{"all_pass":all(checks.values()),"checks":checks,"native_observation":observation,"owner":owner_record,"terminal":terminal,
          "wall_seconds":time.monotonic()-started,"resource_scope":"Cancelled job has no wait4 final usage; observed native RSS is a sample, not final peak or complete CPU."})
        assert all(checks.values()),checks
    if cfg.get("verify_tag"):
        runtime=read(cfg["normal_runtime"]);tag=cfg["verify_tag"];verify=w/("verify-"+tag+".json")
        payload={"fixture_directory":cfg["fixture_directory"],"result_directory":str(w/"results"),"cases":cases,
          "declared_native_library":runtime["finiteflow_library"]["path"],"declared_native_hash":runtime["finiteflow_library"]["sha256"],
          "declared_flint_executable":runtime["flint_executable"]["path"],"declared_flint_executable_hash":runtime["flint_executable"]["sha256"],"declared_flint_version":"3.4.0",
          "declared_fermat_entry":runtime["fermatica_entry"]["path"],"declared_fermat_entry_hash":runtime["fermatica_entry"]["sha256"],
          "declared_fermat_executable":runtime["fermat_executable"]["path"],"declared_fermat_executable_hash":runtime["fermat_executable"]["sha256"],
          "method_options":{"runtime_config":{"path":cfg["normal_runtime"],"sha256":sha(cfg["normal_runtime"])}}}
        write(verify,{"schema":"canon-neu/script-input/v1","task_id":"T-024:verify:"+tag,"step":"VERIFY_FLINT_FIXTURES","payload":payload})
        result=public(verify,w/("verified-"+tag));assert result["status"]=="PASS",result
    after={p:sha(p) for p in cfg["guarded_sources"]};write(w/"source-guard-after.json",{"hashes":after,"unchanged":before==after})
    report={"all_pass":True,"exact_policy_checks":read(w/("verified-"+cfg["verify_tag"])/"checks.json")["check_count"] if cfg.get("verify_tag") else 0,"cases":len(cases),"public_calls":len(calls),
         "all_groups_closed":all(x["group_closed"] for x in calls),"maximum_sampled_rss_bytes":max(x["sampled_aggregate_rss_bytes"] for x in calls),
         "all_observed_native_cpu21":all(x["native_observation"] is None or x["native_observation"]["affinity"]==str(cfg["cpu"]) for x in calls),
         "source_unchanged":before==after,"wall_seconds":sum(x["wall_seconds"] for x in calls),"child_cpu_seconds":sum(x["child_cpu_seconds"] for x in calls),
         "rss_scope":"sampled per-call aggregate; reaped maxRSS in calls is suite-cumulative","scope":"Tiny capability/phase-policy tests only; no physical or scientific acceptance claim"}
    write(w/"report.json",report);print(json.dumps(report),flush=True);assert report["source_unchanged"] and report["all_observed_native_cpu21"]
if __name__=="__main__":main()
