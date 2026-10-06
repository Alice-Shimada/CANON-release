#!/usr/bin/env python3
"""Check the scalar-symbol domain fix and two native import boundary cases."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, required=True)
    parser.add_argument("--staged-root", type=Path, required=True)
    parser.add_argument("--baseline-entry", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    project, staged, baseline, output = (p.resolve() for p in
        (args.project_root, args.staged_root, args.baseline_entry, args.output))
    output.mkdir(parents=True)
    runtime = shutil.which(os.environ.get("CANON_WOLFRAMSCRIPT", "wolframscript"))
    if runtime is None:
        parser.error("configured Wolfram script executable is unavailable")
    environment = dict(os.environ, CANON_WOLFRAMSCRIPT=runtime, OMP_NUM_THREADS="1",
                       OPENBLAS_NUM_THREADS="1", MKL_NUM_THREADS="1", PYTHONDONTWRITEBYTECODE="1")

    def write(path, data):
        path.write_text(json.dumps(data, indent=2) + "\n")

    def run(command, name):
        done = subprocess.run(command, cwd=output, env=environment, text=True,
                              capture_output=True, timeout=60)
        (output / (name + ".log")).write_text(done.stdout + done.stderr)
        assert done.returncode == 0, (command, done.stdout, done.stderr)
        return done

    scalar_script = output / "scalar-cases.wls"
    scalar_script.write_text('''{entry, result} = Rest[$ScriptCommandLine]; Get[entry];
values = <|"undeclared_z" -> CanonMethodCard`DeclaredCoefficientDomainQ[z, {x, eps}],
  "declared_x" -> CanonMethodCard`DeclaredCoefficientDomainQ[x, {x, eps}],
  "declared_eps" -> CanonMethodCard`DeclaredCoefficientDomainQ[eps, {x, eps}],
  "zero" -> CanonMethodCard`DeclaredCoefficientDomainQ[0, {x, eps}],
  "integer" -> CanonMethodCard`DeclaredCoefficientDomainQ[2, {x, eps}],
  "rational" -> CanonMethodCard`DeclaredCoefficientDomainQ[-3/7, {x, eps}],
  "undeclared_quotient" -> CanonMethodCard`DeclaredCoefficientDomainQ[z/x, {x, eps}]|>;
Export[result, values, "RawJSON"];
''')
    for name, entry in (("before", baseline), ("after", staged / "mma/lib/MethodCardCore.wl")):
        run([runtime, "-file", str(scalar_script), str(entry), str(output / (name + ".json"))], name)
    before, after = (json.loads((output / (name + ".json")).read_text()) for name in ("before", "after"))
    assert before == {**after, "undeclared_z": True}
    assert after == {"undeclared_z": False, "declared_x": True, "declared_eps": True,
                     "zero": True, "integer": True, "rational": True, "undeclared_quotient": False}

    # Bind the staged core while the installed native adapter remains referenced in place.
    tree = output / "core fixture tree"
    (tree / "components").mkdir(parents=True)
    (tree / "mma/lib").mkdir(parents=True)
    shutil.copyfile(project / "run_step.py", tree / "run_step.py")
    (tree / "components/default.json").symlink_to(project / "components/default.json")
    (tree / "mma/lib/MethodCardCore.wl").symlink_to(staged / "mma/lib/MethodCardCore.wl")
    (tree / "mma/lib/method-card").symlink_to(staged / "mma/lib/method-card")
    manifest = project / "components/reducers/blade/components.json"
    family = {"schema": "canon-neu/reducer-family/v1", "family_ref": "scalar-domain",
              "basis_ref": "scalar-domain-basis", "topology": "scalar_domain", "integral_head": "J",
              "index_order": ["D1", "D2"], "propagator_slots": [1, 2], "variables": ["x"],
              "dimension": "d", "regulator": "eps", "dimension_rule": "d -> 4-2 eps", "point": []}
    backend = {"schema": "canon-neu/native-backend/v1", "adapter": "blade",
               "encoding": {"head": "Blade`BL", "layout": "family-list", "family": "box"},
               "masters_format": "integrals", "binding": {"family_ref": "scalar-domain",
                   "basis_ref": "scalar-domain-basis", "index_order": ["D1", "D2"],
                   "coefficient_domain": "exact-rational-functions", "point": []},
               "operations": {"REDUCE_IBP": {"mode": "import", "source_format": "blade-rules",
                   "exports": {"masters": "native-masters.wl", "rules": "native-rules.wl"}}}}
    native_records = []
    for name, parameters, expected in (("undeclared", [], ("ERROR", "UNRESOLVED_NATIVE_RULES")),
                                       ("declared-parameter", ["z"], ("PASS", "IBP_REDUCED"))):
        directory = output / name
        directory.mkdir()
        write(directory / "family.json", {**family, "parameters": parameters})
        write(directory / "backend.json", backend)
        (directory / "targets.wl").write_text('<|"schema"->"canon-neu/reduction-targets/v1",'
            '"family_ref"->"scalar-domain","basis_ref"->"scalar-domain-basis",'
            '"targets"->{J[2,1]},"masters"->{J[1,1]},"point"->{}|>\n')
        (directory / "native-masters.wl").write_text('{Blade`BL[box,{1,1}]}\n')
        (directory / "native-rules.wl").write_text('{Blade`BL[box,{2,1}]->z Blade`BL[box,{1,1}]}\n')
        write(directory / "request.json", {"schema": "canon-neu/script-input/v1", "task_id": name,
              "step": "REDUCE_IBP", "payload": {"reducer_family": {"path": "family.json"},
                  "backend": {"path": "backend.json"}, "reduction_targets": {"path": "targets.wl"}}})
        command = [sys.executable, str(tree / "run_step.py"), str(directory / "request.json"),
                   str(directory / "out"), "--components", str(manifest)]
        if not native_records:
            description = json.loads(run(command + ["--describe"], "native-describe").stdout)
            assert description["components"] == [str(manifest)]
            assert description["instructions"] == str(project / "components/reducers/blade/README.md")
        run(command, "native-" + name)
        result = json.loads((directory / "out/result.json").read_text())
        assert (result["status"], result["code"]) == expected, result
        if name == "declared-parameter":
            assert result["summary"]["new_reduction_executed"] is False
        native_records.append({"case": name, "parameters": parameters, "command": command, "result": result})
    readback = output / "readback.wls"
    readback.write_text('r=Get[First[Rest[$ScriptCommandLine]]]; '
                       'Quit[If[r["masters"]==={J[1,1]} && r["rules"]==={J[2,1]->z J[1,1]},0,1]];\n')
    run([runtime, "-file", str(readback), str(output / "declared-parameter/out/ibp-reduction.wl")], "native-readback")
    hash_file = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    evidence = {"pass": True, "intentional_behavior_change": "reject an undeclared level-zero coefficient symbol",
                "before": before, "after": after, "native_cases": native_records,
                "declared_parameter_rule_exact_readback": True, "kernel_concurrency": 1,
                "native_campaigns": 0, "native_execution_mode": "import of synthetic solved rules",
                "components": [str(manifest)], "description": description,
                "baseline_entry_sha256": hash_file(baseline),
                "fixed_contracts_sha256": hash_file(staged / "mma/lib/method-card/Contracts.wl"),
                "installed_native_sources": {str(p.relative_to(project)): hash_file(p) for p in
                    [project / "components/reducers/native-adapter/NativeAdapter.wl",
                     project / "components/reducers/native-adapter/run.py",
                     *sorted((project / "components/reducers/native-adapter/lib").glob("*.wl"))]}}
    write(output / "scalar-domain-fix.json", evidence)
    print("PASS: seven before/after scalar cases, two public native imports, and exact declared-parameter readback")


if __name__ == "__main__":
    main()
