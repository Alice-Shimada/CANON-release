#!/usr/bin/env python3
"""Run the default scalar-bubble binder chain once across a real tree relocation.

The input manifest supplies paths and SHA256 values for four analytic fixture
files. Paths resolve from that manifest. No native reducer is run. Only the
PREPARE/DISCOVER/BUILD_CUT_DE defaults and one legacy DISCOVER subcase execute.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time


SPEC = '''<|"schema" -> "canon-neu/family-spec/v1",
  "family_ref" -> "scalar-bubble", "basis_ref" -> "scalar-bubble-master",
  "topology" -> "scalar_bubble", "integral_head" -> "Q",
  "parameters" -> {d,u}, "variables" -> {u}, "regulator" -> eps,
  "dimension_rule" -> (d -> 4 - 2 eps), "index_order" -> {"D1","D2"},
  "propagator_slots" -> {1,2},
  "sector_convention" -> "Sector = Sum[Boole[a_i > 0] 2^(i-1), {i,1,2}]",
  "family_data" -> "scalar-spec.wl",
  "prepared_derivatives" -> "scalar-derivatives.wl",
  "ordered_masters" -> "scalar-masters"|>
'''
FIXTURE_NAMES = {
    "family_data": "scalar-spec.wl", "prepared_derivatives": "scalar-derivatives.wl",
    "ordered_masters": "scalar-masters", "ibp_reduction": "scalar-reduction.wl"}
SOURCE_FILES = ["run_step.py", "components/default.json", "mma/PrepareFamily.wls",
                "mma/DiscoverSectors.wls", "mma/BuildSectorCutDE.wls",
                "mma/lib/MethodCardCore.wl", "mma/lib/DEBuilder.wl", "mma/lib/SectorDE.wl",
                "mma/lib/IBPReductionAudit.wl",
                *["mma/lib/method-card/" + name + ".wl" for name in (
                    "ArtifactIO", "Contracts", "PreparedBasis", "Sectors", "GaugeChecks",
                    "DLogAlgebra", "StructuredRepair")]]


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def wait_for_process_groups(commands):
    """Allow runtime child cleanup to finish after the script process exits."""
    if os.name != "posix":
        return None
    deadline = time.monotonic() + 5
    while True:
        absent = {}
        for command in commands:
            pid = command["process_id"]
            try:
                os.killpg(pid, 0)
                absent[str(pid)] = False
            except ProcessLookupError:
                absent[str(pid)] = True
        if all(absent.values()) or time.monotonic() >= deadline:
            return absent
        time.sleep(0.1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--canon", type=Path, required=True)
    parser.add_argument("--inputs", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--wolframscript", default=os.environ.get("CANON_WOLFRAMSCRIPT", "wolframscript"))
    args = parser.parse_args()
    canon, inputs, output = args.canon.resolve(), args.inputs.resolve(), args.output.resolve()
    runtime = shutil.which(args.wolframscript)
    if not runtime:
        raise RuntimeError("Configured wolframscript is unavailable")
    output.mkdir(parents=True, exist_ok=False)
    tree = output / "original tree with spaces"
    supplied = tree / "supplied data"
    supplied.mkdir(parents=True)
    input_manifest = json.loads(inputs.read_text(encoding="utf-8"))
    dependency_inputs = {}
    for key, name in FIXTURE_NAMES.items():
        item = input_manifest[key]
        source = (inputs.parent / item["path"]).resolve()
        digest = sha256(source)
        assert digest == item["sha256"], (key, digest)
        shutil.copyfile(source, supplied / name)
        dependency_inputs[key] = {**item, "resolved_path": str(source), "copied_bytes_unchanged": True}
    (supplied / "family-spec.wl").write_text(SPEC, encoding="utf-8")
    initial_source_hashes = {name: sha256(canon / name) for name in SOURCE_FILES}
    environment = dict(os.environ, CANON_WOLFRAMSCRIPT=runtime, PYTHONDONTWRITEBYTECODE="1")
    commands, bindings, step_results = [], [], []

    def call(command, logfile):
        # Each child is awaited before another can be started. No detached mode.
        process = subprocess.Popen(command, cwd=tree, env=environment, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True,
                                   start_new_session=(os.name == "posix"))
        try:
            stdout, _ = process.communicate(timeout=120)
        except subprocess.TimeoutExpired:
            if os.name == "posix":
                import signal
                os.killpg(process.pid, signal.SIGKILL)
            else:
                process.kill()
            stdout, _ = process.communicate()
            logfile.write_text(stdout, encoding="utf-8")
            raise
        logfile.write_text(stdout, encoding="utf-8")
        group_absent = None
        if os.name == "posix":
            try:
                os.killpg(process.pid, 0)
                group_absent = False
            except ProcessLookupError:
                group_absent = True
        commands.append({"argv": command, "process_id": process.pid,
                         "returncode": process.returncode, "process_group_absent_after_wait": group_absent})
        assert process.returncode == 0, stdout
        return stdout

    def request(name, step, payload, sector=None):
        path = tree / name
        write_json(path, {"schema": "canon-neu/script-input/v1", "task_id": "DEFAULT-BINDER-REGRESSION",
                          "step": step, "sector": sector, "payload": payload})
        return path

    def descriptor(path):
        return {"type": "mathematica-expression", "path": path}

    def run(path, destination, expected_code):
        command = [sys.executable, str(canon / "run_step.py"), str(path), str(destination), "--defaults"]
        description = subprocess.run(command + ["--describe"], cwd=tree, env=environment,
                                     capture_output=True, text=True, check=True)
        binding = json.loads(description.stdout)
        assert binding["components"] == [] and binding["workflows"] == []
        assert Path(binding["manifest"]) == canon / "components/default.json"
        bindings.append(binding)
        call(command, output / (path.stem + ".log"))
        result = json.loads((destination / "result.json").read_text(encoding="utf-8"))
        assert result["status"] == "PASS" and result["code"] == expected_code, result
        step_results.append(result)
        return {key: descriptor(os.path.relpath(destination / value["path"], tree))
                for key, value in result["artifacts"].items()}

    prepare_request = request("prepare.json", "PREPARE", {"family_spec": descriptor("supplied data/family-spec.wl")})
    prepared = run(prepare_request, tree / "prepared outputs", "OK")
    before_move = {str(path.relative_to(tree)): sha256(path) for path in tree.rglob("*") if path.is_file()}
    original = tree
    tree = output / "relocated tree with spaces"
    shutil.move(str(original), str(tree))
    assert not original.exists()
    assert all(sha256(tree / name) == digest for name, digest in before_move.items())

    discover_request = request("discover.json", "DISCOVER", prepared)
    discovered = run(discover_request, tree / "discovered outputs", "SECTORS_READY")
    build_request = request("build.json", "BUILD_CUT_DE", {
        **prepared, **discovered, "ibp_reduction": descriptor("supplied data/scalar-reduction.wl")},
        {"id": 3, "propagator_count": 2})
    run(build_request, tree / "built outputs", "OK")

    # A tiny legacy subcase removes only the explicit head from the actual
    # prepared artifact. Keeping it beside that artifact preserves path bases.
    legacy_path = tree / "prepared outputs/legacy-prepared-family.wl"
    legacy_path.write_text('KeyDrop[Get[FileNameJoin[{DirectoryName[$InputFileName], "prepared-family.wl"}]], {"integral_head"}]\n', encoding="utf-8")
    legacy_request = request("legacy-discover.json", "DISCOVER", {
        "prepared_family": descriptor("prepared outputs/legacy-prepared-family.wl")})
    run(legacy_request, tree / "legacy discovered outputs", "SECTORS_READY")

    checker = Path(__file__).resolve().with_name("DefaultBinderChecks.wls")
    receipt = output / "exact-checks.json"
    call([runtime, "-file", str(checker), str(canon), str(tree), str(receipt)], output / "exact-checks.log")
    checks = json.loads(receipt.read_text(encoding="utf-8"))
    assert checks["all_pass"] is True and all(checks["checks"].values())
    assert {name: sha256(canon / name) for name in SOURCE_FILES} == initial_source_hashes
    assert all(sha256(tree / "supplied data" / name) == input_manifest[key]["sha256"]
               for key, name in FIXTURE_NAMES.items())
    generated_files = {str(path.relative_to(tree)): sha256(path) for path in tree.rglob("*") if path.is_file()}
    assert not any(Path(name).suffix in {".yaml", ".yml"} for name in generated_files)
    final_process_groups = wait_for_process_groups(commands)
    if final_process_groups is not None:
        assert all(final_process_groups.values()), final_process_groups
    evidence = {
        "schema": "canon-neu/default-binder-regression/v1", "all_pass": True,
        "scope": "Default typed scalar-bubble binding and relocated supplied-data DE construction, plus legacy discovery symbol context; no global canonical certificate",
        "dependency_inputs": dependency_inputs, "source_hashes": initial_source_hashes,
        "test_source_hashes": {Path(__file__).name: sha256(Path(__file__)), checker.name: sha256(checker)},
        "component_selection": ["--defaults"], "selected_bindings": bindings,
        "relocation": {"old_location": str(original), "new_location": str(tree),
                       "old_location_absent": not original.exists(), "all_moved_bytes_unchanged": True},
        "step_results": step_results, "exact_checks": checks, "commands": commands,
        "final_process_groups_absent": final_process_groups,
        "generated_file_hashes": generated_files,
        "scientific_step_count": len(step_results), "maximum_concurrent_kernels": 1,
        "native_reducer_invocations": 0, "detached_jobs": 0, "source_files_unchanged_during_run": True}
    write_json(output / "evidence.json", evidence)
    print(json.dumps({"all_pass": True, "exact_checks": len(checks["checks"]),
                      "scientific_steps": len(step_results), "evidence": str(output / "evidence.json")}, indent=2))


if __name__ == "__main__":
    main()
