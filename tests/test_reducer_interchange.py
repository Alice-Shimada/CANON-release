#!/usr/bin/env python3
"""Exercise fixed scalar recipes through named interfaces, then one tiny FINAL_CHECK.

All scientific requests in the scalar chain are bound from checked-in JSON.
The discovery executable and exact readback below are test scaffolding only.
No native scientific engine runs; kernels execute serially.
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


SOURCE_FILES = [
    "run_step.py", "components/default.json", "mma/lib/PhysicalDerivative.wl",
    "components/profiles/mixed-reducers.json",
    "mma/BuildSectorCutDE.wls", "mma/lib/MethodCardCore.wl",
    "mma/lib/DEBuilder.wl", "mma/lib/CandidateIBPBridge.wl",
    "skills/canon-build-cut-de/SKILL.md",
    *["components/parameterization/" + name for name in (
        "Prepare.wls", "Parameterization.wl", "components.json", "README.md",
        "WORKFLOW.md", "examples/scalar-spec.wl", "examples/scalar-derivatives.wl",
        "examples/scalar-masters")],
    *["components/reducers/kira/" + name for name in (
        "run.py", "Interop.wls", "components.json", "README.md", "WORKFLOW.md")],
    *["components/reducers/native-adapter/" + name for name in (
        "run.py", "Normalize.wls", "NativeAdapter.wl", "README.md")],
    *["components/reducers/" + package + "/" + name
      for package, names in (
          ("fire7", ("components.json", "README.md", "native.py", "prepare.wls")),
          ("blade", ("components.json", "README.md", "native.wls")),
          ("neatibp", ("components.json", "README.md", "export.py", "prepare.wls")))
      for name in names],
]

SOURCE_FILES += [
    "prepare_request.py", "mma/PrepareReductionTargets.wls", "mma/SliceSectorCutDE.wls",
    "mma/CheckFullSystem.wls", "mma/lib/SectorDE.wl",
    "skills/canon-prepare-request/SKILL.md", "skills/canon-prepare-reduction-targets/SKILL.md",
    "skills/canon-final-check/SKILL.md",
    *["mma/lib/method-card/" + name + ".wl" for name in (
        "ArtifactIO", "Contracts", "PreparedBasis", "Sectors", "GaugeChecks", "DLogAlgebra", "StructuredRepair")],
    *["components/reducers/native-adapter/lib/" + name + ".wl" for name in (
        "Inputs", "Basis", "Discovery", "Reduction", "DifferentialEquations", "Normalization")],
    "tests/fixtures/final-check/ordered-master-de.wl",
    "tests/fixtures/final-check/accepted-prefix.wl",
]
RECIPE = Path("interfaces/examples/scalar-workflow")

DISCOVERY_FIXTURE = r'''
"""Synthetic Kira-format master initiation; no Kira installation is invoked."""
import json, os, sys
from pathlib import Path
assert sys.argv[1] == "--parallel=1"
job = Path(sys.argv[2])
family = Path("config/integralfamilies.yaml").read_text()
kinematics = Path("config/kinematics.yaml").read_text()
assert 'name: "scalar_bubble"' in family
assert 'loop_momenta: ["k"]' in family
assert '["k-q","0"]' in family.replace(" ", "")
assert '[["u", 2]]' in kinematics
assert '[["q", "q"], "u"]' in kinematics
assert 'run_initiate: masters' in job.read_text()
out = Path("results/scalar_bubble")
out.mkdir(parents=True)
(out / "masters").write_text("scalar_bubble[1,1] # analytic fixture master\n")
Path("fixture-invocation.json").write_text(json.dumps({
    "kind": "synthetic-native-format-discovery", "pid": os.getpid(),
    "new_native_reduction": False, "job": str(job), "threads": 1}))
'''

READBACK = r'''
$HistoryLength = 0;
{tree, recipe, receipt} = Rest[$ScriptCommandLine];
Get[FileNameJoin[{tree, "mma", "lib", "MethodCardCore.wl"}]];
load[stage_, key_] := Module[{result, path},
  path = FileNameJoin[{recipe, "outputs", stage, "result.json"}];
  result = Import[path, "RawJSON"];
  Get[CanonMethodCard`ResolveInputPath[path, result["artifacts", key, "path"]]]];
same[q_] := And @@ (Together[#] === 0 & /@ Flatten[Normal /@ q]);
family = load["prepare", "family_data"];
prepared = load["prepare", "prepared_family"];
neutral = Import[FileNameJoin[{recipe,"outputs","prepare","reducer-family.json"}],"RawJSON"];
masters = load["discover", "master_basis"];
sectors = load["discover", "sector_manifest"];
targets = load["targets", "reduction_targets"];
fire = load["fire", "ibp_reduction"];
neat = load["neat", "ibp_reduction"];
blade = load["blade", "ordered_master_de"];
generic = load["generic", "ordered_master_de"];
bladeCut = load["blade", "sector_cut_de"];
genericCut = load["generic", "sector_cut_de"];
sliced = load["slice", "sector_cut_de"];
slicedBasis = load["slice", "sector_basis"];
fireReceipt = load["fire", "normalization_receipt"];
neatReceipt = load["neat", "normalization_receipt"];
bladeReceipt = load["blade", "normalization_receipt"];
expected = {0, (3-d)/u Q[1,1]};
sourceOK[declaring_, descriptor_] := With[{
  path = CanonMethodCard`ResolveInputPath[declaring, descriptor["path"]]},
  FileExistsQ[path] && FileHash[path,"SHA256","HexString"] === descriptor["sha256"]];
preparedPath = FileNameJoin[{recipe,"outputs","prepare","prepared-family.wl"}];
familyPath = FileNameJoin[{recipe,"outputs","prepare","family-data.wl"}];
neutralPath = FileNameJoin[{recipe,"outputs","prepare","reducer-family.json"}];
facts = <|
  "parameterization_schema" -> (family["schema"] === "canon-neu/parameterized-family/v1" && neutral["schema"] === "canon-neu/reducer-family/v1"),
  "actual_scalar_identity" -> (family["family_ref"] === "scalar-bubble" && family["basis_ref"] === "scalar-bubble-master" && family["chart_id"] === "invariant-u"),
  "separate_native_and_scientific_names" -> (neutral["topology"] === "scalar_bubble" && neutral["integral_head"] === "Q"),
  "symbolic_chart_and_dimension" -> (family["chart_type"] === "scalar-products" && family["variables"] === {u} && family["dimension_rule"] === (d -> 4-2eps)),
  "neutral_no_backend_binding" -> (Intersection[Keys[neutral], {"backend","executable","seed","jobs","kira","threads","project"}] === {}),
  "relocated_prepared_sources" -> And @@ (sourceOK[preparedPath, prepared[#]] & /@ {"family_data","reducer_family","prepared_derivatives","ordered_masters"}),
  "relocated_family_spec" -> sourceOK[familyPath,family["sources","family_spec"]],
  "relocated_neutral_family_data" -> sourceOK[neutralPath,neutral["family_data"]],
  "kira_exact_global_head_and_order" -> (masters["masters"] === {Global`Q[1,1]} && masters["topology"] === "Q"),
  "kira_preserves_identity_and_indices" -> (masters["family_ref"] === neutral["family_ref"] && masters["basis_ref"] === neutral["basis_ref"] && masters["index_order"] === {"D1","D2"}),
  "actual_sector_manifest" -> (Lookup[sectors["sectors"],"id"] === {3} && sectors["propagator_slots"] === {1,2}),
  "derived_targets_and_source_order" -> (Sort[targets["targets"]] === Sort[{Q[0,2],Q[1,2]}] && targets["masters"] === masters["masters"]),
  "named_targets_identity_and_symbolic_scope" -> (targets["schema"] === "canon-neu/reduction-targets/v1" && targets["family_ref"] === neutral["family_ref"] && targets["basis_ref"] === neutral["basis_ref"] && targets["point"] === {}),
  "named_targets_exact_order" -> (targets["targets"] === {Q[0,2],Q[1,2]}),
  "sliced_matrices_unchanged" -> same[sliced["matrices"] - genericCut["matrices"]],
  "sliced_identity_and_order" -> (KeyDrop[sliced,"matrices"] === KeyDrop[genericCut,"matrices"] && slicedBasis === load["generic","sector_basis"]),
  "fire_preserves_source_order" -> (fire["masters"] === masters["masters"]),
  "fire_exact_analytic_rules" -> (And @@ (Together[#] === 0 & /@ (({Q[0,2],Q[1,2]} /. fire["rules"]) - expected))),
  "neat_preserves_source_order" -> (neat["masters"] === masters["masters"]),
  "neat_exact_same_rules" -> (And @@ (Together[#] === 0 & /@ ((targets["targets"] /. neat["rules"]) - (targets["targets"] /. fire["rules"])))),
  "de_source_identity_and_order" -> (blade["basis"] === masters["masters"] && generic["basis"] === masters["masters"] && blade["basis_id"] === neutral["basis_ref"] && generic["basis_id"] === neutral["basis_ref"] && blade["family_id"] === neutral["family_ref"] && generic["family_id"] === neutral["family_ref"]),
  "de_variable_and_regulator_order" -> (blade["variables"] === {u} && generic["variables"] === {u} && blade["regulator"] === eps && generic["regulator"] === eps),
  "de_dimension_removed" -> FreeQ[{blade["matrices"],generic["matrices"]}, d],
  "generic_expected_connection" -> same[generic["matrices"] - {{{-eps/u}}}],
  "blade_expected_connection" -> same[blade["matrices"] - {{{-eps/u}}}],
  "exact_de_agreement" -> same[blade["matrices"] - generic["matrices"]],
  "exact_cut_agreement" -> same[bladeCut["matrices"] - genericCut["matrices"]],
  "cut_order_and_sector" -> (bladeCut["basis"] === genericCut["basis"] === {Q[1,1]} && bladeCut["sector"] === genericCut["sector"] === <|"id"->3,"propagator_count"->2|> && bladeCut["proper_subsectors"] === genericCut["proper_subsectors"] === {}),
  "same_neutral_hash_across_adapters" -> (fireReceipt["sources","family","sha256"] === neatReceipt["sources","family","sha256"] === bladeReceipt["sources","family","sha256"] === FileHash[neutralPath,"SHA256","HexString"]),
  "no_new_reduction_claim" -> (fireReceipt["summary","new_reduction_executed"] === False && neatReceipt["summary","new_reduction_executed"] === False),
  "direct_de_scope_retained" -> (blade["validity","flat"] === Missing["not-checked"])
|>;
Export[receipt, <|"wolfram_version"->$Version, "facts"->facts,
  "connection"->ToString[Map[Together,Normal /@ generic["matrices"],{3}],InputForm],
  "source_basis"->ToString[masters["masters"],InputForm],
  "variables"->ToString[generic["variables"],InputForm],
  "all_pass"->AllTrue[Values[facts],TrueQ]|>, "RawJSON"];
Exit[If[AllTrue[Values[facts],TrueQ],0,1]];
'''


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--canon", required=True, type=Path)
    parser.add_argument("--work", required=True, type=Path)
    parser.add_argument("--recipe", type=Path, help="staged static recipe directory")
    parser.add_argument("--resume", action="store_true", help="retain matching completed test stages")
    args = parser.parse_args()
    canon, work = args.canon.resolve(), args.work.resolve()
    recipe_source = (args.recipe or Path(__file__).resolve().parents[1] / RECIPE).resolve()
    wolfram = shutil.which(os.environ.get("CANON_WOLFRAMSCRIPT", "wolframscript"))
    if wolfram is None:
        parser.error("set CANON_WOLFRAMSCRIPT or put installed wolframscript on PATH")
    work.mkdir(parents=True, exist_ok=args.resume)
    original, moved = work / "initial tree", work / "moved tree with spaces"
    tree = moved if args.resume and moved.exists() else original
    recipe = tree / RECIPE
    hashes = {}
    # Only checked-in source/data leaves enter this tree, never a prior workspace.
    files = [(canon / name, Path(name)) for name in SOURCE_FILES]
    files.append((recipe_source / "README.md", RECIPE / "README.md"))
    for directory, pattern in (("templates", "*.json"), ("bind", "*.json"),
                               ("profiles", "*.json"), ("backends", "*.json"), ("fixtures", "*.wl")):
        files += [(path, RECIPE / path.relative_to(recipe_source))
                  for path in sorted((recipe_source / directory).glob(pattern))]
    for source, relative in files:
        destination = tree / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        if not args.resume:
            shutil.copyfile(source, destination)
        hashes[str(relative)] = digest(source)
        assert digest(destination) == digest(source), str(relative)
    fixture_dir = tree / "test-fixtures"
    fixture_dir.mkdir(exist_ok=args.resume)
    (fixture_dir / "kira fixture.py").write_text(DISCOVERY_FIXTURE, encoding="utf-8")
    (fixture_dir / "readback.wls").write_text(READBACK, encoding="utf-8")
    write(recipe / "runtime/kira-backend.json", {
        "schema": "canon-neu/kira-backend/v1", "executable": sys.executable,
        "options": [os.path.relpath(fixture_dir / "kira fixture.py", recipe / "outputs/discover/kira"),
                    "--parallel=1"], "seed": {"r": 2, "s": 0, "d": 0},
        "timeout_seconds": 30, "cancel_grace_seconds": 1})
    environment = {**os.environ, "CANON_WOLFRAMSCRIPT": wolfram}
    logs = work / "logs"
    logs.mkdir(exist_ok=args.resume)
    records, binding_checks = [], []
    earlier = read(work / "progress.json") if args.resume else []

    def execute(command, log):
        started = time.monotonic()
        with log.open("w", encoding="utf-8") as stream:
            done = subprocess.run(command, cwd=tree, env=environment, stdin=subprocess.DEVNULL,
                                  stdout=stream, stderr=subprocess.STDOUT, timeout=180)
        return done.returncode, round(time.monotonic() - started, 6)

    def invoke(name, request, output, expected, profiles=(), defaults=False):
        previous = next((item for item in earlier if item["name"] == name), None)
        if previous and (previous["status"], previous["code"]) == expected:
            assert digest(request) == previous["request_sha256"], "resumed input changed"
            assert digest(output / "result.json") == previous["result_sha256"], "resumed result changed"
            assert expected[0] != "PASS" or previous["returncode"] == 0
            records.append(previous)
            print(name + ": retained matching result", flush=True)
            return read(output / "result.json")
        command = [sys.executable, str(tree / "run_step.py"), str(request), str(output)]
        if defaults:
            command.append("--defaults")
        else:
            for profile in profiles:
                command += ["--components", str(tree / profile)]
        description = subprocess.run([*command, "--describe"], cwd=tree, env=environment,
                                     capture_output=True, text=True, check=True)
        selected = json.loads(description.stdout)
        write(logs / (name + "-selection.json"), selected)
        for instructions in [selected["instructions"], *[x["instructions"] for x in selected["workflows"]]]:
            assert Path(instructions).is_file(), instructions
        code, seconds = execute(command, logs / (name + ".log"))
        result = read(output / "result.json")
        records.append({"name": name, "step": result["step"], "returncode": code,
            "status": result["status"], "code": result["code"], "expected": list(expected),
            "seconds": seconds, "request": str(request.relative_to(tree)),
            "result": str((output / "result.json").relative_to(tree)),
            "components": [{"path": str(p), "sha256": digest(tree / p)} for p in profiles],
            "defaults": defaults, "provider": os.path.relpath(selected["manifest"], tree),
            "interface": selected.get("interface"), "summary": result["summary"],
            "request_sha256": digest(request), "result_sha256": digest(output / "result.json")})
        write(work / "progress.json", records)
        assert (result["status"], result["code"]) == expected, (name, result)
        assert expected[0] != "PASS" or code == 0, (name, code)
        print(name + ": " + result["status"] + "/" + result["code"], flush=True)
        return result

    mixed = Path("components/profiles/mixed-reducers.json")
    generic = RECIPE / "profiles/generic.json"
    neat = RECIPE / "profiles/neat.json"

    def check_binding(name, request):
        template_path = recipe / "templates" / (name + ".json")
        template, bound = read(template_path), read(request)
        assert bound["step"] == template["step"] and bound["sector"] == template["sector"]
        checks = []
        for key, reference in template["payload"].items():
            origin = template_path
            if "from_result" in reference:
                origin = (template_path.parent / reference["from_result"]).resolve()
                reference = read(origin)["artifacts"][reference["artifact"]]
            actual = bound["payload"][key]
            expected_path = (origin.parent / reference["path"]).resolve()
            actual_path = (request.parent / actual["path"]).resolve()
            assert not Path(actual["path"]).is_absolute() and actual_path == expected_path
            assert actual_path.is_file()
            assert {k: v for k, v in actual.items() if k != "path"} == {
                k: v for k, v in reference.items() if k != "path"}
            if "sha256" in actual:
                assert actual["sha256"] == digest(actual_path)
            checks.append({"payload_key": key, "path": str(actual_path.relative_to(tree)),
                           "sha256": digest(actual_path), "relative_path_and_metadata_preserved": True})
        binding_checks.append({"stage": name, "template_sha256": digest(template_path),
                               "descriptors": checks})

    def recipe_step(name, expected, override=None):
        profiles = [mixed] + ([override] if override else [])
        binding_output = recipe / "bindings" / name
        result = invoke("bind-" + name, recipe / "bind" / (name + ".json"),
                        binding_output, ("PASS", "REQUEST_READY"), profiles)
        request = binding_output / result["artifacts"]["request"]["path"]
        check_binding(name, request)
        return invoke(name, request, recipe / "outputs" / name, expected, profiles)

    prepared = recipe_step("prepare", ("PASS", "PARAMETERIZATION_READY"))
    producer_hashes = {key: digest(recipe / "outputs/prepare" / value["path"])
                       for key, value in prepared["artifacts"].items()}
    if tree == original:
        write(work / "relocation.json", {"producer_hashes_before_move": producer_hashes,
                                        "source_sha256_before_move": hashes})
        tree.rename(moved)
        tree, recipe, fixture_dir = moved, moved / RECIPE, moved / "test-fixtures"
    assert not original.exists()
    assert producer_hashes == read(work / "relocation.json")["producer_hashes_before_move"]
    assert hashes == read(work / "relocation.json")["source_sha256_before_move"]
    assert all(digest(tree / path) == value for path, value in hashes.items())
    recipe_step("discover", ("PASS", "SECTORS_READY"))
    recipe_step("targets", ("PASS", "REDUCTION_TARGETS_READY"))
    recipe_step("fire", ("PASS", "IBP_REDUCED"))
    recipe_step("blade", ("PASS", "OK"))
    recipe_step("generic", ("PASS", "OK"), generic)
    recipe_step("slice", ("PASS", "OK"), generic)
    recipe_step("neat", ("PASS", "IBP_REDUCED"), neat)
    recipe_step("equations", ("ERROR", "UNSOLVED_NATIVE_EXPORT"), neat)
    rejected = recipe / "bindings/rejected-upstream"
    rejection = invoke("bind-rejected-upstream", recipe / "bind/rejected-upstream.json", rejected,
                       ("ERROR", "REQUEST_BINDING_FAILED"), [mixed, generic])
    assert rejection["artifacts"] == {} and not (rejected / "request.json").exists()
    exact_path = work / "exact-readback.json"
    code, _ = execute([wolfram, "-file", str(fixture_dir / "readback.wls"), str(tree),
                       str(recipe), str(exact_path)], logs / "readback.log")
    exact = read(exact_path)
    assert code == 0 and exact["all_pass"], exact

    # This is typed test metadata for the unchanged existing two-master fixture.
    final_dir = fixture_dir / "final-check"
    final_dir.mkdir(exist_ok=args.resume)
    metadata = {
        "prepared-family.wl": '<|"schema"->"canon-neu/prepared-family/v1", "family_ref"->"fixture-full-tail", "basis_ref"->"fixture/order", "variables"->{Global`x}, "regulator"->Global`eps|>\n',
        "master-basis.wl": '<|"schema"->"canon-neu/master-basis/v1", "family_ref"->"fixture-full-tail", "basis_ref"->"fixture/order", "masters"->{Global`l0,Global`j0}|>\n',
        "sector-manifest.wl": '<|"schema"->"canon-neu/sector-manifest/v1", "sectors"->{<|"id"->0,"propagator_count"->0|>,<|"id"->1,"propagator_count"->1|>}|>\n'}
    for filename, data in metadata.items():
        (final_dir / filename).write_text(data, encoding="utf-8")
    final_input = final_dir / "input.json"
    final_paths = {"prepared_family": final_dir / "prepared-family.wl",
                   "master_basis": final_dir / "master-basis.wl", "sector_manifest": final_dir / "sector-manifest.wl",
                   "ordered_master_de": tree / "tests/fixtures/final-check/ordered-master-de.wl",
                   "accepted_prefix": tree / "tests/fixtures/final-check/accepted-prefix.wl"}
    # These historical files were hashed in Global`. Declare that context at
    # their boundary, preserving both the immutable bytes and original prefix ID.
    for key in ("ordered_master_de", "accepted_prefix"):
        wrapper = final_dir / (key + "-global.wl")
        relative = Path(os.path.relpath(final_paths[key], final_dir))
        parts = ','.join(json.dumps(part, ensure_ascii=False) for part in relative.parts)
        wrapper.write_text('Block[{$Context="Global`",$ContextPath={"System`"}},'
                           'Get[FileNameJoin[{DirectoryName[$InputFileName],' + parts + '}]]]\n')
        final_paths[key] = wrapper
    write(final_input, {"schema": "canon-neu/script-input/v1", "task_id": "EXISTING-TINY-FINAL-CHECK",
        "step": "FINAL_CHECK", "sector": None, "payload": {
            key: {"type": "mathematica-expression", "path": os.path.relpath(path, final_dir), "sha256": digest(path)}
            for key, path in final_paths.items()}})
    final_output = final_dir / "output"
    final_result = invoke("existing-final-check", final_input, final_output, ("PASS", "ALL_PASS"), defaults=True)
    assert all(final_result["summary"]["checks"].values())
    assert set(final_result["artifacts"]) == {"canonical_basis", "canonical_de"}

    kira = read(recipe / "outputs/discover/backend-run.json")
    fixture = read(recipe / "outputs/discover/kira/fixture-invocation.json")
    pids = {fixture["pid"], read(recipe / "outputs/discover/active-process.json")["pid"],
            *[item["pid"] for item in kira["commands"]]}
    for pid in pids:
        for probe in (os.kill, os.killpg):
            try:
                probe(pid, 0)
            except ProcessLookupError:
                continue
            raise AssertionError(f"fixture process/group {pid} remains")
    assert all(digest(tree / path) == value for path, value in hashes.items())
    assert all(digest(recipe / "outputs/prepare" / prepared["artifacts"][key]["path"]) == value
               for key, value in producer_hashes.items())
    artifact_hashes = {}
    for record in records:
        result_path = tree / record["result"]
        for key, value in read(result_path)["artifacts"].items():
            path = (result_path.parent / value["path"]).resolve()
            artifact_hashes[record["name"] + "/" + key] = {
                "path": str(path.relative_to(tree)), "sha256": digest(path)}
    receipt = {"schema": "canon-neu/interface-first-integration-test/v1", "all_pass": True,
        "scope": "Data-only scalar interface integration on fixed analytic native-format fixtures, plus one unchanged two-master FINAL_CHECK regression.",
        "source_sha256": hashes, "test_source_sha256": digest(Path(__file__)),
        "steps": records, "request_binding_checks": binding_checks, "exact_scalar_readback": exact,
        "artifact_hashes": artifact_hashes,
        "relocation": {"original": str(original), "current": str(tree), "original_absent": not original.exists(),
            "before_move_checkpoint": "relocation.json", "producer_hashes_before_and_after": producer_hashes},
        "runtime": {"python": sys.executable, "python_version": sys.version, "wolframscript": wolfram,
            "wolframscript_sha256": digest(Path(wolfram)), "wolfram_version": exact["wolfram_version"],
            "maximum_concurrent_kernels": 1, "fixture_threads": 1},
        "final_check": {"invocations": 1, "result": final_result, "family_id": "fixture-full-tail",
            "raw_input_hashes": {str(path.relative_to(tree)): digest(path) for key, path in final_paths.items()
                                 if key in {"ordered_master_de", "accepted_prefix"}},
            "scope": "Existing exact-global-gauge, symbolic-flatness, shared-residue declared-dlog-span checker on the unchanged two-master fixture; independent of scalar native imports."},
        "discovery_fixture": fixture, "checked_process_ids": sorted(pids), "remaining_recorded_processes": [],
        "native_engine_runs": 0, "generated_scientific_glue_programs": 0,
        "root_python_suites_repeated": False}
    write(work / "receipt.json", receipt)
    print(json.dumps({"all_pass": True, "step_outcomes": len(records), "exact_scalar_facts": len(exact["facts"]),
                      "final_check": "PASS/ALL_PASS", "receipt": str(work / "receipt.json")}))


if __name__ == "__main__":
    main()
