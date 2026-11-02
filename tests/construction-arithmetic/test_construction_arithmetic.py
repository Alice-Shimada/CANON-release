#!/usr/bin/env python3
"""Focused current-checkout construction integration, with caller-supplied fixtures."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import resource
import sys
import time

sys.dont_write_bytecode = True
NAMES = ["rational-nonzero", "root-nonzero", "no-prefix", "default", "unsupported-cubic",
         "native-unavailable", "default-unavailable", "failed-reconstruction"]
ERRORS = {"unsupported-cubic": "UNSUPPORTED_ARITHMETIC_DOMAIN",
          "native-unavailable": "ARITHMETIC_BACKEND_UNAVAILABLE",
          "failed-reconstruction": "ARITHMETIC_RECONSTRUCTION_FAILED"}

def read(path):
    return json.loads(Path(path).read_text())

def write(path, value):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(value, indent=2) + "\n")

def digest(path):
    with Path(path).open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--work", type=Path, required=True)
    args = parser.parse_args(); cfg = read(args.config.resolve())
    root, work = Path(cfg["project_root"]).resolve(), args.work.resolve()
    work.mkdir(parents=True, exist_ok=False)
    os.sched_setaffinity(0, {cfg["cpu"]})
    env = os.environ.copy(); env.update(cfg["environment"])
    env["CANON_WOLFRAMSCRIPT"] = cfg["wolframscript"]
    selection = cfg["complete_components"]
    runtime = Path(cfg["runtime_config"]).resolve()
    execution = root / "components/local-jobs/support.py"
    spec = importlib.util.spec_from_file_location("canon_owned_execution", execution)
    owner_support = importlib.util.module_from_spec(spec); spec.loader.exec_module(owner_support)
    before = {p: digest(p) for p in cfg["guarded_sources"]}
    for row in cfg["fixture_files"]:
        assert digest(row["path"]) == row["sha256"], row
    write(work / "source-guard-before.json", before)
    calls = []

    def request(label, step, payload, sector=None):
        path = work / "requests" / (label + ".json")
        write(path, {"schema": "canon-neu/script-input/v1", "task_id": cfg["task_id"] + ":" + label,
                     "step": step, "sector": sector, "payload": payload})
        return path

    def public(req, output):
        argv = [cfg["python"], str(root / "run_step.py"), str(req), str(output)]
        for manifest in selection:
            argv += ["--components", manifest]
        group = None; peak = 0; over_rss = False; native = []
        def launched(pid):
            nonlocal group
            group = pid
        def cancel_for_rss():
            nonlocal peak, over_rss
            pending = [group] if group else []; records = []
            while pending:
                pid = pending.pop()
                try:
                    base = Path("/proc") / str(pid)
                    status = {s.split(":", 1)[0]: s.split(":", 1)[1].strip()
                              for s in (base / "status").read_text().splitlines() if ":" in s}
                    rss = int(status.get("VmRSS", "0 kB").split()[0]) * 1024
                    records.append(rss)
                    if status.get("Name") == "WolframKernel":
                        native.append({"pid": pid, "group": os.getpgid(pid), "affinity": status["Cpus_allowed_list"], "rss_bytes": rss})
                    pending += [int(s) for s in (base / "task" / str(pid) / "children").read_text().split()]
                except (OSError, ValueError):
                    pass
            peak = max(peak, sum(records)); over_rss = peak > cfg["rss_limit_bytes"]
            return over_rss
        start = time.monotonic(); old = resource.getrusage(resource.RUSAGE_CHILDREN)
        log_path = work / "logs" / (output.parent.name + "-" + output.name + ".log")
        log_path.parent.mkdir(parents=True, exist_ok=True)
        with log_path.open("w") as log:
            code, reason = owner_support.run_owned(argv, str(root), env, log, launched=launched,
                cancelled=cancel_for_rss, timeout=cfg["execution_timeout_seconds"], grace=cfg["cancellation_grace_seconds"])
        usage = resource.getrusage(resource.RUSAGE_CHILDREN)
        try:
            os.killpg(group, 0); closed = False
        except ProcessLookupError:
            closed = True
        result = read(output / "result.json")
        row = {"request": str(req), "output": str(output), "argv": argv, "returncode": code,
               "stop_reason": reason, "wall_seconds": time.monotonic() - start,
               "child_cpu_seconds": usage.ru_utime + usage.ru_stime - old.ru_utime - old.ru_stime,
               "suite_cumulative_reaped_peak_rss_bytes": usage.ru_maxrss * 1024,
               "sampled_aggregate_rss_bytes": peak, "owned_group": group, "group_closed": closed,
               "rss_limit_exceeded": over_rss, "native_observation": native[-1] if native else None,
               "status": result["status"], "code": result["code"], "execution_helper_sha256": digest(execution)}
        calls.append(row); write(work / "calls.json", calls)
        print(json.dumps({"call": output.name, "status": row["status"], "code": row["code"], "closed": closed}), flush=True)
        assert closed and not over_rss and reason is None, row
        return result

    def bind_and_build(name, template, result_base):
        template_path = work / "templates" / (result_base.name + "-" + name + ".json")
        write(template_path, template)
        bind = request(result_base.name + "-bind-" + name, "PREPARE_REQUEST", {"template": {"path": str(template_path)}})
        bound = work / "bound" / result_base.name / name
        assert public(bind, bound)["status"] == "PASS"
        return public(bound / "request.json", result_base / name)

    results = work / "arithmetic-results"
    for name in NAMES:
        template = read(cfg["fixture_templates"][name])
        for key, descriptor in template["payload"].items():
            if isinstance(descriptor, dict) and "path" in descriptor:
                file = cfg["fixture_artifacts"][Path(descriptor["path"]).name]
                template["payload"][key] = {"path": file["path"], "sha256": file["sha256"]}
        runtime_name = "unavailable" if name in ["native-unavailable", "default-unavailable"] else "failed" if name == "failed-reconstruction" else "normal"
        runtime_path = cfg["runtime_variants"][runtime_name]
        template["payload"]["method_options"]["runtime_config"] = {"path": runtime_path, "sha256": digest(runtime_path)}
        template["task_id"] = cfg["task_id"] + ":" + name
        result = bind_and_build(name, template, results)
        expected = ERRORS.get(name)
        assert (result["status"] == "ERROR" and result["code"] == expected) if expected else result["status"] == "PASS", (name, result)
    verify = request("verify-arithmetic", "VERIFY_FFT_FIXTURES", {"fixture_directory": cfg["fixture_directory"],
                     "result_directory": str(results), "method_options": {"runtime_config": {"path": str(runtime), "sha256": digest(runtime)}}})
    assert public(verify, work / "arithmetic-verification")["status"] == "PASS"
    exact = read(work / "arithmetic-verification/checks.json")
    assert exact["all_pass"]

    block_checks = None
    if cfg.get("block_regression", False):
        prep = request("prepare-block", "PREPARE_BLOCK_FIXTURES", {"method_options": {"runtime_config": {"path": str(runtime), "sha256": digest(runtime)}}})
        fixtures = work / "block-fixtures"
        assert public(prep, fixtures)["status"] == "PASS"
        block_results = work / "block-results"
        for name in read(fixtures / "fixtures.json")["names"]:
            template = read(fixtures / (name + ".json"))
            for key, descriptor in template["payload"].items():
                if isinstance(descriptor, dict) and "path" in descriptor:
                    template["payload"][key] = {**descriptor, "path": str(fixtures / descriptor["path"])}
            result = bind_and_build(name, template, block_results)
            expected = "ERROR" if name in ["inexact-rows", "malformed-rows"] else "PASS"
            assert result["status"] == expected, (name, result)
        verify = request("verify-block", "VERIFY_BLOCK_FIXTURES", {"fixture_directory": str(fixtures), "result_directory": str(block_results),
                         "method_options": {"runtime_config": {"path": str(runtime), "sha256": digest(runtime)}}})
        assert public(verify, work / "block-verification")["status"] == "PASS"
        block_checks = read(work / "block-verification/fixture-checks.json")
        assert block_checks["all_pass"]
    after = {p: digest(p) for p in cfg["guarded_sources"]}
    write(work / "source-guard-after.json", {"hashes": after, "unchanged": before == after})
    report = {"all_pass": exact["all_pass"] and (block_checks is None or block_checks["all_pass"]),
              "arithmetic_exact_checks": sum(len(v) for v in exact["checks"].values()),
              "block_exact_checks": block_checks["check_count"] if block_checks else 0,
              "public_call_count": len(calls), "all_groups_closed": all(r["group_closed"] for r in calls),
              "maximum_sampled_rss_bytes": max(r["sampled_aggregate_rss_bytes"] for r in calls),
              "sources_unchanged": before == after, "cpu": cfg["cpu"], "finiteflow_threads": cfg["finiteflow_threads"],
              "scope": "Tiny current-checkout integration regression only; no physical family, canonical/UT/final acceptance or speedup claim"}
    write(work / "report.json", report); print(json.dumps(report), flush=True)
    assert report["all_pass"] and report["sources_unchanged"]

if __name__ == "__main__":
    main()
