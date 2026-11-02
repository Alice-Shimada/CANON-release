#!/usr/bin/env python3
"""Focused public-runner batch/single-sector equality and rejection fixtures."""
import argparse,hashlib,json,os,subprocess,time
from pathlib import Path

def read(p):return json.loads(Path(p).read_text())
def save(p,v):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(v,indent=2)+"\n")
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    parser=argparse.ArgumentParser();parser.add_argument("--config",required=True);parser.add_argument("--work",required=True)
    a=parser.parse_args();cfg=read(a.config);root=Path(cfg["project_root"]);work=Path(a.work).resolve()
    if work.exists():raise RuntimeError("Fixture workspace must be fresh.")
    work.mkdir(parents=True);os.sched_setaffinity(0,{cfg["cpu"]})
    env={**os.environ,**cfg["environment"],"CANON_BATCH_TEST_CONFIG":str(Path(a.config).resolve()),
         "CANON_WOLFRAMSCRIPT":cfg["wolframscript"]}
    components=cfg["complete_components"];calls=[];checks={}
    def envelope(step,payload,sector=None):
        v={"schema":"canon-neu/script-input/v1","task_id":"BATCH-FIXTURE-"+step,"step":step,"payload":payload}
        if sector is not None:v["sector"]=sector
        return v
    def public(name,request,output):
        p=work/(name+".json");save(p,request);command=["python3",str(root/"run_step.py"),str(p),str(output)]
        for component in components:command.extend(["--components",component])
        start=time.monotonic()
        with (work/(name+".log")).open("wb") as log:proc=subprocess.run(command,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=cfg["collection_seconds"])
        return read(output/"result.json"),proc.returncode,time.monotonic()-start
    def run(name,step,payload,sector=None,expected=("PASS",None),extra_component=None):
        directory=work/name;directory.mkdir();request=directory/"request.json";save(request,envelope(step,payload,sector))
        launch,code,_=public(name+"-submit",envelope("SUBMIT_JOB",{"request":{"path":str(request)},"run_id":"batch-fixtures",
                       "components":components+([str(extra_component)] if extra_component else []),"environment":{k:env[k] for k in [*cfg["environment"],"CANON_BATCH_TEST_CONFIG","CANON_WOLFRAMSCRIPT"]},
                       "cancel_grace_seconds":cfg["cleanup_seconds"]}),directory/"submitted")
        if code or launch["code"]!="JOB_SUBMITTED":raise RuntimeError(launch)
        handle=(directory/"submitted"/launch["artifacts"]["job"]["path"]).resolve();job=read(handle);start=time.monotonic();peak=0;cancelled=False
        while not (handle.parent/"terminal.json").exists():
            owner=handle.parent/"owner.json"
            if owner.exists():
                pid=read(owner)["child_pid"]
                try:
                    fields=dict(line.split(":",1) for line in Path(f"/proc/{pid}/status").read_text().splitlines() if ":" in line)
                    peak=max(peak,int(fields.get("VmRSS","0 kB").split()[0])*1024)
                except (FileNotFoundError,ProcessLookupError):pass
            if (time.monotonic()-start>cfg["fixture_timeout_seconds"] or peak>cfg["rss_bytes"]) and not cancelled:
                public(name+"-cancel",envelope("CANCEL_JOB",{"job":{"path":str(handle)},"reason":"tiny fixture allocation"}),directory/"cancelled");cancelled=True
            if cancelled and time.monotonic()-start>cfg["fixture_timeout_seconds"]+cfg["cleanup_seconds"]+cfg["collection_seconds"]:
                raise RuntimeError("Owned fixture did not close within declared cleanup/collection reserve.")
            time.sleep(.2)
        collected,_,_=public(name+"-collect",envelope("COLLECT_JOB",{"job":{"path":str(handle)}}),directory/"collected")
        terminal=read(handle.parent/"terminal.json");result_path=handle.parent/"science/result.json"
        result=read(result_path) if result_path.exists() else None
        calls.append({"name":name,"step":step,"job_id":job["job_id"],"job":str(handle),"terminal":str(handle.parent/"terminal.json"),
                      "scientific_result":str(result_path),"elapsed_seconds":time.monotonic()-start,"sampled_peak_kernel_rss_bytes":peak,
                      "terminal_status":terminal["status"],"returncode":terminal["returncode"],"result":result})
        save(work/"calls.json",calls)
        if cancelled or not result or (result["status"],result["code"])!=(expected[0],expected[1] or result["code"]):
            raise RuntimeError(f"Unexpected fixture result {name}: {result}")
        return result_path,result
    sources=work/"sources";sources.mkdir()
    multi='''<|"schema"->"canon-neu/ordered-master-de/v1","family_id"->"batch-fixture","basis_id"->"frozen-noncontiguous",
 "coefficient_domain"->"exact-rational-functions","basis"->{f[0,0],f[2,0],f[1,1],f[1,0],f[0,1]},
 "variables"->{x,y},"regulator"->eps,
 "matrices"->{(eps/x) {{1,0,0,0,0},{2,3,0,4,0},{7,8,9,10,11},{12,5,0,6,0},{13,0,0,0,14}},
 (eps/(y+1)) {{1,0,0,0,0},{2,3,0,4,0},{7,8,9,10,11},{12,5,0,6,0},{13,0,0,0,14}}}|>'''
    manifest='''<|"schema"->"canon-neu/sector-manifest/v1","family_ref"->"batch-fixture","propagator_slots"->{1,2},
 "sectors"->{<|"id"->3,"propagator_count"->2,"sector_bits"->{1,1}|>,<|"id"->2,"propagator_count"->1,"sector_bits"->{0,1}|>,
 <|"id"->0,"propagator_count"->0,"sector_bits"->{0,0}|>,<|"id"->1,"propagator_count"->1,"sector_bits"->{1,0}|>}|>'''
    def source(name,text):
        p=sources/(name+".wl");p.write_text(text+"\n");return {"type":"mathematica-expression","path":str(p),"sha256":sha(p)}
    ordered=source("ordered",multi);sectors=source("manifest",manifest);payload={"ordered_master_de":ordered,"sector_manifest":sectors}
    batch_path,batch=run("multi-batch","SLICE_CUT_DE_BATCH",payload,expected=("PASS","BATCH_SLICED"))
    batch_dir=batch_path.parent;index=read(batch_dir/"sector-index.json")
    checks["canonical_sector_order"]=[r["sector"]["id"] for r in index["sectors"]]==[0,1,2,3]
    checks["resident_positions"]=[r["resident_positions"] for r in index["sectors"]]==[[1],[2,4],[5],[3]]
    checks["source_hash_binding"]=index["sources"]["ordered_master_de"]["sha256"]==ordered["sha256"] and index["sources"]["sector_manifest"]["sha256"]==sectors["sha256"]
    timing=read(batch_dir/"batch-timing.json")
    checks["same_clock_operational_timing"]=timing["clock"]=="same-kernel SessionTime[] differences" and all(timing[k]>=0 for k in ["ordered_de_load_seconds","ordered_de_validation_seconds","all_sector_slice_and_write_seconds"])
    for row in index["sectors"]:
        sid=row["sector"]["id"];single_path,single=run("single-"+str(sid),"SLICE_CUT_DE",payload,sector=row["sector"],expected=("PASS","OK"))
        for key in ["sector_basis","sector_cut_de"]:
            bp=batch_dir/row[key]["path"];sp=single_path.parent/single["artifacts"][key]["path"]
            checks[f"sector_{sid}_{key}_bytes"]=bp.read_bytes()==sp.read_bytes()
            checks[f"sector_{sid}_{key}_hash"]=sha(bp)==row[key]["sha256"]
    edge_ordered=source("edge-ordered",multi.replace('"batch-fixture"','"single-sector-fixture"').replace('{f[0,0],f[2,0],f[1,1],f[1,0],f[0,1]}','{f[1,0],f[2,0]}').replace('{{1,0,0,0,0},{2,3,0,4,0},{7,8,9,10,11},{12,5,0,6,0},{13,0,0,0,14}}','{{3,4},{5,6}}'))
    edge_manifest=source("edge-manifest",'<|"schema"->"canon-neu/sector-manifest/v1","family_ref"->"single-sector-fixture","propagator_slots"->{1,2},"sectors"->{<|"id"->1,"propagator_count"->1,"sector_bits"->{1,0}|>}|>')
    edge_payload={"ordered_master_de":edge_ordered,"sector_manifest":edge_manifest}
    edge_path,edge=run("edge-batch","SLICE_CUT_DE_BATCH",edge_payload,expected=("PASS","BATCH_SLICED"))
    edge_single_path,edge_single=run("edge-single","SLICE_CUT_DE",edge_payload,sector={"id":1,"propagator_count":1},expected=("PASS","OK"))
    for key in ["sector_basis","sector_cut_de"]:
        checks["edge_"+key]=(edge_path.parent/edge["artifacts"][key+"_1"]["path"]).read_bytes()==(edge_single_path.parent/edge_single["artifacts"][key]["path"]).read_bytes()
    bad_de=source("bad-de",multi.replace('(eps/x)','(1.0/x)',1))
    bad_manifest=source("bad-manifest",manifest.replace('"batch-fixture"','"wrong-family"'))
    duplicate=source("duplicate-manifest",manifest.replace('"id"->2','"id"->1'))
    uncovered=source("uncovered-manifest",'<|"schema"->"canon-neu/sector-manifest/v1","family_ref"->"batch-fixture","propagator_slots"->{1,2},"sectors"->{<|"id"->1,"propagator_count"->1,"sector_bits"->{1,0}|>}|>')
    for name,changed,code in [
        ("bad-de",{"ordered_master_de":bad_de},"INVALID_DIFFERENTIAL_EQUATION"),
        ("bad-manifest",{"sector_manifest":bad_manifest},"INVALID_DIFFERENTIAL_EQUATION"),
        ("duplicate-manifest",{"sector_manifest":duplicate},"INVALID_DIFFERENTIAL_EQUATION"),
        ("uncovered-manifest",{"sector_manifest":uncovered},"INVALID_DIFFERENTIAL_EQUATION"),
        ("ordered-hash",{"ordered_master_de":{**ordered,"sha256":"0"*64}},"SOURCE_HASH_MISMATCH"),
        ("manifest-hash",{"sector_manifest":{**sectors,"sha256":"0"*64}},"SOURCE_HASH_MISMATCH")]:
        _,r=run(name,"SLICE_CUT_DE_BATCH",{**payload,**changed},expected=("ERROR",code));checks[name]=r["artifacts"]=={}
    verifier_payload={"batch_index":{"path":str(batch_dir/"sector-index.json")}}
    _,verified=run("independent-readback","VERIFY_BATCH_FIXTURE",verifier_payload,expected=("PASS","EXPECTED_BLOCKS_MATCH"),extra_component=Path(__file__).resolve().parent/"verify-components.json")
    checks.update(verified["summary"]["checks"])
    result={"schema":"batch-sector-cuts/fixture-report/v1","passed":all(checks.values()),"checks":checks,"public_calls":len(calls),
            "components":components,"cpu":cfg["cpu"],"library_threads":1,"limits":{k:cfg[k] for k in ["rss_bytes","fixture_timeout_seconds","cleanup_seconds","collection_seconds"]},
            "scope":"Tiny component fixtures only; no physical37-master input or canonical/UT certification."}
    save(work/"fixture-report.json",result);print(json.dumps(result),flush=True)
    if not result["passed"]:raise RuntimeError("Fixture checks failed.")
if __name__=="__main__":main()
