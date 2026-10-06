#!/usr/bin/env python3
"""Bounded synthetic integration tests; every scientific call goes through run_step."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--canon", required=True, type=Path)
    parser.add_argument("--work", required=True, type=Path)
    parser.add_argument("--wolframscript", default=os.environ.get("CANON_WOLFRAMSCRIPT", "wolframscript"))
    args = parser.parse_args()
    canon, work = args.canon.resolve(), args.work.resolve()
    package = Path(__file__).resolve().parents[1]
    work.mkdir(parents=True, exist_ok=False)
    (work / "logs").mkdir()
    records = []
    environment = dict(os.environ, CANON_WOLFRAMSCRIPT=args.wolframscript)

    def command(argv, name):
        completed = subprocess.run(list(map(str, argv)), cwd=work, env=environment, text=True, capture_output=True, timeout=180)
        (work / "logs" / (name + ".txt")).write_text(completed.stdout + completed.stderr)
        if completed.returncode:
            raise AssertionError(f"{name}: process exit {completed.returncode}; see logs/{name}.txt")

    def step(case, request, output, expected, manifest=None):
        root = work / case
        command([sys.executable, canon / "run_step.py", root / request, root / output,
                 "--components", manifest or package / "components.json"], case.replace("/", "_") + "_" + output)
        result = json.loads((root / output / "result.json").read_text())
        actual = (result["status"], result["code"])
        assert actual == expected, (case, output, actual, expected)
        assert result["code"] != "ALL_PASS"
        records.append({"case": case, "output": output, "status": actual[0], "code": actual[1], "expected": True})
        print(f"{case}/{output}: {actual[0]}/{actual[1]}", flush=True)
        return result

    def request(case, filename, **changes):
        root = work / case
        value = json.loads((root / "check.json").read_text())
        value["payload"].update(changes)
        (root / filename).write_text(json.dumps(value, indent=2) + "\n")

    command([args.wolframscript, "-file", package / "tests" / "PrepareCases.wls", package, work], "prepare")
    proposal = ("PROVISIONAL", "DLOG_RECONSTRUCTED")
    validated = ("PASS", "RECONSTRUCTION_VALIDATED")
    step("exact", "reconstruct.json", "fit", proposal)
    positive = step("exact", "check.json", "check", validated)
    assert positive["summary"]["checked_matrix_entries"] == 40
    step("numeric", "reconstruct.json", "fit", proposal)
    step("numeric", "check.json", "check", validated)
    step("indexed", "reconstruct.json", "fit", proposal)
    step("indexed", "check.json", "check", validated)
    sparse = step("sparse", "reconstruct.json", "fit", proposal)
    assert sparse["summary"]["fitted_nonzero_positions"] == 3
    assert sparse["summary"]["all_matrix_positions"] == 6400
    sparse_check = step("sparse", "check.json", "check", validated)
    assert sparse_check["summary"]["checked_matrix_entries"] == 64000
    step("sparse-heldout", "reconstruct.json", "fit", proposal)
    step("sparse-heldout", "check.json", "check", ("FAIL", "RECONSTRUCTION_MISMATCH"))
    zero = step("zero", "reconstruct.json", "fit", proposal)
    assert zero["summary"]["fitted_nonzero_positions"] == 0
    step("zero", "check.json", "check", validated)
    failures = {
        "missing-letter": ("INCONCLUSIVE", "MISSING_LETTERS_OR_INCONSISTENT_TRAINING"),
        "insufficient-rank": ("INCONCLUSIVE", "INSUFFICIENT_TRAINING_RANK"),
        "epsilon": ("INCONCLUSIVE", "EPSILON_NOT_FACTORIZED"),
        "missing-matrix": ("ERROR", "INCOMPLETE_MATRICES"),
        "role-overlap": ("ERROR", "SAMPLE_ROLE_OVERLAP"),
        "low-precision": ("ERROR", "INSUFFICIENT_INPUT_PRECISION"),
        "recognition-bound": ("INCONCLUSIVE", "RATIONAL_RECOGNITION_FAILED"),
    }
    for case, expected in failures.items():
        step(case, "reconstruct.json", "fit", expected)
    heldout_failures = {
        "wrong-frame": ("ERROR", "IDENTITY_OR_FRAME_MISMATCH"),
        "duplicate-point": ("ERROR", "SAMPLE_ROLE_OVERLAP"),
        "missing-validation": ("ERROR", "MISSING_VALIDATION"),
        "validation-changed": ("FAIL", "RECONSTRUCTION_MISMATCH"),
        "blind-changed": ("FAIL", "RECONSTRUCTION_MISMATCH"),
        "rank-growth": ("INCONCLUSIVE", "INSUFFICIENT_TRAINING_RANK"),
    }
    for case, expected in heldout_failures.items():
        step(case, "reconstruct.json", "fit", proposal)
        step(case, "check.json", "check", expected)
    command([args.wolframscript, "-file", package / "tests" / "TamperCases.wls", work], "tamper")
    facts = json.loads((work / "artifact-facts.json").read_text())
    assert all(facts.values()), facts
    for name, expected in {
        "wrong-frame": ("ERROR", "IDENTITY_OR_FRAME_MISMATCH"),
        "changed-coefficients": ("FAIL", "COEFFICIENT_BINDING_MISMATCH"),
        "changed-coefficients-rebound": ("FAIL", "RECONSTRUCTION_MISMATCH"),
    }.items():
        request("exact", name + ".json", reconstruction={"path": "fit/" + name + ".wl"})
        step("exact", name + ".json", name, expected)
    request("exact", "changed-letters.json", raw_letters={"path": "changed-raw-letters.wl"})
    step("exact", "changed-letters.json", "changed-letters", ("ERROR", "RAW_LETTER_BINDING_MISMATCH"))
    step("exact", "propose.json", "proposed", ("PROVISIONAL", "LETTERS_PROPOSED"))
    reconstruction_request = json.loads((work / "exact" / "reconstruct.json").read_text())
    reconstruction_request["payload"]["raw_letters"] = {"path": "proposed/raw-letters.wl"}
    (work / "exact" / "proposed-fit.json").write_text(json.dumps(reconstruction_request))
    step("exact", "proposed-fit.json", "proposed-fit", proposal)
    request("exact", "proposed-check.json", raw_letters={"path": "proposed/raw-letters.wl"}, reconstruction={"path": "proposed-fit/reconstruction.wl"})
    step("exact", "proposed-check.json", "proposed-check", validated)
    relocated_package = work / "relocated" / "package"
    shutil.copytree(package, relocated_package)
    shutil.copytree(work / "exact", work / "relocated" / "example")
    step("relocated/example", "check.json", "relocated-check", validated, relocated_package / "components.json")
    receipt = {"all_expected": True, "scientific_steps": len(records), "cases": records, "artifact_facts": facts,
               "kernel_concurrency": 1, "physical_results_recomputed": False, "scope": "synthetic component tests only"}
    (work / "test-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(f"PASS: {len(records)} step expectations and {len(facts)} artifact facts", flush=True)


if __name__ == "__main__":
    main()
