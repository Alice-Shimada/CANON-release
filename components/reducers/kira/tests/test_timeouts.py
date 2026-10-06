#!/usr/bin/env python3
"""Optional Kira phase budgets with spies and short synthetic child processes."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time
from unittest.mock import patch


def load_module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def spy_worker(adapter_path, canon, request, output):
    adapter = load_module(adapter_path, "timeout_test_adapter")
    task = adapter.read(request)
    backend = adapter.read(adapter.resolve(request, task["payload"]["backend"]))
    original = adapter.OwnedProcesses.run
    records = []

    def run(owner, command, cwd, log_name, environment, timeout=None):
        phase = "prepare" if log_name == "prepare.log" else "import" if log_name == "import.log" else "native"
        delay = environment.get("CANON_TIMEOUT_TEST_DELAY_PHASE")
        if phase == "native" or delay in (phase, "both"):
            child_command = command if phase == "native" else [sys.executable, "-c", "import time; time.sleep(0.1)"]
            value = original(owner, child_command, cwd, log_name, environment, timeout)
        else:
            value = {"command": command, "returncode": 0, "pid": None, "log": log_name,
                     "elapsed_seconds": 0, "timed_out": False, "termination_signal": None}
        records.append({"phase": phase, "forwarded_timeout": timeout, **value})
        adapter.write(output / "phase-spy.json", records)
        if value["returncode"] == 0 and not value["timed_out"] and owner.interrupted is None:
            if phase == "prepare":
                for name in ("request-data.wl", "reduction-kinematics.wl", "kira/targets", "kira/preferred-masters"):
                    (output / name).write_text("neutral phase-forwarding fixture\n")
            elif phase == "import":
                adapter.result(task, output, "PASS", "IBP_REDUCED", {"scope": "mock import; no scientific reduction"})
        return value

    with patch.object(adapter.OwnedProcesses, "run", run):
        return adapter.main(canon, "unused-wolfram-spy", request, output)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--canon", type=Path, required=True)
    p.add_argument("--work", type=Path, required=True)
    p.add_argument("--components", type=Path, action="append", default=[])
    args = p.parse_args()
    canon, work = args.canon.resolve(), args.work.resolve()
    work.mkdir(parents=True, exist_ok=False)
    adapter = Path(__file__).resolve().parents[1] / "run.py"
    fixture_path = canon / "components/reducers/kira/tests/run.py"
    fixture = load_module(fixture_path, "native_timeout_fixture")
    (work / "native-fixture.py").write_text(fixture.FAKE)
    family = {"schema": "canon-neu/reducer-family/v1", "family_ref": "timeout-fixture", "basis_ref": "timeout-source",
        "topology": "native_family", "integral_head": "B", "index_order": ["D1", "D2"],
        "propagator_slots": [1, 2], "top_level_sectors": [3], "loop_momenta": ["l"], "external_momenta": ["p"],
        "propagators": [{"momentum": "l", "mass_squared": "0"}, {"momentum": "l-p", "mass_squared": "0"}],
        "scalar_products": [{"momenta": ["p", "p"], "value": "s"}], "invariants": [{"name": "s", "mass_dimension": 2}],
        "point": [], "dimension": "d", "variables": ["s"], "regulator": "eps"}
    write(work / "family.json", family)
    manifest = work / "spy-components.json"
    write(manifest, {"schema": "canon-neu/components/v1", "steps": {"REDUCE_IBP": {
        "command": ["{python}", str(Path(__file__).resolve()), "--spy-worker", str(adapter), "{canon}"],
        "instructions": str(adapter.with_name("README.md"))}}})
    components = [str(path.resolve()) for path in args.components] + [str(manifest)]
    environment = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
    environment.pop("CANON_COMPONENTS", None)
    records = []

    def invoke(name, settings, expected, mode="normal", cancel=False):
        backend = {"schema": "canon-neu/kira-backend/v1", "executable": sys.executable,
            "options": [str(work / "native-fixture.py"), mode], "seed": {"r": 3, "s": 0, "d": 1},
            "cancel_grace_seconds": 0.05, **settings}
        write(work / (name + "-backend.json"), backend)
        request = work / (name + ".json")
        write(request, {"schema": "canon-neu/script-input/v1", "task_id": name, "step": "REDUCE_IBP", "sector": None,
            "payload": {"reducer_family": {"path": "family.json"}, "backend": {"path": name + "-backend.json"}}})
        output = work / name
        command = [sys.executable, str(canon / "run_step.py"), str(request), str(output)]
        for manifest_path in components:
            command += ["--components", manifest_path]
        if not records:
            description = subprocess.run([*command, "--describe"], env=environment, capture_output=True, text=True, check=True)
            (work / "selected-description.json").write_text(description.stdout)
        with (work / (name + ".log")).open("w") as log:
            process = subprocess.Popen(command, env=environment, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            if cancel:
                ready = output / "kira/cancel-ready"
                while process.poll() is None and not ready.exists():
                    time.sleep(0.02)
                assert ready.exists(), name
                process.send_signal(signal.SIGTERM)
            returncode = process.wait()
        result = json.loads((output / "result.json").read_text())
        assert (result["status"], result["code"]) == expected, (name, result)
        assert (returncode == 0) == (expected[0] == "PASS"), (name, returncode)
        phases = json.loads((output / "phase-spy.json").read_text()) if (output / "phase-spy.json").exists() else []
        runtime = json.loads((output / "backend-run.json").read_text())
        pids = [process.pid] + [phase["pid"] for phase in phases if phase["pid"] is not None]
        descendant = output / "kira/descendant.pid"
        if descendant.exists():
            pids.append(int(descendant.read_text()))
        closure = {}
        for pid in pids:
            state = Path(f"/proc/{pid}/stat")
            status = state.read_text().split(")", 1)[1].split()[0] if state.exists() else "absent"
            closure[str(pid)] = status
            assert status in ("absent", "Z"), (name, pid, status)
        record = {"case": name, "returncode": returncode, "status": result["status"], "code": result["code"],
            "phases": phases, "closed_process_states": closure, "reason": result["summary"].get("reason"),
            "effective_budgets": {key: runtime.get(key) for key in
                ("prepare_timeout_seconds", "timeout_seconds", "import_timeout_seconds")}}
        records.append(record)
        return result, runtime, phases

    keys = ("prepare_timeout_seconds", "timeout_seconds", "import_timeout_seconds")
    profiles = [("defaults", {}, [120.0, None, 120.0]),
        ("unlimited", dict.fromkeys(keys), [None, None, None]),
        ("finite", dict(zip(keys, (0.75, 0.8, 0.9))), [0.75, 0.8, 0.9])]
    for name, settings, expected_budgets in profiles:
        if name == "unlimited":
            settings = {**settings, "environment": {"CANON_TIMEOUT_TEST_DELAY_PHASE": "both"}}
        _, receipt, phases = invoke(name, settings, ("PASS", "IBP_REDUCED"))
        assert [phase["phase"] for phase in phases] == ["prepare", "native", "import"]
        assert [receipt[key] for key in keys] == expected_budgets
        actual = [phase["forwarded_timeout"] for phase in phases]
        assert actual[0] == expected_budgets[0] and actual[2] == expected_budgets[2]
        assert actual[1] is None if expected_budgets[1] is None else 0 < actual[1] <= expected_budgets[1]
    invalid = [0, -1, False, True, "1", [], {}, float("inf"), float("nan"), 10**400]
    for key in keys:
        for index, value in enumerate(invalid):
            result, _, phases = invoke(f"invalid-{key}-{index}", {key: value}, ("ERROR", "KIRA_ADAPTER_ERROR"))
            assert phases == [] and result["summary"]["reason"] == f"{key} must be a positive finite number or null"
    _, _, phases = invoke("invalid-grace", {"cancel_grace_seconds": 0}, ("ERROR", "KIRA_ADAPTER_ERROR"))
    assert phases == []
    no_limits = dict.fromkeys(keys)
    for phase, code in (("prepare", "REDUCTION_INPUT_TIMEOUT"), ("import", "KIRA_IMPORT_TIMEOUT")):
        result, _, phases = invoke(phase + "-finite-timeout", {**no_limits, phase + "_timeout_seconds": 0.04,
            "environment": {"CANON_TIMEOUT_TEST_DELAY_PHASE": phase}}, ("INCONCLUSIVE", code))
        assert phases[-1]["timed_out"] and result["summary"]["timed_out"]
    result, receipt, phases = invoke("native-finite-timeout", {**no_limits, "timeout_seconds": 0.2},
        ("INCONCLUSIVE", "KIRA_TIMEOUT"), mode="timeout")
    assert phases[-1]["timed_out"] and not receipt["reduction_complete"]
    result, receipt, phases = invoke("unlimited-cancel-zero", no_limits,
        ("INCONCLUSIVE", "KIRA_INTERRUPTED"), mode="cancel-zero", cancel=True)
    assert phases[-1]["returncode"] == 0 and phases[-1]["termination_signal"] == signal.SIGTERM
    assert not phases[-1]["timed_out"] and not receipt["reduction_complete"]
    evidence = {"scope": "neutral timeout forwarding and ownership tests; prepare/import use spies, native uses Python fixture",
        "all_expected": True, "components": components, "fixture_source": str(fixture_path),
        "fixture_sha256": hashlib.sha256(fixture_path.read_bytes()).hexdigest(),
        "outer_execution_deadline": None, "individual_memory_cap": None,
        "all_owned_processes_closed": True, "cases": records}
    write(work / "evidence.json", evidence)
    print(json.dumps({"expected_cases": len(records), "all_expected": True, "all_owned_processes_closed": True}))


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--spy-worker":
        sys.exit(spy_worker(*map(Path, sys.argv[2:])))
    main()
