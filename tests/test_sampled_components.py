#!/usr/bin/env python3
"""Bounded actual point-DE -> dlog reconstruction -> local-job integration.

Use --canon CHECKOUT --work FRESH_DIRECTORY. Wolfram comes from
--wolframscript, CANON_WOLFRAMSCRIPT, or PATH. One kernel runs at a time.
All fixture, copied-source and runtime writes stay below --work.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import time


PACKAGE_FILES = {
    "point-de": ["components.json", "Run.wls", "PointDE.wl", "README.md", "WORKFLOW.md",
                 *[f"examples/{name}.wl" for name in ("family", "masters", "candidates", "point", "reduction")]],
    "dlog-reconstruction": ["components.json", "run.wls", "Reconstruction.wl", "README.md", "WORKFLOW.md"],
    "local-jobs": ["components.json", "local_jobs.py", "support.py", "jobs.py", "watches.py",
                   "README.md", "WORKFLOW.md", "examples/fake_session_receiver.py"],
}


FIXTURE_HELPER = r'''
$HistoryLength = 0;
{canon, input, output} = Rest[$ScriptCommandLine];
Get[FileNameJoin[{canon, "mma", "lib", "MethodCardCore.wl"}]];
If[!DirectoryQ[output], CreateDirectory[output, CreateIntermediateDirectories -> True]];
raw = Import[input, "RawJSON"];
task = CanonMethodCard`ReadTask[input, raw["step"]];
load[key_] := CanonMethodCard`LoadArtifact[task, input, key];
set = load["sample_set"];
keys = {"family_id", "basis_id", "chart_id", "frame_id", "scope", "variables", "regulator", "convention"};
v = First[set["variables"]]; ep = set["regulator"];
If[task["step"] === "MAKE_SAMPLED_FIXTURE_LETTER",
  letters = Join[KeyTake[set, keys], <|"schema" -> "canon-neu/raw-letters/v1",
    "labels" -> {"supplied-scale-letter"}, "letters" -> {v}|>];
  CanonMethodCard`WriteWLArtifact[letters, output, "raw-letters.wl"];
  CanonMethodCard`WriteResult[task, output, "PROVISIONAL", "FIXTURE_RAW_LETTER_READY",
    <|"raw_letters" -> <|"type" -> "mathematica-expression", "path" -> "raw-letters.wl"|>|>,
    <|"scope" -> "Known letter for the supplied synthetic bubble; metadata read from the actual producer index."|>];
  Exit[0]
];
candidate = load["reconstruction"]; checked = load["reconstruction_check"];
setPath = CanonMethodCard`ResolveInputPath[input, task["payload", "sample_set", "path"]];
entries = Join[set["training"], set["validation"]];
paths = CanonMethodCard`ResolveInputPath[setPath, #["path"]] & /@ entries;
samples = Get /@ paths;
prepared = MapThread[Get[CanonMethodCard`ResolveInputPath[#1, #2["sources", "prepared_point", "path"]]] &, {paths, samples}];
projections = Get[FileNameJoin[{DirectoryName[#], "projection.wl"}]] & /@ paths;
points = (v /. #["point"]) & /@ samples;
facts = <|
  "actual_producer_schema" -> AllTrue[samples, #["schema"] === "canon-neu/de-sample/v1" &],
  "indexed_variable_retained" -> (v === Global`x[1]),
  "two_training_one_heldout" -> (Length[set["training"]] === 2 && Length[set["validation"]] === 1 && points === {2, 4, 3}),
  "frame_and_scope_preserved" -> AllTrue[samples, KeyTake[#, keys] === KeyTake[set, keys] &],
  "nonconstant_frame_derivatives_retained" -> And @@ MapThread[
    Together[#1["frame_derivatives"][[1, 1, 1]] + 1/#2^2] === 0 &, {prepared, points}],
  "candidate_is_x_times_master" -> And @@ MapThread[
    Together[#1["expressions"][[1]] - #2 #1["masters"][[1]]] === 0 &, {prepared, points}],
  "projection_is_identity" -> AllTrue[projections, #["projection"] === {{1}} &],
  "projection_derivative_is_zero" -> AllTrue[projections, Flatten[#["projection_derivatives"]] === {0} &],
  "sample_connections_minus_two_eps_over_x" -> And @@ MapThread[
    Together[#1["matrices"][[1, 1, 1]] + 2 ep/#2] === 0 &, {samples, points}],
  "residue_is_minus_two" -> (Normal[First[candidate["residue_matrices"]]] === {{-2}}),
  "reconstructed_connection" -> (Together[candidate["matrices"][[1, 1, 1]] + 2 ep/v] === 0),
  "logarithmic_form" -> (Together[candidate["Atilde"][[1, 1]] + 2 Log[v]] === 0),
  "fit_kept_validation_out" -> (candidate["evidence", "heldout_checked"] === False),
  "independent_checker_pass" -> (checked["status"] === "PASS" && checked["code"] === "RECONSTRUCTION_VALIDATED"),
  "independent_checker_roles" -> (Lookup[checked["checks"], "role"] === {"training", "training", "validation"}),
  "finite_sample_boundary_retained" -> (checked["global_gauge_checked"] === False && checked["alphabet_complete"] === False)
|>;
Export[FileNameJoin[{output, "fixture-facts.json"}], facts, "RawJSON"];
good = AllTrue[Values[facts], TrueQ];
CanonMethodCard`WriteResult[task, output, If[good, "PASS", "FAIL"],
  If[good, "SAMPLED_INTEGRATION_CHECKED", "SAMPLED_INTEGRATION_FAILED"],
  <|"fixture_facts" -> <|"type" -> "json", "path" -> "fixture-facts.json"|>|>,
  <|"facts" -> facts, "scope" -> "Synthetic supplied-rule integration only; no global physics claim."|>];
If[!good, Exit[1]];
'''


def read(path):
    return json.loads(Path(path).read_text())


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def wait_for(predicate, seconds=120):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        value = predicate()
        if value:
            return value
        time.sleep(0.05)
    raise AssertionError("bounded component integration timed out")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--canon", required=True, type=Path)
    parser.add_argument("--work", required=True, type=Path)
    parser.add_argument("--wolframscript", default=os.environ.get("CANON_WOLFRAMSCRIPT", "wolframscript"))
    args = parser.parse_args()
    canon, work = args.canon.resolve(), args.work.resolve()
    runtime = shutil.which(args.wolframscript)
    if runtime is None:
        raise RuntimeError("supply --wolframscript or a configured Wolfram executable")
    work.mkdir(parents=True, exist_ok=False)
    (work / "logs").mkdir()
    original = work / "original component tree with spaces"
    tree = original
    tree.mkdir()
    copied = {}
    for name, files in PACKAGE_FILES.items():
        for filename in files:
            source = canon / "components" / name / filename
            target = tree / "packages" / name / filename
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            copied[f"components/{name}/{filename}"] = sha(source)
    helper = tree / "fixture tools"
    helper.mkdir()
    (helper / "Fixture.wls").write_text(FIXTURE_HELPER)
    (helper / "README.md").write_text("Synthetic integration helper: derive the supplied scale-letter metadata from the producer index, then verify the known bubble, frame derivative and heldout checker scope. No candidate discovery or general physics claim.\n")
    write(tree / "selection/components.json", {"schema":"canon-neu/components/v1",
        "extends":[f"../packages/{name}/components.json" for name in PACKAGE_FILES],
        "steps":{step:{"command":["{wolframscript}","-file","{package}/../fixture tools/Fixture.wls","{canon}"],
                       "instructions":"../fixture tools/README.md"}
                 for step in ("MAKE_SAMPLED_FIXTURE_LETTER","CHECK_SAMPLED_INTEGRATION")}})
    fixtures = tree / "fixtures"
    fixtures.mkdir()
    for name in ("family", "masters", "candidates", "reduction"):
        text = (tree / "packages/point-de/examples" / (name + ".wl")).read_text()
        (fixtures / (name + ".wl")).write_text(re.sub(r"(?<![\w-])x(?![\w-])", "x[1]", text))
    point_template = (tree / "packages/point-de/examples/point.wl").read_text()
    point_template = re.sub(r"(?<![\w-])x(?![\w-])", "x[1]", point_template)
    for label, point in (("train-1",2),("train-2",4),("heldout",3)):
        (fixtures / (label + ".wl")).write_text(point_template.replace("x[1] -> 2", f"x[1] -> {point}"))
    environment = dict(os.environ, CANON_WOLFRAMSCRIPT=runtime, PYTHONDONTWRITEBYTECODE="1")
    records = []
    job_relative = watch_relative = None

    def request(name, step, payload):
        path = tree / (name + ".json")
        write(path, {"schema":"canon-neu/script-input/v1","task_id":"SAMPLED-INTEGRATION-"+name,
                     "step":step,"sector":None,"payload":payload})
        return path

    def descriptor(result_path, key):
        value = dict(read(result_path)["artifacts"][key])
        target = (result_path.parent / value["path"]).resolve()
        value["path"] = os.path.relpath(target, tree)
        return value

    def invoke(input_path, destination, expected):
        command = [sys.executable,str(canon / "run_step.py"),str(input_path),str(destination),
                   "--components",str(tree / "selection/components.json")]
        described = subprocess.run(command+["--describe"], env=environment, text=True, capture_output=True, check=True)
        description = json.loads(described.stdout)
        assert [Path(item["manifest"]).parent.name for item in description["workflows"]] == list(PACKAGE_FILES)
        index = len(records) + 1
        logfile = work / "logs" / f"{index:02d}-{description['step']}.log"
        with logfile.open("w") as log:
            process = subprocess.Popen(command, cwd=tree, env=environment, stdout=log, stderr=subprocess.STDOUT,
                                       start_new_session=True)
            try:
                returncode = process.wait(timeout=120)
            except BaseException:
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
                raise
        result = read(destination / "result.json")
        actual = result["status"],result["code"]
        assert returncode == 0 and actual == expected, (description["step"],actual,returncode,str(logfile))
        assert result["code"] != "ALL_PASS"
        records.append({"step":description["step"],"status":actual[0],"code":actual[1],
                        "selected_manifest":description["manifest"],"components":description["components"],
                        "result":os.path.relpath(destination / "result.json",tree),"log":os.path.relpath(logfile,work)})
        print(f"{description['step']}: {actual[0]}/{actual[1]}",flush=True)
        return result

    try:
        samples = []
        for label in ("train-1","train-2","heldout"):
            payload = {name:{"path":"fixtures/"+filename+".wl"} for name,filename in
                       (("family_data","family"),("master_basis","masters"),("candidates","candidates"),("point_spec",label))}
            prepared = tree / "outputs" / (label + "-prepared")
            invoke(request("prepare-"+label,"PREPARE_POINT",payload),prepared,("PASS","POINT_PREPARED"))
            build = request("build-"+label,"BUILD_POINT_DE",{
                "prepared_point":descriptor(prepared / "result.json","prepared_point"),
                "ibp_reduction":{"path":"fixtures/reduction.wl","symbolic":True}})
            if label != "heldout":
                output = tree / "outputs" / label
                invoke(build,output,("PASS","POINT_DE_BUILT"))
            else:
                output = tree / "outputs/heldout-submit"
                invoke(request("submit-heldout","SUBMIT_JOB",{
                    "request":{"path":os.path.relpath(build,tree)},"run_id":"synthetic-heldout-run",
                    "components":["selection/components.json"],"cancel_grace_seconds":1}),
                       output,("PROVISIONAL","JOB_SUBMITTED"))
                job_relative = descriptor(output / "result.json","job")["path"]
                job_path = tree / job_relative
                job = read(job_path)
                checkpoint = job_path.parent / job["checkpoint"]["path"]
                watch_output = tree / "outputs/watch"
                invoke(request("watch-heldout","WATCH_COMPLETION",{
                    "checkpoint":{"path":os.path.relpath(checkpoint,tree)},
                    "job_id":job["job_id"],"run_id":job["run_id"],"mode":"background","interval_seconds":0.05,
                    "target":{"host":"fake-local-host","session":"fake-integration-session",
                              "message":"Collect the saved heldout point result and continue the bounded integration."},
                    "callback":{"argv":[sys.executable,"packages/local-jobs/examples/fake_session_receiver.py","receiver.json"],
                                "cwd":".","timeout_seconds":5}}),watch_output,("PROVISIONAL","WATCH_STARTED"))
                watch_relative = descriptor(watch_output / "result.json","watch")["path"]
                watch_path = tree / watch_relative
                wait_for(lambda: checkpoint.exists())
                wait_for(lambda: watch_path.with_name("delivery.json").exists() and
                         read(watch_path.with_name("delivery.json"))["state"] == "acknowledged")
                wait_for(lambda: watch_path.with_name("monitor.json").exists() and
                         not read(watch_path.with_name("monitor.json"))["running"])
                collection = tree / "outputs/heldout-collection"
                collected = invoke(request("collect-heldout","COLLECT_JOB",{"job":{"path":job_relative}}),
                                   collection,("PROVISIONAL","JOB_FINISHED"))
                assert collected["summary"]["scientific_status"] == "PASS"
                assert collected["summary"]["scientific_code"] == "POINT_DE_BUILT"
                assert collected["summary"]["scientific_acceptance"] is False
                scientific = descriptor(collection / "result.json","scientific_result")
                output = (tree / scientific["path"]).parent
                assert (read(output / "result.json")["status"],read(output / "result.json")["code"]) == ("PASS","POINT_DE_BUILT")
                snapshot = read(job_path.with_name("invocation.json"))
                assert snapshot["components"] == [str(tree / "selection/components.json")]
                assert [Path(item["manifest"]).parent.name for item in snapshot["workflows"]] == list(PACKAGE_FILES)
            samples.append({"id":label,"path":descriptor(output / "result.json","de_sample")["path"]})

        sample_set_output = tree / "outputs/samples"
        invoke(request("collect-samples","COLLECT_DE_SAMPLES",{"training":samples[:2],"validation":samples[2:]}),
               sample_set_output,("PASS","DE_SAMPLES_COLLECTED"))
        sample_set = descriptor(sample_set_output / "result.json","de_sample_set")
        sample_hashes = {item["id"]:sha(tree / item["path"]) for item in samples}
        science_hash = sha(tree / scientific["path"])
        event_id = read((tree / watch_relative).with_name("event.json"))["event_id"]
        moved = work / "relocated component tree with spaces"
        tree.rename(moved)
        tree = moved
        assert not original.exists()
        assert {item["id"]:sha(tree / item["path"]) for item in samples} == sample_hashes

        letters_output = tree / "outputs/letters"
        invoke(request("make-letters","MAKE_SAMPLED_FIXTURE_LETTER",{"sample_set":sample_set}),
               letters_output,("PROVISIONAL","FIXTURE_RAW_LETTER_READY"))
        raw_letters = descriptor(letters_output / "result.json","raw_letters")
        fit_output = tree / "outputs/fit"
        fitted = invoke(request("fit","RECONSTRUCT_DLOG",{"sample_set":sample_set,"raw_letters":raw_letters,
                         "arithmetic":{"mode":"exact"}}),fit_output,("PROVISIONAL","DLOG_RECONSTRUCTED"))
        assert fitted["summary"]["heldout_checked"] is False
        reconstruction = descriptor(fit_output / "result.json","reconstruction")
        check_output = tree / "outputs/check"
        checked = invoke(request("check","CHECK_RECONSTRUCTION",{"sample_set":sample_set,"raw_letters":raw_letters,
                          "reconstruction":reconstruction}),check_output,("PASS","RECONSTRUCTION_VALIDATED"))
        assert checked["summary"]["training_samples"] == 2
        assert checked["summary"]["validation_samples"] == 1
        assert checked["summary"]["checked_matrix_entries"] == 3
        facts_output = tree / "outputs/fixture-check"
        invoke(request("fixture-check","CHECK_SAMPLED_INTEGRATION",{"sample_set":sample_set,
                       "reconstruction":reconstruction,
                       "reconstruction_check":descriptor(check_output / "result.json","reconstruction_check")}),
               facts_output,("PASS","SAMPLED_INTEGRATION_CHECKED"))
        facts = read(facts_output / "fixture-facts.json")
        assert all(facts.values()), facts

        invoke(request("collect-relocated","COLLECT_JOB",{"job":{"path":job_relative}}),
               tree / "outputs/relocated-collection",("PROVISIONAL","JOB_FINISHED"))
        invoke(request("watch-relocated","WATCH_COMPLETION",{"watch":{"path":watch_relative}}),
               tree / "outputs/relocated-watch",("PROVISIONAL","EVENT_DELIVERED"))
        assert sha(tree / scientific["path"]) == science_hash
        event = read((tree / watch_relative).with_name("event.json"))
        delivery = read((tree / watch_relative).with_name("delivery.json"))
        assert event["event_id"] == event_id and event["scientific_status"] == "PASS"
        assert event["scientific_code"] == "POINT_DE_BUILT" and event["scientific_acceptance"] is False
        assert delivery["attempts"] == 1 and delivery["state"] == "acknowledged"
        assert list(read(tree / "receiver.json")["accepted"]) == [event_id]
        references = 0
        for path in (tree / "outputs").rglob("*.wl"):
            for value in re.findall(r'"path"\s*->\s*"([^"\n]+)"',path.read_text()):
                assert not Path(value).is_absolute(), (path,value)
                assert (path.parent / value).exists(), (path,value)
                references += 1
        assert references > 0
        # No computation is started during these final handle/readback checks.
        process_list = subprocess.run(["ps","-eo","pid=,stat=,args="],text=True,capture_output=True,check=True)
        active = [line for line in process_list.stdout.splitlines()
                  if str(work) in line and any(name in line for name in ("local_jobs.py --supervise", "local_jobs.py --monitor", " -file "))]
        assert not active, active
        receipt = {"all_expected":True,"scope":"synthetic supplied-rule bubble integration and finite-sample verification only",
                   "invocations":records,"component_order":list(PACKAGE_FILES),"copied_source_sha256":copied,
                   "kernel_concurrency":1,"wolframscript":runtime,"fixture_facts":facts,
                   "relocation":{"original_absent":not original.exists(),"tree":tree.name,"sample_hashes_unchanged":True,
                                 "resolved_relative_wl_references":references},
                   "job":{"job_id":job["job_id"],"run_id":job["run_id"],"result":scientific["path"],
                          "scientific_status":event["scientific_status"],"scientific_code":event["scientific_code"],
                          "event_id":event_id,"delivery_attempts":delivery["attempts"],"receiver_event_count":1,
                          "scientific_acceptance":False,"no_active_test_children":True},
                   "checker_result":os.path.relpath(check_output / "result.json",work),
                   "facts_file":os.path.relpath(facts_output / "fixture-facts.json",work),
                   "real_reducer_run":False,"live_host_callback":False,"global_physics_claim":False}
        write(work / "integration-evidence.json",receipt)
        print(f"PASS: {len(records)} component calls, {len(facts)} exact fixture facts, relocation and fake delivery",flush=True)
    finally:
        if watch_relative and (tree / watch_relative).exists():
            monitor = (tree / watch_relative).with_name("monitor.json")
            if monitor.exists() and read(monitor)["running"]:
                invoke(request("cleanup-watch","CANCEL_WATCH",{"watch":{"path":watch_relative}}),
                       tree / "outputs/cleanup-watch",("PROVISIONAL","WATCH_CANCEL_REQUESTED"))
                wait_for(lambda: not read(monitor)["running"],10)
        if job_relative and (tree / job_relative).exists():
            handle = tree / job_relative
            terminal = handle.parent / read(handle)["checkpoint"]["path"]
            if not terminal.exists():
                invoke(request("cleanup-job","CANCEL_JOB",{"job":{"path":job_relative}}),
                       tree / "outputs/cleanup-job",("PROVISIONAL","JOB_CANCEL_REQUESTED"))
                wait_for(terminal.exists,10)


if __name__ == "__main__":
    main()
