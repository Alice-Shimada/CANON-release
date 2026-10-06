#!/usr/bin/env python3
"""Synthetic native-format conversion tests; actual reducer execution is explicitly not claimed."""
import argparse
import ast
import json
import os
from pathlib import Path
import shutil
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
    reducers = package.parent
    work.mkdir(parents=True, exist_ok=False)
    (work / "logs").mkdir()
    environment = dict(os.environ, CANON_WOLFRAMSCRIPT=args.wolframscript)
    results = []

    def call(command, name):
        completed = subprocess.run(list(map(str, command)), cwd=work, env=environment, text=True, capture_output=True, timeout=180)
        (work / "logs" / (name.replace("/", "_") + ".txt")).write_text(completed.stdout + completed.stderr)
        if completed.returncode:
            raise AssertionError((name, completed.returncode, completed.stdout[-2000:], completed.stderr[-2000:]))

    def step(case, adapter, name, output, expected=("PASS", None), manifest=None):
        case_dir = work / case
        call([sys.executable, canon / "run_step.py", case_dir / (adapter + "-" + name + ".json"), case_dir / output,
              "--components", manifest or reducers / adapter / "components.json"], case + "_" + output)
        result = json.loads((case_dir / output / "result.json").read_text())
        expected_code = expected[1] or {"DISCOVER": "SECTORS_READY", "REDUCE_IBP": "IBP_REDUCED", "BUILD_CUT_DE": "OK"}[name]
        assert (result["status"], result["code"]) == (expected[0], expected_code), (case, adapter, name, result)
        results.append({"case": case, "adapter": adapter, "step": name, "status": result["status"], "code": result["code"], "expected": True})
        print(f"{case}/{adapter}/{name}: {result['status']}/{result['code']}", flush=True)
        return result

    call([args.wolframscript, "-file", package / "tests" / "PrepareCases.wls", package, work], "prepare")
    for chart in ("base", "alternate"):
        for adapter in ("blade", "fire7", "neatibp"):
            for name, output in (("DISCOVER", "discover"), ("REDUCE_IBP", "reduce"), ("BUILD_CUT_DE", "de")):
                result = step(chart, adapter, name, adapter + "-" + output)
                assert result["summary"]["mode"] == "import"
                assert not result["summary"]["driver_executed"]
    negatives = [
        ("missing-target", "fire7", "REDUCE_IBP", "MISSING_TARGETS"),
        ("unresolved", "fire7", "REDUCE_IBP", "UNRESOLVED_NATIVE_RULES"),
        ("wrong-family", "fire7", "REDUCE_IBP", "NATIVE_FAMILY_MISMATCH"),
        ("wrong-head", "fire7", "REDUCE_IBP", "INVALID_TARGETS"),
        ("wrong-order", "fire7", "REDUCE_IBP", "MASTER_ORDER_MISMATCH"),
        ("equations", "neatibp", "REDUCE_IBP", "UNSOLVED_NATIVE_EXPORT"),
        ("finite-field", "fire7", "REDUCE_IBP", "UNSUPPORTED_COEFFICIENT_DOMAIN"),
        ("inexact", "fire7", "REDUCE_IBP", "UNRESOLVED_NATIVE_RULES"),
        ("master-relation", "fire7", "REDUCE_IBP", "NATIVE_MASTER_RELATION"),
        ("binding", "fire7", "REDUCE_IBP", "FAMILY_BINDING_MISMATCH"),
        ("de-incomplete", "blade", "BUILD_CUT_DE", "INCOMPLETE_NATIVE_DE"),
        ("de-variable", "blade", "BUILD_CUT_DE", "INCOMPLETE_NATIVE_DE"),
        ("de-point", "blade", "BUILD_CUT_DE", "POINT_ONLY_DE_EXPORT"),
        ("de-finite-field", "fire7", "BUILD_CUT_DE", "INVALID_NATIVE_DE"),
        ("no-conversion", "blade", "REDUCE_IBP", "NATIVE_BASIS_MISMATCH"),
        ("no-conversion", "blade", "BUILD_CUT_DE", "NATIVE_BASIS_MISMATCH"),
        ("unsupported", "fire7", "REDUCE_IBP", "UNSUPPORTED_NATIVE_OPERATION"),
        ("backend-mismatch", "fire7", "REDUCE_IBP", "INVALID_NATIVE_BACKEND"),
    ]
    for case, adapter, name, code in negatives:
        step(case, adapter, name, name.lower(), ("ERROR", code))
    step("legacy-point", "fire7", "REDUCE_IBP", "reduce")
    step("conversion", "blade", "REDUCE_IBP", "blade-reduce")
    step("conversion", "blade", "BUILD_CUT_DE", "blade-de")
    step("dimension-rule", "blade", "BUILD_CUT_DE", "blade-de")

    # Test a caller-controlled operator program, explicitly labelled as synthetic, plus useful native input drivers.
    for adapter in ("blade", "fire7", "neatibp"):
        cfg_path = work / "driver" / adapter / "backend.json"
        cfg = json.loads(cfg_path.read_text())
        cfg["fixture_exports"] = {}
        for name, op in cfg["operations"].items():
            cfg["fixture_exports"][name] = {Path(value).name: value for value in op["exports"].values()}
            op.update(mode="command", argv=["{python}", str(package / "tests" / "SyntheticDriver.py"), "{context}"])
        if adapter in ("fire7", "neatibp"):
            cfg["test_prepare_driver"] = True
        if adapter == "neatibp":
            cfg.update(generic_point="{x -> 2, y -> 3}", generic_dimension="{d -> 7/3}", native_config="test-native-config.txt")
            (cfg_path.parent / "test-native-config.txt").write_text('(* Synthetic input preparation only; no native executable configured. *)\nOutputName="fixture";\n')
        cfg_path.write_text(json.dumps(cfg, indent=2) + "\n")
        result = step("driver", adapter, "REDUCE_IBP", adapter + "-reduce")
        assert result["summary"]["driver_executed"] and not result["summary"]["new_reduction_executed"]
    call([args.wolframscript, "-file", package / "tests" / "VerifyArtifacts.wls", work], "independent-readback")
    facts = json.loads((work / "artifact-checks.json").read_text())
    assert all(facts.values()), facts

    # The runner, not a parameterization/native package, selects each phase.
    mixed = work / "mixed-components.json"
    mixed.write_text(json.dumps({"schema": "canon-neu/components/v1", "steps": {
        "DISCOVER": {"from": str(reducers / "neatibp" / "components.json")},
        "REDUCE_IBP": {"from": str(reducers / "fire7" / "components.json")},
        "BUILD_CUT_DE": {"from": str(reducers / "blade" / "components.json")}}}, indent=2))
    for adapter, name, output in (("neatibp", "DISCOVER", "mixed-discover"), ("fire7", "REDUCE_IBP", "mixed-reduce"), ("blade", "BUILD_CUT_DE", "mixed-de")):
        step("base", adapter, name, output, manifest=mixed)
    relocated = work / "relocated"
    shutil.copytree(reducers, relocated / "reducers")
    shutil.copytree(work / "base", relocated / "case")
    step("relocated/case", "fire7", "REDUCE_IBP", "relocated-reduce", manifest=relocated / "reducers" / "fire7" / "components.json")
    step("relocated/case", "blade", "BUILD_CUT_DE", "relocated-de", manifest=relocated / "reducers" / "blade" / "components.json")
    for source in reducers.rglob("*.py"):
        ast.parse(source.read_text(), filename=str(source))
    receipt = {"all_expected": True, "scientific_step_expectations": len(results), "artifact_facts": facts, "cases": results,
               "kernel_concurrency": 1, "native_reducer_campaigns": 0, "native_end_to_end_validated": False,
               "scope": "native-format import, explicit driver boundary, native input preparation and exact output readback on synthetic fixtures",
               "runtime": json.loads((work / "runtime.json").read_text())}
    (work / "test-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(f"PASS: {len(results)} step expectations and {len(facts)} exact artifact facts", flush=True)


if __name__ == "__main__":
    main()
