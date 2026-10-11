#!/usr/bin/env python3
"""Public point collection/reconstruction symbol-frame roundtrips; generic fixtures only."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--canon", required=True, type=Path)
    parser.add_argument("--work", required=True, type=Path)
    parser.add_argument("--reconstruction", required=True, type=Path)
    parser.add_argument("--components", action="append", type=Path, default=[])
    args = parser.parse_args()
    canon, work = args.canon.resolve(), args.work.resolve()
    point = Path(__file__).resolve().parents[1]
    reconstruction = args.reconstruction.resolve()
    work.mkdir(parents=True, exist_ok=False)
    runtime = os.environ.get("CANON_WOLFRAMSCRIPT") or shutil.which("wolframscript")
    if not runtime:
        raise RuntimeError("CANON_WOLFRAMSCRIPT or wolframscript on PATH is required")
    records = []

    def run(command, log):
        result = subprocess.run(list(map(str, command)), text=True, capture_output=True, timeout=120)
        (work / log).write_text(result.stdout + result.stderr)
        return result

    script = point / "tests" / "DataReaderChecks.wls"
    prepared = run([runtime, "-file", script, canon, work, "prepare", work / "writer-checks.json"], "prepare.log")
    assert prepared.returncode == 0, prepared.stderr

    def step(case, request, output, package, expected):
        root = work / case
        manifests = [p.resolve() for p in args.components] + [package / "components.json"]
        command = [sys.executable, canon / "run_step.py", root / request, root / output]
        for manifest in manifests:
            command.extend(["--components", manifest])
        result = run(command, case + "-" + output + ".log")
        receipt = json.loads((root / output / "result.json").read_text())
        actual = receipt["status"], receipt["code"]
        assert actual == expected, (case, output, actual, expected, result.stderr)
        assert result.returncode == (1 if actual[0] == "FAIL" else 0), result.stderr
        records.append({"case": case, "output": output, "status": actual[0], "code": actual[1],
                        "command": list(map(str, command)), "components": list(map(str, manifests))})
        print(case + "/" + output + ": " + "/".join(actual), flush=True)

    for case in ["canonical", "global", "foreign", "qualified-canonical"]:
        step(case, "collect.json", "collect", point, ("PASS", "DE_SAMPLES_COLLECTED"))
        step(case, "fit.json", "fit", reconstruction, ("PROVISIONAL", "DLOG_RECONSTRUCTED"))
        step(case, "check.json", "check", reconstruction, ("PASS", "RECONSTRUCTION_VALIDATED"))
    for tag in ["foreign-variable", "foreign-regulator"]:
        step("canonical", tag + ".json", tag, point, ("FAIL", "SAMPLE_IDENTITY_MISMATCH"))
    step("canonical", "foreign-letters.json", "foreign-letters", reconstruction,
         ("ERROR", "IDENTITY_OR_FRAME_MISMATCH"))
    checked = run([runtime, "-file", script, canon, work, "check", work / "identity-checks.json"], "identity-checks.log")
    facts = json.loads((work / "identity-checks.json").read_text())
    assert checked.returncode == 0 and all(facts.values()), facts
    writer = json.loads((work / "writer-checks.json").read_text())
    assert all(writer.values()), writer
    evidence = {"all_pass": True, "public_steps": records, "identity_checks": facts,
                "writer_checks": writer, "kernels_in_parallel": 1,
                "scope": "Generic public IO/collection/reconstruction fixtures; no native reduction or physical-family result"}
    (work / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print(f"PASS: {len(records)} public steps and {len(facts) + len(writer)} readback facts", flush=True)


if __name__ == "__main__":
    main()
