#!/usr/bin/env python3
"""Standalone Kira discovery/reduction from a reducer-neutral family."""

import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import time


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write(path, value):
    temporary = path.with_name("." + path.name + ".tmp")
    temporary.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def resolve(declaring, value):
    return (declaring.parent / (value["path"] if isinstance(value, dict) else value)).resolve()


def descriptor(declaring, path, kind="json"):
    return {"type": kind, "path": os.path.relpath(path, declaring.parent), "sha256": digest(path)}


def result(task, output, status, code, summary, artifacts=None):
    write(output / "result.json", {"schema":"canon-neu/script-result/v1", "task_id":task["task_id"],
        "step":task["step"], "status":status, "code":code, "artifacts":artifacts or {}, "summary":summary})
    return 0 if status == "PASS" else 3 if status == "INCONCLUSIVE" else 2


def phase_timeout(backend, key, default=None):
    value = backend.get(key, default)
    if value is None:
        return None
    message = f"{key} must be a positive finite number or null"
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(message)
    try:
        seconds = float(value)
    except OverflowError as exc:
        raise ValueError(message) from exc
    if not math.isfinite(seconds) or seconds <= 0:
        raise ValueError(message)
    return seconds


def native_identifier(value):
    if not isinstance(value, str) or re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", value) is None:
        raise ValueError(f"Kira native identifiers must be simple names: {value!r}")
    return value


def project_path(project, value):
    path = Path(value)
    if path.is_absolute() or ".." in path.parts:
        raise ValueError(f"native project paths must stay relative to the project: {value}")
    return project / path


def recovery_source(source, family, family_path):
    receipt_path = source / "backend-run.json"
    saved = read(receipt_path)
    if saved["schema"] != "canon-neu/kira-run/v1" or saved["step"] != "REDUCE_IBP":
        raise ValueError("import_from requires a REDUCE_IBP output directory")
    if any(saved[key] != family[field] for key, field in
           (("family_ref","family_ref"),("basis_ref","basis_ref"),
            ("native_topology","topology"),("point","point"))):
        raise ValueError("import_from family, basis or point binding differs")
    for key in ("reducer_family", "backend"):
        if digest(resolve(receipt_path,saved[key])) != saved[key]["sha256"]:
            raise ValueError(f"import_from {key} has changed since native execution")
    if digest(family_path) != saved["reducer_family"]["sha256"]:
        raise ValueError("import_from neutral family differs")
    for value in saved.get("prepared_inputs", {}).values():
        if digest(resolve(receipt_path,value)) != value["sha256"]:
            raise ValueError("import_from prepared inputs have changed")
    commands = saved["commands"]
    if not commands or len(commands) != len(saved["jobs"]) or any(
            item["returncode"] != 0 or item["timed_out"] or item["termination_signal"] is not None
            for item in commands):
        raise ValueError("import_from native jobs did not complete successfully")
    previous = read(source / "result.json")
    if previous["step"] != "REDUCE_IBP":
        raise ValueError("import_from result step differs")
    backend = read(resolve(receipt_path,saved["backend"]))
    project = resolve(receipt_path,saved["project"])
    topology = family["topology"]
    paths = {"native_masters":project_path(project,backend.get("native_masters",f"results/{topology}/masters.final")),
             "native_rules":project_path(project,backend.get("native_rules",f"results/{topology}/kira_targets.m"))}
    context = read(source / "interop.json")
    for key, path in paths.items():
        if resolve(source / "interop.json",context[key]) != path.resolve():
            raise ValueError("import_from native export binding differs")
        if key in saved.get("native_outputs", {}) and digest(path) != saved["native_outputs"][key]["sha256"]:
            raise ValueError("import_from native export has changed")
    return receipt_path, previous, paths


def prepare_project(family, backend, config_path, project, step):
    topology = native_identifier(family["topology"])
    for name in [*family["loop_momenta"], *family["external_momenta"]]:
        native_identifier(name)
    if len(family["index_order"]) != len(family["propagators"]):
        raise ValueError("index_order and propagator lengths disagree")
    config = project / "config"
    config.mkdir(parents=True)
    family_lines = ["integralfamilies:", f"  - name: {json.dumps(topology)}",
                    "    loop_momenta: " + json.dumps(family["loop_momenta"]),
                    "    top_level_sectors: " + json.dumps(family["top_level_sectors"]),
                    "    propagators:"]
    family_lines += ["      - " + json.dumps([item["momentum"], item["mass_squared"]])
                     for item in family["propagators"]]
    (config / "integralfamilies.yaml").write_text("\n".join(family_lines) + "\n")
    invariants = [[native_identifier(item["name"]), item["mass_dimension"]] for item in family["invariants"]]
    if not all(isinstance(item[1], int) for item in invariants):
        raise ValueError("invariant mass dimensions must be declared integers")
    kinematics = ["kinematics:", "  incoming_momenta: []",
                  "  outgoing_momenta: " + json.dumps(family["external_momenta"]),
                  "  momentum_conservation: []", "  kinematic_invariants: " + json.dumps(invariants),
                  "  scalarproduct_rules:"]
    kinematics += ["    - " + json.dumps([item["momenta"], item["value"]]) for item in family["scalar_products"]]
    (config / "kinematics.yaml").write_text("\n".join(kinematics) + "\n")
    for item in backend.get("files", []):
        destination = project_path(project, item["destination"])
        if destination.exists() or item["destination"] in ("targets", "preferred-masters"):
            raise ValueError("backend files cannot overwrite generated kinematics or integral lists")
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(resolve(config_path, item["path"]), destination)
    if "jobs" in backend:
        jobs = []
        if not backend["jobs"]:
            raise ValueError("caller jobs must be a nonempty ordered list")
        for supplied in backend["jobs"]:
            source = resolve(config_path, supplied)
            destination = project / source.name
            if destination.exists():
                raise ValueError("caller jobs have colliding native basenames")
            shutil.copyfile(source, destination)
            jobs.append(destination.name)
        return jobs
    seed = backend["seed"]
    if not all(isinstance(seed[key], int) and seed[key] >= 0 for key in ("r", "s")):
        raise ValueError("generated jobs require nonnegative integer seed r and s")
    if "d" in seed and (not isinstance(seed["d"], int) or seed["d"] < 0):
        raise ValueError("seed d must be a nonnegative integer")
    values = {"topologies":[topology], "sectors":family["top_level_sectors"],
              **{key:seed[key] for key in ("r","s","d") if key in seed}}
    selection = json.dumps(values)
    lines = ["jobs:", "  - reduce_sectors:", "      reduce:", "        - " + selection, "      select_integrals:"]
    if step == "DISCOVER":
        lines += ["        select_mandatory_recursively:", "          - " + selection,
                  "      iterative_reduction: sectorwise", "      run_initiate: masters"]
    else:
        engine = backend.get("reduction_engine", "firefly")
        if engine not in ("firefly", "fermat"):
            raise ValueError("reduction_engine must be firefly or fermat")
        lines += ["        select_mandatory_list:", "          - " + json.dumps([topology,"targets"]),
                  "      preferred_masters: preferred-masters", "      run_initiate: true"]
        lines += (["      run_firefly: true"] if engine == "firefly" else
                  ["      run_triangular: true", "      run_back_substitution: true"])
        lines += ["  - kira2math:", "      target:", "        - " + json.dumps([topology,"targets"])]
    (project / "jobs.yaml").write_text("\n".join(lines) + "\n")
    return ["jobs.yaml"]


class OwnedProcesses:
    """A signal always marks interruption, even if the native child exits zero."""
    def __init__(self, output, grace):
        if os.name != "posix" or not all(hasattr(os, name) for name in ("waitid","WNOWAIT","killpg")):
            raise ValueError("POSIX process groups and waitid(WNOWAIT) are required")
        self.output, self.grace, self.interrupted = output, grace, None
        self.previous = {number:signal.signal(number,self.on_signal) for number in (signal.SIGTERM,signal.SIGINT)}

    def on_signal(self, number, _frame):
        self.interrupted = number

    def close(self):
        for number, handler in self.previous.items():
            signal.signal(number, handler)

    def run(self, command, cwd, log_name, environment, timeout=None):
        started = time.monotonic()
        with (self.output / log_name).open("w") as log:
            child = subprocess.Popen(command, cwd=cwd, env=environment, stdin=subprocess.DEVNULL,
                                     stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            write(self.output / "active-process.json", {"pid":child.pid,"process_group":child.pid,"log":log_name})
            stopped, timed_out = None, False

            def terminate(number):
                try:
                    os.killpg(child.pid,number)
                except ProcessLookupError:
                    pass

            try:
                while True:
                    exited = os.waitid(os.P_PID,child.pid,os.WEXITED|os.WNOHANG|os.WNOWAIT)
                    if exited is not None:
                        terminate(signal.SIGKILL)
                        returncode = child.wait()
                        break
                    elapsed = time.monotonic() - started
                    if stopped is None and (self.interrupted is not None or timeout is not None and elapsed >= timeout):
                        timed_out = self.interrupted is None
                        stopped = time.monotonic()
                        terminate(signal.SIGTERM)
                    if stopped is not None and time.monotonic()-stopped >= self.grace:
                        terminate(signal.SIGKILL)
                    time.sleep(0.02)
            finally:
                if child.returncode is None:
                    terminate(signal.SIGKILL)
                    child.wait()
        return {"command":command,"returncode":returncode,"pid":child.pid,"log":log_name,
                "elapsed_seconds":round(time.monotonic()-started,6),"timed_out":timed_out,
                "termination_signal":self.interrupted}


def main(canon, wolfram, request, output):
    task = read(request)
    output.mkdir(parents=True,exist_ok=True)
    if (output / "result.json").exists():
        raise ValueError("use a fresh output directory")
    receipt_path = output / "backend-run.json"
    receipt = {"schema":"canon-neu/kira-run/v1","step":task["step"],"commands":[],
               "master_discovery_complete":False,"reduction_complete":False}
    owner = None
    try:
        if task["schema"] != "canon-neu/script-input/v1" or task["step"] not in ("DISCOVER","REDUCE_IBP"):
            raise ValueError("Kira adapter implements DISCOVER and REDUCE_IBP only")
        family_path = resolve(request,task["payload"]["reducer_family"])
        config_path = resolve(request,task["payload"]["backend"])
        family, backend = read(family_path),read(config_path)
        if family["schema"] != "canon-neu/reducer-family/v1" or backend["schema"] != "canon-neu/kira-backend/v1":
            raise ValueError("unsupported neutral family or Kira backend schema")
        source = resolve(config_path,backend["import_from"]) if "import_from" in backend else None
        if source is not None and task["step"] != "REDUCE_IBP":
            raise ValueError("import_from is supported for REDUCE_IBP only")
        if source is None:
            executable = backend["executable"]
            if "/" in executable or "\\" in executable:
                executable = str(resolve(config_path,executable))
            executable = shutil.which(executable)
            if executable is None:
                raise ValueError("configured Kira executable was not found")
        environment = os.environ.copy()
        environment.update(backend.get("environment",{}))
        grace = float(backend.get("cancel_grace_seconds",1))
        budget = phase_timeout(backend,"timeout_seconds")
        prepare_budget = phase_timeout(backend,"prepare_timeout_seconds",120)
        import_budget = phase_timeout(backend,"import_timeout_seconds",120)
        if grace <= 0:
            raise ValueError("cancellation grace must be positive")
        owner = OwnedProcesses(output,grace)
        project = output / "kira"
        project.mkdir()
        jobs = prepare_project(family,backend,config_path,project,task["step"]) if source is None else []
        topology = family["topology"]
        masters = backend.get("native_masters",f"results/{topology}/" + ("masters" if task["step"] == "DISCOVER" else "masters.final"))
        rules = backend.get("native_rules",f"results/{topology}/kira_targets.m")
        context = {"schema":"canon-neu/kira-interop/v1", "native_masters":os.path.relpath(project_path(project,masters),output),
                   "native_rules":os.path.relpath(project_path(project,rules),output)}
        write(output / "interop.json",context)
        receipt.update(family_ref=family["family_ref"],basis_ref=family["basis_ref"],native_topology=topology,
                       reducer_family=descriptor(receipt_path,family_path),backend=descriptor(receipt_path,config_path),
                       jobs=jobs,project="kira",point=family["point"],options=backend.get("options",[]),
                       timeout_seconds=budget,prepare_timeout_seconds=prepare_budget,
                       import_timeout_seconds=import_budget,native_execution_inherited=source is not None)
        if source is None:
            receipt.update(executable=executable,executable_sha256=digest(Path(executable)))
        else:
            source_receipt, source_result, paths = recovery_source(source,family,family_path)
            context = {"schema":"canon-neu/kira-interop/v1",
                       **{key:os.path.relpath(path,output) for key,path in paths.items()}}
            write(output / "interop.json",context)
            receipt.update(import_from=descriptor(receipt_path,source_receipt),
                           source_result=descriptor(receipt_path,source / "result.json"),
                           source_result_code=source_result["code"])
        write(receipt_path,receipt)
        interop = Path(__file__).with_name("Interop.wls")
        if task["step"] == "REDUCE_IBP":
            stage = owner.run([wolfram,"-file",str(interop),str(canon),"prepare",str(request),str(output)],
                              output,"prepare.log",environment,prepare_budget)
            if stage["timed_out"]:
                return result(task,output,"INCONCLUSIVE","REDUCTION_INPUT_TIMEOUT",stage)
            if stage["returncode"] != 0 or owner.interrupted is not None:
                if (output / "result.json").exists():
                    return 2
                return result(task,output,"INCONCLUSIVE" if owner.interrupted else "ERROR",
                              "KIRA_INTERRUPTED" if owner.interrupted else "REDUCTION_INPUT_FAILED",stage)
            if source is not None:
                for name in ("request-data.wl", "reduction-kinematics.wl", "kira/targets", "kira/preferred-masters"):
                    if digest(output / name) != digest(source / name):
                        raise ValueError("import_from target, source-basis or point binding differs")
            receipt["prepared_inputs"] = {name:descriptor(receipt_path,output / name) for name in
                ("request-data.wl", "reduction-kinematics.wl", "kira/targets", "kira/preferred-masters")}
            write(receipt_path,receipt)
        native_started = time.monotonic()
        for number, job in enumerate(jobs,1):
            remaining = None if budget is None else max(0.001,budget-(time.monotonic()-native_started))
            execution = owner.run([executable,*backend.get("options",[]),job],project,f"native-{number:02d}.log",environment,remaining)
            receipt["commands"].append(execution)
            write(receipt_path,receipt)
            if owner.interrupted is not None or execution["timed_out"] or execution["returncode"] != 0:
                interrupted = owner.interrupted is not None or execution["timed_out"] or execution["returncode"] < 0
                code = "KIRA_TIMEOUT" if execution["timed_out"] else "KIRA_INTERRUPTED" if interrupted else "KIRA_FAILED"
                return result(task,output,"INCONCLUSIVE" if interrupted else "ERROR",code,
                              {"master_discovery_complete":False,"reduction_complete":False,**execution},
                              {"backend_run":descriptor(output / "result.json",receipt_path)})
        native_paths = {"native_masters":resolve(output / "interop.json",context["native_masters"])}
        if task["step"] == "REDUCE_IBP":
            native_paths["native_rules"] = resolve(output / "interop.json",context["native_rules"])
        required = list(native_paths.values())
        if not all(path.is_file() and path.stat().st_size for path in required):
            return result(task,output,"INCONCLUSIVE","NATIVE_OUTPUT_MISSING",
                          {"missing":[os.path.relpath(path,output) for path in required if not path.is_file() or not path.stat().st_size],
                           "master_discovery_complete":False,"reduction_complete":False},
                          {"backend_run":descriptor(output / "result.json",receipt_path)})
        receipt["native_outputs"] = {key:descriptor(receipt_path,path,"native-output") for key,path in native_paths.items()}
        receipt["native_execution_complete"] = True
        write(receipt_path,receipt)
        stage = owner.run([wolfram,"-file",str(interop),str(canon),"import",str(request),str(output)],
                          output,"import.log",environment,import_budget)
        if owner.interrupted is not None or stage["timed_out"]:
            return result(task,output,"INCONCLUSIVE","KIRA_IMPORT_TIMEOUT" if stage["timed_out"] else "KIRA_INTERRUPTED",stage,
                          {"backend_run":descriptor(output / "result.json",receipt_path)})
        if not (output / "result.json").exists():
            return result(task,output,"ERROR","NATIVE_IMPORT_FAILED",stage,
                          {"backend_run":descriptor(output / "result.json",receipt_path)})
        final = read(output / "result.json")
        if stage["returncode"] != 0 and final["status"] == "PASS":
            return result(task,output,"ERROR","NATIVE_IMPORT_FAILED",stage,
                          {"backend_run":descriptor(output / "result.json",receipt_path)})
        if final["status"] == "PASS":
            receipt["master_discovery_complete" if task["step"] == "DISCOVER" else "reduction_complete"] = True
        write(receipt_path,receipt)
        final["artifacts"]["backend_run"] = descriptor(output / "result.json",receipt_path)
        write(output / "result.json",final)
        return 0 if final["status"] == "PASS" else 3 if final["status"] == "INCONCLUSIVE" else 2
    except (OSError,ValueError,KeyError,TypeError) as exc:
        write(receipt_path,receipt)
        return result(task,output,"ERROR","KIRA_ADAPTER_ERROR",{"reason":str(exc),"master_discovery_complete":False,"reduction_complete":False},
                      {"backend_run":descriptor(output / "result.json",receipt_path)})
    finally:
        if owner:
            owner.close()


if __name__ == "__main__":
    canon_root, wolframscript, request_path, output_dir = sys.argv[1:]
    sys.exit(main(Path(canon_root).resolve(),wolframscript,Path(request_path).resolve(),Path(output_dir).resolve()))
