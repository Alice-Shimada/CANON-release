#!/usr/bin/env python3
"""Bounded argv/sequence regressions through the current runner and explicit adapter."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--canon", type=Path, required=True)
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--wolframscript", default=os.environ.get("CANON_WOLFRAMSCRIPT", "wolframscript"))
    args = parser.parse_args()
    canon, work = args.canon.resolve(), args.work.resolve()
    package = Path(__file__).resolve().parents[1]
    manifest = package.parent / "fire7" / "components.json"
    driver = package / "tests" / "SequenceDriver.py"
    work.mkdir(parents=True, exist_ok=False)
    environment = dict(os.environ, CANON_WOLFRAMSCRIPT=args.wolframscript)
    records = []

    def call(command, log):
        result = subprocess.run(list(map(str, command)), cwd=work, env=environment,
                                text=True, capture_output=True, timeout=120)
        log.write_text(result.stdout + result.stderr)
        assert result.returncode == 0, (command, result.returncode, result.stdout, result.stderr)

    def write_json(path, data):
        path.write_text(json.dumps(data, indent=2) + "\n")

    fixture = work / "fixture inputs"
    call([args.wolframscript, "-file", package / "examples" / "make-example.wls", fixture], work / "prepare.log")
    source_backend = json.loads((fixture / "fire7" / "backend.json").read_text())
    source_request = json.loads((fixture / "fire7-REDUCE_IBP.json").read_text())

    def command(action, count, *arguments):
        return ["{python}", str(driver), "{context}", action, str(count), *arguments]

    def run(name, command_fields, expected, bad_rules=False, escaping=False):
        directory = work / name
        directory.mkdir()
        request = json.loads(json.dumps(source_request))
        request["task_id"] = name
        for key, value in request["payload"].items():
            value["path"] = "backend.json" if key == "backend" else str(fixture / value["path"])
        backend = json.loads(json.dumps(source_backend))
        backend["fixture_exports"] = {"masters.wl": str(fixture / "fire7" / "native-masters.wl"),
                                       "rules.wl": str(fixture / "fire7" / "native-rules.wl")}
        if bad_rules:
            invalid = directory / "invalid-rules.wl"
            invalid.write_text("{G[7,{2,1,0}] -> G[7,{9,9,0}]}\n")
            backend["fixture_exports"]["rules.wl"] = str(invalid)
        operation = dict(mode="command", source_format="fire7-rules",
                         exports={"masters": "masters.wl", "rules": "../rules.wl" if escaping else "rules.wl"},
                         **command_fields)
        backend["operations"] = {"REDUCE_IBP": operation}
        write_json(directory / "backend.json", backend)
        write_json(directory / "request.json", request)
        call([sys.executable, canon / "run_step.py", directory / "request.json", directory / "out",
              "--components", manifest], directory / "test.log")
        result = json.loads((directory / "out" / "result.json").read_text())
        assert (result["status"], result["code"]) == expected, (name, result)
        trace_path = directory / "out" / "native" / "sequence-trace.json"
        trace = json.loads(trace_path.read_text()) if trace_path.exists() else []
        runtime_path = directory / "out" / "normalization-run.json"
        runtime = json.loads(runtime_path.read_text()) if runtime_path.exists() else {}
        if result["status"] == "PASS":
            assert result["summary"]["driver_executed"]
            assert not result["summary"]["new_reduction_executed"]
            assert result["summary"]["native_engine_validation"] == "not established by artifact normalization"
            assert "driver_receipt" not in runtime
        else:
            assert not result["artifacts"]
            assert not (directory / "out" / "ibp-reduction.wl").exists()
        records.append({"case": name, "status": result["status"], "code": result["code"],
                        "actions": [item["action"] for item in trace],
                        "exit_codes": [item["exit_code"] for item in runtime.get("command_results", [])], "expected": True})
        print(name + ": " + "/".join(expected), flush=True)
        return directory, trace, runtime

    _, trace, runtime = run("single argv", {"argv": command("export", 0)}, ("PASS", "IBP_REDUCED"))
    assert [item["action"] for item in trace] == ["export"]
    assert runtime["argv"] == runtime["commands"][0] == runtime["command_results"][0]["argv"]

    literal = "space ; $HOME $(literal) `literal`"
    commands = [command("prepare", 0, "{backend_dir}/input with spaces.txt", literal),
                command("solve", 1, "{input}", "{output}"), command("export", 2)]
    # Resolve a relative executable from the backend directory, independently of command cwd.
    commands[1][0] = os.path.relpath(sys.executable, work / "ordered commands")
    directory, trace, runtime = run("ordered commands", {"commands": commands}, ("PASS", "IBP_REDUCED"))
    assert [item["action"] for item in trace] == ["prepare", "solve", "export"]
    assert trace[0]["arguments"] == [str(directory / "input with spaces.txt"), literal]
    assert trace[1]["arguments"] == [str(directory / "request.json"), str(directory / "out" / "native")]
    assert runtime["commands"][1][0] == str(Path(sys.executable).resolve())
    assert runtime["argv"] == [] and [item["exit_code"] for item in runtime["command_results"]] == [0, 0, 0]

    directory, trace, runtime = run("failure stops sequence", {"commands": [command("export", 0), command("fail", 1), command("unreachable", 2)]},
                                    ("ERROR", "NATIVE_DRIVER_FAILED"))
    assert [item["action"] for item in trace] == ["export", "fail"]
    assert [item["exit_code"] for item in runtime["command_results"]] == [0, 7]
    assert (directory / "out" / "native" / "rules.wl").is_file()
    assert not (directory / "out" / "normalization-receipt.wl").exists()

    _, trace, runtime = run("launch failure stops sequence", {"commands": [command("prepare", 0),
                          ["./missing-native-command"], command("unreachable", 1)]}, ("ERROR", "NATIVE_DRIVER_FAILED"))
    assert [item["action"] for item in trace] == ["prepare"]
    assert [item["exit_code"] for item in runtime["command_results"]] == [0, None]
    assert "error" in runtime["command_results"][-1]

    run("successful command missing exports", {"commands": [command("prepare", 0)]}, ("ERROR", "MISSING_NATIVE_EXPORT"))
    run("successful commands invalid rules", {"commands": [command("prepare", 0), command("export", 1)]},
        ("ERROR", "UNRESOLVED_NATIVE_RULES"), bad_rules=True)
    for name, fields in (("ambiguous commands", {"argv": command("export", 0), "commands": [command("export", 0)]}),
                         ("empty commands", {"commands": []}), ("non argv commands", {"commands": ["echo", "text"]})):
        _, trace, _ = run(name, fields, ("ERROR", "INVALID_NATIVE_BACKEND"))
        assert not trace
    _, trace, _ = run("escaping export", {"commands": [command("export", 0)]}, ("ERROR", "INVALID_NATIVE_BACKEND"), escaping=True)
    assert not trace

    verify = work / "verify.wls"
    verify.write_text('paths=Rest[$ScriptCommandLine]; expected=Get[First[paths]]; facts=Table[r=Get[p]; '
                     'r["masters"]===expected["masters"] && First/@r["rules"]===First/@expected["rules"] && '
                     'AllTrue[Last/@r["rules"]-Last/@expected["rules"],TrueQ[Together[#]===0]&],{p,Rest[paths]}]; '
                     'If[!And@@facts,Print[facts];Exit[1]];Print["exact ordered rules: PASS"];\n')
    call([args.wolframscript, "-file", verify, fixture / "expected.wl",
          work / "single argv" / "out" / "ibp-reduction.wl", work / "ordered commands" / "out" / "ibp-reduction.wl"], work / "readback.log")
    write_json(work / "sequence-receipt.json", {"all_expected": True, "cases": records, "exact_rule_readbacks": 2,
               "kernel_concurrency": 1, "native_reducer_campaigns": 0, "native_end_to_end_validated": False,
               "runner": str(canon / "run_step.py"), "components": [str(manifest)],
               "scope": "ordered literal command execution, failure short-circuit, and exact synthetic output normalization"})
    print(f"PASS: {len(records)} sequence expectations and 2 exact rule readbacks", flush=True)


if __name__ == "__main__":
    main()
