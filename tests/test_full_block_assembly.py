#!/usr/bin/env python3
"""Known-answer public BUILD_FULL_DE block-assembly regression."""
import argparse
import json
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--canon", type=Path, required=True)
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--components", type=Path, action="append", default=[])
    args = parser.parse_args()
    root, work = args.canon.resolve(), args.work.resolve()
    work.mkdir(parents=True, exist_ok=False)
    steps = {}
    for step, name in (("PREPARE_BLOCK_FIXTURES", "BuildFullBlockFixtures.wls"),
                       ("VERIFY_BLOCK_FIXTURES", "VerifyFullBlockFixtures.wls")):
        steps[step] = {"command": ["{wolframscript}", "-file", str(root / "tests" / name), "{canon}"],
                       "instructions": str(root / "skills/canon-build-full-de/SKILL.md")}
    fixture_manifest = work / "fixture-components.json"
    fixture_manifest.write_text(json.dumps({"schema": "canon-neu/components/v1", "steps": steps}) + "\n")
    components = [str(p.resolve()) for p in args.components] + [str(fixture_manifest)]

    def run(request, output):
        argv = ["python3", str(root / "run_step.py"), str(request), str(output)]
        for component in components:
            argv += ["--components", component]
        with (work / (output.name + ".log")).open("w") as log:
            result = subprocess.run(argv, stdout=log, stderr=subprocess.STDOUT)
        return json.loads((output / "result.json").read_text()), result.returncode

    def request(name, step, payload):
        path = work / (name + ".json")
        path.write_text(json.dumps({"schema": "canon-neu/script-input/v1", "task_id": name,
                                   "step": step, "sector": None, "payload": payload}) + "\n")
        return path

    fixtures = work / "fixtures"
    prepared, code = run(request("prepare", "PREPARE_BLOCK_FIXTURES", {}), fixtures)
    assert code == 0 and prepared["status"] == "PASS", prepared
    names = json.loads((fixtures / "fixtures.json").read_text())["names"]
    for name in names:
        result, _ = run(fixtures / (name + ".json"), work / "results" / name)
        expected = "ERROR" if name in ("inexact-rows", "malformed-rows") else "PASS"
        assert result["status"] == expected, (name, result)
    verified, code = run(request("verify", "VERIFY_BLOCK_FIXTURES",
                                 {"fixture_directory": str(fixtures), "result_directory": str(work / "results")}),
                         work / "verification")
    evidence = json.loads((work / "verification/fixture-checks.json").read_text())
    print(json.dumps({"all_pass": evidence["all_pass"], "check_count": evidence["check_count"]}))
    assert code == 0 and verified["status"] == "PASS" and evidence["all_pass"]


if __name__ == "__main__":
    main()
