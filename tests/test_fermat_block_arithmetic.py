#!/usr/bin/env python3
"""Public exact fixtures for the optional BUILD_FULL_DE Fermatica backend."""
import argparse
import json
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--canon", type=Path, required=True)
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--package-entry", type=Path, required=True)
    parser.add_argument("--components", type=Path, action="append", default=[])
    args = parser.parse_args()
    root, work = args.canon.resolve(), args.work.resolve()
    work.mkdir(parents=True, exist_ok=False)
    manifest = work / "fixture-components.json"
    steps = {}
    for step, entry in (("PREPARE_BLOCK_FIXTURES", "BuildFullFermatFixtures.wls"),
                        ("VERIFY_FERMAT_FIXTURES", "VerifyFullFermatFixtures.wls")):
        steps[step] = {"command": ["{wolframscript}", "-file", str(root / "tests" / entry), "{canon}"],
                       "instructions": str(root / "docs/full-block-assembly.md")}
    manifest.write_text(json.dumps({"schema": "canon-neu/components/v1", "steps": steps}) + "\n")
    components = [str(p.resolve()) for p in args.components] + [str(manifest)]

    def call(request, output):
        argv = ["python3", str(root / "run_step.py"), str(request), str(output)]
        for component in components:
            argv += ["--components", component]
        with (work / (output.name + ".log")).open("w") as log:
            subprocess.run(argv, stdout=log, stderr=subprocess.STDOUT)
        return json.loads((output / "result.json").read_text())

    def request(name, step, payload):
        path = work / (name + ".json")
        path.write_text(json.dumps({"schema": "canon-neu/script-input/v1", "task_id": name,
                                   "step": step, "sector": None, "payload": payload}) + "\n")
        return path

    assert call(request("prepare", "PREPARE_BLOCK_FIXTURES", {}), work / "fixtures")["status"] == "PASS"
    assert call(request("prepare-extra", "PREPARE_BLOCK_FIXTURES", {"extra": True}),
                work / "extra-fixtures")["status"] == "PASS"
    names = ["zero", "rational-zero", "unsupported-cube", "lower-nonzero", "upper-nonzero",
             "no-prefix", "inexact-upper", "inexact-rows", "malformed-rows", "no-prefix-default"]
    for name in names:
        case = "no-prefix" if name == "no-prefix-default" else name
        base = work / ("extra-fixtures" if case in ("rational-zero", "unsupported-cube") else "fixtures")
        task = json.loads((base / (case + ".json")).read_text())
        task["task_id"] = "fermat-fixture-" + name
        for value in task["payload"].values():
            if isinstance(value, dict) and "path" in value:
                value["path"] = str((base / value["path"]).resolve())
        task["payload"]["method_options"] = ({} if name == "no-prefix-default" else
            {"block_backend": "fermat", "package_entry": str(args.package_entry.resolve())})
        path = work / (name + ".json")
        path.write_text(json.dumps(task) + "\n")
        folder = "zero-native-output" if name == "zero" else name + "-output"
        result = call(path, work / folder)
        assert result["status"] == ("PASS" if name in ("zero", "rational-zero", "no-prefix-default") else "ERROR")
    result = call(request("verify", "VERIFY_FERMAT_FIXTURES", {"workspace": str(work),
        "method_options": {"package_entry": str(args.package_entry.resolve())}}), work / "verification")
    evidence = json.loads((work / "verification/fixture-checks.json").read_text())
    print(json.dumps({"all_pass": evidence["all_pass"], "check_count": evidence["check_count"]}))
    assert result["status"] == "PASS" and evidence["all_pass"]


if __name__ == "__main__":
    main()
