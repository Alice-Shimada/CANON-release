#!/usr/bin/env python3
"""Neutral native-format import gates; no Kira or family calculation is run."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--canon", required=True, type=Path)
    parser.add_argument("--work", required=True, type=Path)
    parser.add_argument("--candidate", required=True, type=Path)
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--components", type=Path, action="append", default=[])
    args = parser.parse_args()
    canon, work = args.canon.resolve(), args.work.resolve()
    work.mkdir(parents=True, exist_ok=False)
    runtime = os.environ.get("CANON_WOLFRAMSCRIPT") or shutil.which("wolframscript")
    if not runtime:
        raise RuntimeError("configure CANON_WOLFRAMSCRIPT or wolframscript on PATH")
    environment = dict(os.environ, OMP_NUM_THREADS="1", OPENBLAS_NUM_THREADS="1", MKL_NUM_THREADS="1",
                       PYTHONDONTWRITEBYTECODE="1", CANON_WOLFRAMSCRIPT=runtime)
    family = {"schema": "canon-neu/reducer-family/v1", "family_ref": "neutral-import",
              "basis_ref": "neutral-source", "topology": "neutral_native", "integral_head": "B",
              "index_order": ["D1", "D2"], "point": [], "variables": ["x", "y"],
              "invariants": [{"name": "x", "mass_dimension": 2}, {"name": "y", "mass_dimension": 2}],
              "dimension": "d"}
    rhs = "((d+x)^2+y)/(1+x+x^2+y^2) neutral_native[1,1] + (x-y)/(1+2*x+x^2+2*y^2) neutral_native[1,2]"
    cases = [
        ("linear", rhs, "IBP_REDUCED"),
        ("zero", "0", "IBP_REDUCED"),
        ("unknown-integral", "neutral_native[9,9]", "UNREDUCED_NATIVE_OUTPUT"),
        ("nonlinear", "neutral_native[1,1] neutral_native[1,2]", "NATIVE_RULES_NOT_LINEAR"),
        ("square", "neutral_native[1,1]^2", "NATIVE_RULES_NOT_LINEAR"),
        ("integral-function", "Sin[neutral_native[1,1]]", "NATIVE_RULES_NOT_LINEAR"),
        ("fractional-power", "Sqrt[neutral_native[1,1]]", "NATIVE_RULES_NOT_LINEAR"),
        ("cancelled-polynomial", "(neutral_native[1,1]+neutral_native[1,2])^2-neutral_native[1,1]^2-neutral_native[1,2]^2-2 neutral_native[1,1] neutral_native[1,2] + " + rhs, "IBP_REDUCED"),
        ("cancelled-scalar", "((x+y)^2-x^2-y^2-2 x y) + " + rhs, "IBP_REDUCED"),
        ("cancelled-coefficient", "((x+y)^2-x^2-y^2-2 x y) neutral_native[1,1]^2 + " + rhs, "IBP_REDUCED"),
        ("master-denominator", "neutral_native[1,1]/(1+neutral_native[1,2])", "NATIVE_RULES_NOT_LINEAR"),
        ("constant-term", rhs + " + x/(1+y)", "NATIVE_RULES_NOT_LINEAR"),
        ("undeclared-symbol", "rogue neutral_native[1,1]", "UNDECLARED_NATIVE_COEFFICIENT"),
        ("machine-coefficient", "1.0 neutral_native[1,1]", "INVALID_NATIVE_COEFFICIENT_DOMAIN"),
        ("transcendental-coefficient", "Sin[x] neutral_native[1,1]", "INVALID_NATIVE_COEFFICIENT_DOMAIN"),
        ("algebraic-coefficient", "Sqrt[x] neutral_native[1,1]", "INVALID_NATIVE_COEFFICIENT_DOMAIN"),
        ("source-changed", rhs, "SOURCE_BASIS_CHANGED"),
        ("basis-changed", rhs, "NATIVE_BASIS_MISMATCH"),
        ("unused-source", "(d+x)/(1+y) neutral_native[1,1]", "IBP_REDUCED"),
        ("omitted-used-source", rhs, "UNREDUCED_NATIVE_OUTPUT"),
        ("unused-source-changed", "(d+x)/(1+y) neutral_native[1,1]", "SOURCE_BASIS_CHANGED"),
        ("duplicate-target", rhs, "INVALID_NATIVE_RULE_TARGETS"),
        ("dimension-expression", rhs, "IBP_REDUCED"),
        ("dimension-undeclared", "rogue neutral_native[1,1]", "UNDECLARED_NATIVE_COEFFICIENT"),
    ]
    variants = [("candidate", args.candidate.resolve())]
    if args.baseline:
        variants.insert(0, ("baseline", args.baseline.resolve()))
    records, hashes = [], {}
    for variant, interop in variants:
        hashes[variant] = {"path": str(interop), "sha256": hashlib.sha256(interop.read_bytes()).hexdigest()}
        override = work / variant / "components.json"
        write(override, {"schema": "canon-neu/components/v1", "steps": {"REDUCE_IBP": {
            "command": [runtime, "-file", str(interop), str(canon), "import"],
            "instructions": str(canon / "components/reducers/kira/README.md")}}})
        for name, expression, expected in cases:
            case = work / variant / name
            output = case / "output"
            output.mkdir(parents=True)
            f = dict(family)
            if name.startswith("dimension-"):
                f["dimension"] = "4-2*ep"
                if variant == "baseline" and name == "dimension-expression":
                    expected = "UNDECLARED_NATIVE_COEFFICIENT"
            write(case / "family.json", f)
            write(output / "interop.json", {"native_masters": "masters", "native_rules": "rules.m"})
            master_text = "neutral_native[1,2]\nneutral_native[1,1]\n"
            if name == "basis-changed":
                master_text = master_text.replace("[1,1]", "[0,1]")
            if name in ("unused-source", "omitted-used-source", "unused-source-changed"):
                master_text = "neutral_native[1,1]\n"
                if variant == "baseline":
                    expected = "NATIVE_BASIS_MISMATCH"
            (output / "masters").write_text(master_text)
            rules = ["neutral_native[2,1] -> " + expression]
            if name == "source-changed":
                rules.append("neutral_native[1,1] -> 2 neutral_native[1,1]")
            if name == "unused-source-changed":
                rules.append("neutral_native[1,2] -> 2 neutral_native[1,2]")
            if name == "duplicate-target":
                rules.append(rules[0])
            (output / "rules.m").write_text("{" + ",".join(rules) + "}\n")
            (output / "request-data.wl").write_text('<|"targets"->{B[2,1]},"masters"->{B[1,1],B[1,2]},"point"->{}|>\n')
            (output / "reduction-kinematics.wl").write_text('<|"schema"->"canon-neu/reduction-kinematics/v1","family_id"->"neutral-import","variables"->{x,y},"point"->{}|>\n')
            request = case / "request.json"
            write(request, {"schema": "canon-neu/script-input/v1", "task_id": "NEUTRAL-" + name,
                            "step": "REDUCE_IBP", "sector": None,
                            "payload": {"reducer_family": {"path": "family.json"}}})
            command = [sys.executable, str(canon / "run_step.py"), str(request), str(output)]
            for manifest in args.components or [canon / "components/profiles/custom-kira.json"]:
                command += ["--components", str(manifest.resolve())]
            command += ["--components", str(override)]
            if name == "linear":
                described = subprocess.run(command + ["--describe"], capture_output=True, text=True, check=True, env=environment)
                (case / "describe.json").write_text(described.stdout)
            started = time.monotonic()
            completed = subprocess.run(command, capture_output=True, text=True, timeout=30, env=environment)
            elapsed = time.monotonic() - started
            (case / "driver.log").write_text(completed.stdout + completed.stderr)
            result = json.loads((output / "result.json").read_text())
            assert result["code"] == expected, (variant, name, result)
            assert (completed.returncode == 0) == (expected == "IBP_REDUCED"), (name, completed.returncode)
            if name == "unused-source" and expected == "IBP_REDUCED":
                assert result["summary"]["masters"] == 2 and result["summary"]["native_master_count"] == 1
            records.append({"variant": variant, "case": name, "code": result["code"], "seconds": elapsed})
            print(variant, name, result["code"], flush=True)
    check = work / "exact-check.wls"
    check.write_text('''$HistoryLength=0;
{base,out}=Rest[$ScriptCommandLine];
red=Get[FileNameJoin[{base,"candidate","linear","output","ibp-reduction.wl"}]];
expected=((d+x)^2+y)/(1+x+x^2+y^2) B[1,1]+(x-y)/(1+2 x+x^2+2 y^2) B[1,2];
dim=Get[FileNameJoin[{base,"candidate","dimension-expression","output","ibp-reduction.wl"}]];
subset=Get[FileNameJoin[{base,"candidate","unused-source","output","ibp-reduction.wl"}]];
facts=<|"exact_rule"->(Together[(B[2,1]/.red["rules"])-expected]===0),
"source_order"->(red["masters"]==={B[1,1],B[1,2]}),
"outgoing_keys"->(Sort[Keys[red]]===Sort[{"masters","rules"}]),
"unused_source_retained"->(subset["masters"]==={B[1,1],B[1,2]} &&
 Together[(B[2,1]/.subset["rules"])-(d+x)/(1+y) B[1,1]]===0),
"dimension_expression"->(Together[(B[2,1]/.dim["rules"])-(expected/.d->4-2 ep)]===0)|>;
If[FileExistsQ[FileNameJoin[{base,"baseline","linear","output","ibp-reduction.wl"}]],
old=Get[FileNameJoin[{base,"baseline","linear","output","ibp-reduction.wl"}]];
AssociateTo[facts,"baseline_exact_equality"->(Together[(B[2,1]/.old["rules"])-(B[2,1]/.red["rules"])]===0)]];
Export[out,facts,"RawJSON"];Exit[If[AllTrue[Values[facts],TrueQ],0,1]];
''')
    checked = subprocess.run([runtime, "-file", str(check), str(work), str(work / "exact.json")],
                             capture_output=True, text=True, timeout=30, env=environment)
    (work / "exact.log").write_text(checked.stdout + checked.stderr)
    exact = json.loads((work / "exact.json").read_text())
    assert checked.returncode == 0 and all(exact.values()), exact
    write(work / "evidence.json", {"all_expected": True, "cases": records, "exact": exact,
          "sources": hashes, "kernel_concurrency": 1, "native_execution": False,
          "scope": "neutral import-only public dispatch; no native reduction or scientific family result"})


if __name__ == "__main__":
    main()
