#!/usr/bin/env python3
"""Focused native-format adapter fixtures or one explicitly requested Kira smoke."""

import argparse
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import time


FAKE = r'''
from pathlib import Path
import json, os, signal, subprocess, sys, time
mode, job = sys.argv[1:]
if os.environ.get("KIRA_TEST_CALL_MARKER"):
    with Path(os.environ["KIRA_TEST_CALL_MARKER"]).open("a") as marker: marker.write("native call\\n")
family = Path("config/integralfamilies.yaml").read_text()
kinematics = Path("config/kinematics.yaml").read_text()
assert 'name: "native_family"' in family and '["l-p", "0"]' in family
if mode == "numeric-point":
    assert 'kinematic_invariants: []' in kinematics and '[["p", "p"], "7"]' in kinematics
else:
    assert '[["s", 2]]' in kinematics and '[["p", "p"], "s"]' in kinematics
Path("invoked-"+Path(job).name).write_text(mode)
if mode == "nonzero": sys.exit(7)
if mode == "missing": sys.exit(0)
out = Path("results/native_family"); out.mkdir(parents=True,exist_ok=True)
masters = "native_family[1,0] # sector 1\nnative_family[1,1] # sector 3\n"
if mode == "different-basis": masters = "native_family[0,1]\nnative_family[1,1]\n"
(out/"masters").write_text(masters)
(out/"masters.final").write_text(masters)
rule = "{native_family[2,1] -> 2 native_family[1,1] + s native_family[1,0]}"
if mode == "numeric-point": rule = "{native_family[2,1] -> 2 native_family[1,1] + 7 native_family[1,0]}"
if mode == "unreduced": rule = "{native_family[2,1] -> native_family[3,1]}"
if mode == "nonlinear": rule = "{native_family[2,1] -> native_family[1,1]^2}"
(out/"kira_targets.m").write_text(rule)
if mode == "custom-jobs":
    assert Path("aux data/selected").read_text() == "declared caller resource\n"
if mode in ("cancel-zero","timeout"):
    child = subprocess.Popen([sys.executable,"-c","import signal,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); time.sleep(30)"])
    Path("descendant.pid").write_text(str(child.pid))
    signal.signal(signal.SIGTERM,lambda *_: sys.exit(0))
    Path("cancel-ready").write_text("ready")
    time.sleep(30)
'''


CHECKS = r'''
$HistoryLength = 0;
{mode, tree, receipt} = Rest[$ScriptCommandLine];
If[mode === "fixtures",
  red = Get[FileNameJoin[{tree, "outputs", "reduce", "ibp-reduction.wl"}]];
  dis = Get[FileNameJoin[{tree, "outputs", "discover", "master-basis.wl"}]];
  sec = Get[FileNameJoin[{tree, "outputs", "discover", "sector-manifest.wl"}]];
  facts = <|"requested_source_order" -> (red["masters"] === {B[1,1],B[1,0]}),
    "native_rule_conversion" -> (red["rules"] === {B[2,1] -> s B[1,0]+2 B[1,1]}),
    "discovery_canonical_head" -> (dis["topology"] === "B" && AllTrue[dis["masters"], SymbolName[Head[#]] === "B" &]),
    "standard_sector_order" -> (Lookup[sec["sectors"], "id"] === {1,3}),
    "native_underscore_not_pattern" -> (List @@@ dis["masters"] === {{1,0},{1,1}})|>,
  red = Get[FileNameJoin[{tree, "outputs", "native", "ibp-reduction.wl"}]];
  values = {B[2,1],B[1,2]} /. red["rules"];
  facts = <|"native_bubble_source" -> (red["masters"] === {B[1,1]}),
    "two_native_targets" -> (Length[red["rules"]] === 2),
    "analytic_bubble_recurrence" -> AllTrue[values, Together[# - (3-d)/s B[1,1]] === 0 &]|>
];
Export[receipt,facts,"RawJSON"];
Exit[If[AllTrue[Values[facts],TrueQ],0,1]];
'''


def write(path, value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,indent=2)+"\n")


def read(path):
    return json.loads(path.read_text())


def wait_for(predicate, timeout=15):
    deadline = time.monotonic()+timeout
    while time.monotonic()<deadline:
        if predicate():
            return
        time.sleep(0.02)
    raise AssertionError("bounded fixture did not reach checkpoint")


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--canon",required=True,type=Path)
    parser.add_argument("--work",required=True,type=Path)
    parser.add_argument("--components",type=Path,action="append",default=[])
    parser.add_argument("--native-kira",help="run only one real native bubble smoke instead of fixture cases")
    args=parser.parse_args()
    canon,work=args.canon.resolve(),args.work.resolve()
    work.mkdir(parents=True,exist_ok=False)
    tree=work/"initial tree with spaces"
    package=tree/"package"
    shutil.copytree(Path(__file__).resolve().parents[1],package,ignore=shutil.ignore_patterns("__pycache__","tests"))
    backend_dir=tree/"backend files"
    backend_dir.mkdir()
    fake=backend_dir/"native fixture.py"
    fake.write_text(FAKE)
    family={"schema":"canon-neu/reducer-family/v1","family_ref":"fixture-family","basis_ref":"fixture-source",
            "topology":"bubble" if args.native_kira else "native_family","integral_head":"B",
            "index_order":["D1","D2"],"propagator_slots":[1,2],"top_level_sectors":[3],
            "loop_momenta":["l"],"external_momenta":["p"],
            "propagators":[{"momentum":"l","mass_squared":"0"},{"momentum":"l-p","mass_squared":"0"}],
            "scalar_products":[{"momenta":["p","p"],"value":"s"}],"invariants":[{"name":"s","mass_dimension":2}],
            "point":[],"dimension":"d","variables":["s"],"regulator":"eps","dimension_rule":"d->4-2*eps",
            "family_data":{"path":"family-data.wl"}}
    write(tree/"family.json",family)
    (tree/"family-data.wl").write_text('<|"schema"->"canon-neu/parameterized-family/v1","family_ref"->"fixture-family","dimension"->d,"variables"->{s},"regulator"->eps|>\n')
    masters="{B[1,1]}" if args.native_kira else "{B[1,1],B[1,0]}"
    targets="{B[2,1],B[1,2]}" if args.native_kira else "{B[2,1]}"
    (tree/"targets.wl").write_text('<|"schema"->"canon-neu/reduction-targets/v1","family_ref"->"fixture-family","basis_ref"->"fixture-source","targets"->'+targets+',"masters"->'+masters+',"point"->{}|>\n')
    (tree/"basis.wl").write_text('<|"schema"->"canon-neu/master-basis/v1","family_ref"->"fixture-family","basis_ref"->"fixture-source","masters"->'+masters+'|>\n')
    environment=dict(os.environ,PYTHONDONTWRITEBYTECODE="1")
    runtime=environment.get("CANON_WOLFRAMSCRIPT") or shutil.which("wolframscript")
    if not runtime:
        raise RuntimeError("configure CANON_WOLFRAMSCRIPT or wolframscript on PATH")
    records=[]

    def prepare(name,step,mode="normal",changes=None,payload_changes=None):
        destination=tree/"outputs"/name
        config={"schema":"canon-neu/kira-backend/v1","executable":sys.executable,
                "options":[os.path.relpath(tree/"backend files/native fixture.py",destination/"kira"),mode],
                "seed":{"r":3,"s":0,"d":1},"timeout_seconds":5,"cancel_grace_seconds":0.1}
        config.update(changes or {})
        config_path=tree/"backend files"/(name+".json")
        write(config_path,config)
        payload={"reducer_family":{"path":"family.json"},"backend":{"path":os.path.relpath(config_path,tree)}}
        if step=="REDUCE_IBP":
            payload.update(reduction_targets={"path":"targets.wl"},master_basis={"path":"basis.wl"})
        payload.update(payload_changes or {})
        request=tree/(name+".json")
        write(request,{"schema":"canon-neu/script-input/v1","task_id":"KIRA-ADAPTER-"+name,"step":step,"sector":None,"payload":payload})
        command=[sys.executable,str(canon/"run_step.py"),str(request),str(destination)]
        for manifest in args.components or [canon/"components/profiles/custom-kira.json"]:
            command += ["--components",str(manifest.resolve())]
        command += ["--components",str(package/"components.json")]
        return command,destination

    def run(name,step,expected,mode="normal",changes=None,payload_changes=None):
        command,destination=prepare(name,step,mode,changes,payload_changes)
        process=subprocess.run(command,env=environment,cwd=tree,text=True,capture_output=True,timeout=130)
        value=read(destination/"result.json")
        assert (value["status"],value["code"])==expected,(name,value,process.stdout,process.stderr)
        assert (process.returncode==0)==(value["status"]=="PASS"),(name,process.returncode)
        (destination/"driver.log").write_text(process.stdout+process.stderr)
        records.append({"case":name,"status":value["status"],"code":value["code"],"returncode":process.returncode,
                        "native_kind":"installed-kira" if args.native_kira else "native-format-adapter-fixture"})
        print(name+": "+value["status"]+"/"+value["code"],flush=True)
        return value,destination

    if args.native_kira:
        executable=shutil.which(args.native_kira)
        if not executable:
            raise RuntimeError("declared native Kira executable is unavailable")
        version=subprocess.run([executable,"--version"],text=True,capture_output=True,timeout=10,check=True)
        native_version=(version.stdout+version.stderr).strip()
        value,destination=run("native","REDUCE_IBP",("PASS","IBP_REDUCED"),changes={"executable":executable,"options":["--parallel=1"],"timeout_seconds":90})
        native_run=read(destination/"backend-run.json")
        assert sum(item["elapsed_seconds"] for item in native_run["commands"])<90
    else:
        native_version=None
        manifest=read(package/"components.json")
        assert set(manifest["steps"])=={"DISCOVER","REDUCE_IBP"}
        run("discover","DISCOVER",("PASS","SECTORS_READY"))
        run("reduce","REDUCE_IBP",("PASS","IBP_REDUCED"))
        slow_launcher=tree/"backend files/slow-import-wolfram"
        slow_launcher.write_text("#!/usr/bin/env python3\nimport os,sys,time\nif sys.argv[4]=='import': time.sleep(0.2)\nruntime=os.environ['KIRA_TEST_REAL_WOLFRAM']\nos.execv(runtime,[runtime,*sys.argv[1:]])\n")
        slow_launcher.chmod(0o755)
        previous_runtime=environment.get("CANON_WOLFRAMSCRIPT")
        environment.update(CANON_WOLFRAMSCRIPT=str(slow_launcher),KIRA_TEST_REAL_WOLFRAM=runtime)
        marker=tree/"native-calls.txt"
        try:
            value,source=run("import-timeout","REDUCE_IBP",("ERROR","KIRA_IMPORT_TIMEOUT"),
                changes={"import_timeout_seconds":0.05,"environment":{"KIRA_TEST_CALL_MARKER":str(marker)}})
            source_result=(source/"result.json").read_bytes()
            calls=marker.read_bytes()
            recovery={"import_from":os.path.relpath(source,tree/"backend files"),
                      "import_timeout_seconds":30,"executable":"must-not-be-resolved-or-invoked",
                      "environment":{"KIRA_TEST_CALL_MARKER":str(marker)}}
            value,destination=run("import-recovery","REDUCE_IBP",("PASS","IBP_REDUCED"),changes=recovery)
            receipt=read(destination/"backend-run.json")
            assert receipt["commands"]==[] and receipt["native_execution_inherited"]
            assert receipt["source_result_code"]=="KIRA_IMPORT_TIMEOUT" and receipt["import_timeout_seconds"]==30
            assert marker.read_bytes()==calls and (source/"result.json").read_bytes()==source_result
            assert sorted(p.name for p in (destination/"kira").iterdir())==["preferred-masters","targets"]
            assert (destination/"ibp-reduction.wl").read_bytes()==(tree/"outputs/reduce/ibp-reduction.wl").read_bytes()
            assert not read(source/"backend-run.json")["reduction_complete"]
            (tree/"other-targets.wl").write_text((tree/"targets.wl").read_text().replace('B[2,1]','B[3,1]'))
            value,rejected=run("import-wrong-targets","REDUCE_IBP",("ERROR","KIRA_ADAPTER_ERROR"),changes=recovery,
                payload_changes={"reduction_targets":{"path":"other-targets.wl"}})
            assert "binding differs" in value["summary"]["reason"] and not (rejected/"import.log").exists()
            write(tree/"other-family.json",{**family,"family_ref":"other-family"})
            value,rejected=run("import-wrong-family","REDUCE_IBP",("ERROR","KIRA_ADAPTER_ERROR"),changes=recovery,
                payload_changes={"reducer_family":{"path":"other-family.json"}})
            assert not (rejected/"prepare.log").exists() and marker.read_bytes()==calls
            run("invalid-import-timeout","REDUCE_IBP",("ERROR","KIRA_ADAPTER_ERROR"),changes={"import_timeout_seconds":0})
            assert read(tree/"outputs/reduce/backend-run.json")["import_timeout_seconds"]==120
        finally:
            environment.pop("KIRA_TEST_REAL_WOLFRAM",None)
            if previous_runtime is None:
                environment.pop("CANON_WOLFRAMSCRIPT",None)
            else:
                environment["CANON_WOLFRAMSCRIPT"]=previous_runtime
        value,_=run("missing","REDUCE_IBP",("FAIL","IBP_CHECK_FAILED"),"missing")
        assert value["summary"]["reason_code"]=="NATIVE_OUTPUT_MISSING"
        run("nonzero","DISCOVER",("ERROR","KIRA_FAILED"),"nonzero")
        failed_launcher=tree/"backend files/failing-wolfram"
        failed_launcher.write_text("#!/usr/bin/env python3\nimport os,subprocess,sys\ncode=subprocess.call([os.environ['KIRA_TEST_REAL_WOLFRAM'],*sys.argv[1:]])\nsys.exit(7 if code==0 else code)\n")
        failed_launcher.chmod(0o755)
        previous_runtime=environment.get("CANON_WOLFRAMSCRIPT")
        environment.update(CANON_WOLFRAMSCRIPT=str(failed_launcher),KIRA_TEST_REAL_WOLFRAM=runtime)
        try:
            value,destination=run("import-exit-failure","DISCOVER",("ERROR","NATIVE_IMPORT_FAILED"))
            assert not read(destination/"backend-run.json")["master_discovery_complete"]
        finally:
            environment.pop("KIRA_TEST_REAL_WOLFRAM",None)
            if previous_runtime is None:
                environment.pop("CANON_WOLFRAMSCRIPT",None)
            else:
                environment["CANON_WOLFRAMSCRIPT"]=previous_runtime
        for name,reason in (("different-basis","NATIVE_BASIS_MISMATCH"),
                            ("unreduced","UNREDUCED_NATIVE_OUTPUT"),("nonlinear","NATIVE_RULES_NOT_LINEAR")):
            value,_=run(name,"REDUCE_IBP",("FAIL","IBP_CHECK_FAILED"),name)
            assert value["summary"]["reason_code"]==reason
        numeric={**family,"invariants":[],"point":[{"variable":"s","value":"7"}],
                 "scalar_products":[{"momenta":["p","p"],"value":"7"}]}
        write(tree/"numeric-family.json",numeric)
        (tree/"numeric-targets.wl").write_text((tree/"targets.wl").read_text().replace('"point"->{}','"point"->{s->7}'))
        run("numeric-point","REDUCE_IBP",("PASS","IBP_REDUCED"),"numeric-point",payload_changes={
            "reducer_family":{"path":"numeric-family.json"},"reduction_targets":{"path":"numeric-targets.wl"}})
        bad=(tree/"targets.wl").read_text().replace('"point"->{}','"point"->{s->2}')
        (tree/"wrong-point.wl").write_text(bad)
        value,destination=run("wrong-point","REDUCE_IBP",("ERROR","REDUCTION_POINT_MISMATCH"),payload_changes={"reduction_targets":{"path":"wrong-point.wl"}})
        assert read(destination/"backend-run.json")["commands"]==[]
        bad=(tree/"targets.wl").read_text().replace('B[2,1]','WrongHead[2,1]')
        (tree/"wrong-head.wl").write_text(bad)
        run("wrong-head","REDUCE_IBP",("ERROR","INTEGRAL_ENCODING_MISMATCH"),payload_changes={"reduction_targets":{"path":"wrong-head.wl"}})
        jobs=tree/"backend files/jobs with spaces"
        jobs.mkdir()
        for name in ("first.yaml","second.yaml"):
            (jobs/name).write_text("jobs: []\n")
        (tree/"backend files/resource").write_text("declared caller resource\n")
        run("custom-jobs","REDUCE_IBP",("PASS","IBP_REDUCED"),"custom-jobs",changes={
            "jobs":["jobs with spaces/first.yaml","jobs with spaces/second.yaml"],
            "files":[{"path":"resource","destination":"aux data/selected"}]})
        command,destination=prepare("cancel-zero","REDUCE_IBP","cancel-zero")
        process=subprocess.Popen(command,env=environment,cwd=tree,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,start_new_session=True)
        try:
            wait_for(lambda:(destination/"kira/cancel-ready").exists())
            time.sleep(0.06)
            process.send_signal(signal.SIGTERM)
            output,_=process.communicate(timeout=10)
            (destination/"driver.log").write_text(output)
            value=read(destination/"result.json")
            assert value["code"]=="KIRA_INTERRUPTED" and value["status"]=="ERROR",value
            native_run=read(destination/"backend-run.json")
            assert native_run["commands"][0]["returncode"]==0,native_run
            assert not native_run["reduction_complete"]
            pid=int((destination/"kira/descendant.pid").read_text())
            state=subprocess.run(["ps","-o","stat=","-p",str(pid)],text=True,capture_output=True).stdout.strip()
            assert not state or state.startswith("Z"),state
            records.append({"case":"cancel-zero","status":value["status"],"code":value["code"],"child_zero_exit":True,"descendant_stopped":True,"native_kind":"native-format-adapter-fixture"})
            print("cancel-zero: ERROR/KIRA_INTERRUPTED despite native zero exit",flush=True)
        finally:
            if process.poll() is None:
                process.send_signal(signal.SIGTERM)
                process.wait(timeout=10)
        run("timeout","REDUCE_IBP",("ERROR","KIRA_TIMEOUT"),"timeout",changes={"timeout_seconds":0.2})
        old_tree=tree
        tree=work/"relocated tree with spaces"
        old_tree.rename(tree)
        package=tree/"package"
        assert not old_tree.exists()
        run("relocated","REDUCE_IBP",("PASS","IBP_REDUCED"))
    checks=work/"Checks.wls"
    checks.write_text(CHECKS)
    facts_file=work/"facts.json"
    completed=subprocess.run([runtime,"-file",str(checks),"native" if args.native_kira else "fixtures",str(tree),str(facts_file)],
                             text=True,capture_output=True,timeout=30,env=environment)
    (work/"checks.log").write_text(completed.stdout+completed.stderr)
    facts=read(facts_file)
    assert completed.returncode==0 and all(facts.values()),facts
    receipt={"all_expected":True,"native_execution":bool(args.native_kira),"native_version":native_version,
             "adapter_fixture_only":not bool(args.native_kira),"cases":records,"artifact_facts":facts,
             "kernel_concurrency":1,"reducer_concurrency":1,"physical_campaign":False,
             "scope":"one symbolic native bubble" if args.native_kira else "native-format fixtures, not native Kira execution"}
    write(work/"evidence.json",receipt)
    print(json.dumps(receipt,indent=2),flush=True)


if __name__=="__main__":
    main()
