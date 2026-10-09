#!/usr/bin/env python3
"""Native invariant serialization and public import/recovery regression fixtures."""

import argparse
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


PACKAGE = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("kira_alias_adapter", PACKAGE / "run.py")
ADAPTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ADAPTER)


def family(names):
    return {"schema": "canon-neu/reducer-family/v1", "family_ref": "alias-fixture", "basis_ref": "alias-source",
        "topology": "alias_native", "integral_head": "B", "index_order": ["D1", "D2"],
        "propagator_slots": [1, 2], "top_level_sectors": [3], "loop_momenta": ["l"], "external_momenta": ["p"],
        "propagators": [{"momentum": "l", "mass_squared": "0"}, {"momentum": "l-p", "mass_squared": "0"}],
        "scalar_products": [{"momenta": ["p", "p"], "value": names[0]}],
        "invariants": [{"name": name, "mass_dimension": 2} for name in names],
        "point": [], "dimension": "d", "variables": names, "regulator": "eps"}


class AliasTests(unittest.TestCase):
    def test_compatible_names_preserved(self):
        f = family(["s", "t", "m3sq"])
        self.assertEqual(ADAPTER.invariant_aliases(f), [{"scientific": x, "native": x} for x in f["variables"]])

    def test_deterministic_collisions_and_reserved_dimension(self):
        f = family(["S", "s", "canonkira1", "M3sq", "canonkira4", "d", "Foreign`T"])
        before = copy.deepcopy(f)
        aliases = ADAPTER.invariant_aliases(f)
        self.assertEqual([x["native"] for x in aliases],
                         ["canonkira2", "s", "canonkira1", "canonkira5", "canonkira4", "canonkira6", "canonkira7"])
        self.assertEqual(aliases, ADAPTER.invariant_aliases(f))
        self.assertEqual(f, before)

    def test_native_momentum_and_topology_names_reserved(self):
        f = family(["S"])
        f["loop_momenta"] = ["canonkira1"]
        f["topology"] = "canonkira2"
        self.assertEqual(ADAPTER.invariant_aliases(f)[0]["native"], "canonkira3")

    def test_whole_tokens_and_contexts(self):
        aliases = [{"scientific": "S", "native": "canonkira1"}, {"scientific": "M3sq", "native": "canonkira2"},
                   {"scientific": "Foreign`T", "native": "canonkira3"}]
        expression = "S+S1+M3sq+M3sq2+S_other+S$other+Foreign`S+CANON`DEData`S+Foreign`T"
        self.assertEqual(ADAPTER.native_expression(expression, aliases),
            "canonkira1+S1+canonkira2+M3sq2+S_other+S$other+Foreign`S+canonkira1+canonkira3")
        self.assertEqual(ADAPTER.native_expression("canonkira1+S", aliases), "canonkira1+canonkira1")

    def test_mass_scalar_product_and_momentum_coefficients(self):
        f = family(["S", "s", "M3sq"])
        f["propagators"][1] = {"momentum": "l-(S/s)*p", "mass_squared": "M3sq+S"}
        f["scalar_products"][0]["value"] = "(S-M3sq)/2"
        before = copy.deepcopy(f)
        with tempfile.TemporaryDirectory() as name:
            directory = Path(name)
            ADAPTER.prepare_project(f, {"seed": {"r": 3, "s": 0, "d": 1}}, directory / "backend.json", directory, "DISCOVER")
            self.assertIn('["l-(canonkira1/s)*p", "canonkira3+canonkira1"]',
                          (directory / "config/integralfamilies.yaml").read_text())
            config = (directory / "config/kinematics.yaml").read_text()
            self.assertIn('[["canonkira1", 2], ["s", 2], ["canonkira3", 2]]', config)
            self.assertIn('[["p", "p"], "(canonkira1-canonkira3)/2"]', config)
        self.assertEqual(f, before)

    def test_saved_mapping_is_used_without_regeneration(self):
        f = family(["S", "s"])
        saved = [{"scientific": "S", "native": "oldnative1"}, {"scientific": "s", "native": "oldnative2"}]
        self.assertEqual(ADAPTER.invariant_aliases(f, saved, legacy=True), saved)
        self.assertNotEqual(ADAPTER.invariant_aliases(f), saved)

    def test_legacy_compatible_identity_and_unsafe_rejection(self):
        self.assertEqual(ADAPTER.invariant_aliases(family(["s"]), legacy=True), [{"scientific": "s", "native": "s"}])
        with self.assertRaisesRegex(ValueError, "requires saved invariant aliases"):
            ADAPTER.invariant_aliases(family(["S"]), legacy=True)

    def test_saved_mapping_collisions_and_identity_rejected(self):
        f = family(["S", "s"])
        for native in (["s", "s"], ["S", "s"], ["d", "s"]):
            with self.subTest(native=native), self.assertRaisesRegex(ValueError, "backend-safe"):
                ADAPTER.invariant_aliases(f, [dict(scientific=name, native=value) for name, value in zip(f["variables"], native)])
        with self.assertRaisesRegex(ValueError, "differ from the neutral family"):
            ADAPTER.invariant_aliases(f, [{"scientific": "s", "native": "s"}])

    def test_same_scientific_symbol_cannot_have_two_native_aliases(self):
        with self.assertRaisesRegex(ValueError, "distinct"):
            ADAPTER.invariant_aliases(family(["S", "CANON`DEData`S"]))


FAKE = r'''
from pathlib import Path
import json, os, sys
mode, job = sys.argv[1:]
with Path(os.environ["KIRA_ALIAS_TEST_MARKER"]).open("a") as marker: marker.write("native call\n")
aliases = json.loads(Path("../interop.json").read_text())["invariant_aliases"]
config = Path("config/kinematics.yaml").read_text()
for item in aliases:
    assert '["' + item["native"] + '", 2]' in config
    assert item["native"][0].islower() and item["native"] != "d"
assert '"S"' not in config and '"Foreign`T"' not in config
out = Path("results/alias_native"); out.mkdir(parents=True)
masters = "alias_native[1,0]\nalias_native[1,1]\n"
if mode == "basis-mismatch": masters += "alias_native[0,2]\n"
(out/"masters.final").write_text(masters)
coefficient = "+".join([item["native"] for item in aliases]+["d"])
if mode == "unknown-coefficient": coefficient += "+rogue+canonkira99"
first = "alias_native[2,1] -> ("+coefficient+") alias_native[1,1]"
second = "alias_native[1,2] -> -"+aliases[0]["native"]+"/(d-1) alias_native[1,0]"
rules = [first, second]
if mode == "missing-target": rules = [first]
if mode == "source-changed": rules.append("alias_native[1,1] -> 2 alias_native[1,1]")
if mode == "nonlinear": rules[0] = "alias_native[2,1] -> alias_native[1,1]^2"
(out/"kira_targets.m").write_text("{"+",".join(rules)+"}")
'''


CHECK = r'''
{canon,base,mode}=Rest[$ScriptCommandLine];
Get[FileNameJoin[{canon,"mma","lib","MethodCardCore.wl"}]];
read[name_]:=CanonMethodCard`ReadWLData[FileNameJoin[{base,name,"ibp-reduction.wl"}]];
If[mode==="native",
  red=read["native-uppercase"];
  facts=<|"exact_native_bubble_recurrence"->And@@(Together[#-(3-Foreign`dim)/CANON`DEData`S CANON`DEData`B[1,1]]===0 & /@ (Last /@ red["rules"])),
    "scientific_source"->(red["masters"]==={CANON`DEData`B[1,1]})|>,
  red=read["uppercase"]; recovery=read["saved-recovery"]; expr=read["dimension-expression"];
  expected=CANON`DEData`S+CANON`DEData`s+CANON`DEData`canonkira1+CANON`DEData`M3sq+CANON`DEData`M4sq+Foreign`T+CANON`DEData`d+Foreign`dim;
  kin=CanonMethodCard`ReadWLData[FileNameJoin[{base,"uppercase","reduction-kinematics.wl"}]];
  facts=<|"scientific_contexts_and_dimension"->(Together[(CANON`DEData`B[2,1]/.red["rules"])-expected CANON`DEData`B[1,1]]===0),
    "second_target"->(Together[(CANON`DEData`B[1,2]/.red["rules"])+CANON`DEData`S/(Foreign`dim-1) CANON`DEData`B[1,0]]===0),
    "dimension_expression_and_invariant_d_distinct"->(Together[(CANON`DEData`B[2,1]/.expr["rules"])-(expected/.Foreign`dim->4-2 CANON`DEData`ep) CANON`DEData`B[1,1]]===0),
    "full_source_order_including_unused"->(red["masters"]==={CANON`DEData`B[1,1],CANON`DEData`B[1,0],CANON`DEData`B[0,1]}),
    "all_targets"->(First /@ red["rules"]==={CANON`DEData`B[2,1],CANON`DEData`B[1,2]}),
    "variables_retained"->(kin["variables"]==={CANON`DEData`S,CANON`DEData`s,CANON`DEData`canonkira1,CANON`DEData`M3sq,CANON`DEData`M4sq,Foreign`T,CANON`DEData`d}),
    "saved_recovery_exact"->(red===recovery),
    "historical_saved_aliases_exact"->(red===read["historical-recovery"]),
    "legacy_recovery_exact"->(read["legacy"]===read["legacy-recovery"])|>
];
Export[FileNameJoin[{base,"facts.json"}],facts,"RawJSON"];
Exit[If[And@@Values[facts],0,1]];
'''


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--canon", type=Path, required=True)
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--components", type=Path, action="append", default=[])
    parser.add_argument("--native-kira", help="run only one installed uppercase bubble after unit checks")
    args = parser.parse_args()
    canon, work = args.canon.resolve(), args.work.resolve()
    work.mkdir(parents=True, exist_ok=False)
    units = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(AliasTests))
    assert units.wasSuccessful()
    components = [str(x.resolve()) for x in args.components] or [str(canon / "components/profiles/custom-kira.json")]
    runtime = os.environ.get("CANON_WOLFRAMSCRIPT") or shutil.which("wolframscript")
    if not runtime:
        raise RuntimeError("configure CANON_WOLFRAMSCRIPT or wolframscript on PATH")
    environment = dict(os.environ, OMP_NUM_THREADS="1", MKL_NUM_THREADS="1", OPENBLAS_NUM_THREADS="1", PYTHONDONTWRITEBYTECODE="1")
    environment.pop("CANON_COMPONENTS", None)
    (work / "fixture.py").write_text(FAKE)
    marker = work / "native-calls.txt"
    records = []

    def run(name, f, expected="IBP_REDUCED", mode="normal", source=None):
        write(work / (name + "-family.json"), f)
        target_list = "{B[2,1],B[1,2]}"
        master_list = "{B[1,1]}" if args.native_kira else "{B[1,1],B[1,0],B[0,1]}"
        (work / (name + "-targets.wl")).write_text('<|"schema"->"canon-neu/reduction-targets/v1","family_ref"->"alias-fixture","basis_ref"->"alias-source","targets"->'+target_list+',"masters"->'+master_list+',"point"->{}|>')
        backend = {"schema": "canon-neu/kira-backend/v1", "executable": sys.executable,
            "options": [str(work / "fixture.py"), mode], "seed": {"r": 3, "s": 0, "d": 1}, "timeout_seconds": 5,
            "environment": {"KIRA_ALIAS_TEST_MARKER": str(marker)}}
        if args.native_kira:
            backend.update(executable=args.native_kira, options=["--parallel=1"], timeout_seconds=90)
        if source:
            backend = {"schema": "canon-neu/kira-backend/v1", "import_from": str(source),
                       "executable": "must-not-resolve-or-execute", "import_timeout_seconds": 30}
        write(work / (name + "-backend.json"), backend)
        request = work / (name + ".json")
        write(request, {"schema": "canon-neu/script-input/v1", "task_id": name, "step": "REDUCE_IBP", "sector": None,
            "payload": {"reducer_family": {"path": name + "-family.json"}, "backend": {"path": name + "-backend.json"},
                        "reduction_targets": {"path": name + "-targets.wl"}}})
        output = work / name
        command = [sys.executable, str(canon / "run_step.py"), str(request), str(output)]
        for manifest in components:
            command += ["--components", manifest]
        if not records:
            described = subprocess.run(command + ["--describe"], env=environment, capture_output=True, text=True, check=True)
            (work / "selected-description.json").write_text(described.stdout)
        with (work / (name + ".log")).open("w") as log:
            completed = subprocess.run(command, env=environment, stdout=log, stderr=subprocess.STDOUT, timeout=130)
        result = json.loads((output / "result.json").read_text())
        assert result["code"] == expected, (name, result)
        assert (completed.returncode == 0) == (expected == "IBP_REDUCED"), (name, completed.returncode)
        receipt = json.loads((output / "backend-run.json").read_text())
        if expected == "IBP_REDUCED":
            assert receipt["invariant_aliases"] == json.loads((output / "interop.json").read_text())["invariant_aliases"]
            assert json.loads((work / (name + "-family.json")).read_text()) == f
            assert result["summary"]["complete_target_coverage"] and result["summary"]["source_master_order_preserved"]
        records.append({"case": name, "code": result["code"], "status": result["status"], "returncode": completed.returncode,
                        "native_command_count": len(receipt["commands"]), "aliases": receipt.get("invariant_aliases")})
        print(name + ": " + result["status"] + "/" + result["code"], flush=True)
        return output

    if args.native_kira:
        f = family(["S"]); f.update(topology="bubble", dimension="Foreign`dim")
        run("native-uppercase", f)
    else:
        f = family(["S", "s", "canonkira1", "M3sq", "M4sq", "Foreign`T", "d"])
        f["dimension"] = "Foreign`dim"
        f["propagators"][1] = {"momentum": "l-(S/s)*p", "mass_squared": "M3sq+M4sq"}
        f["scalar_products"][0]["value"] = "(S+M3sq+Foreign`T)/2"
        source = run("uppercase", f)
        before_calls, before_result = marker.read_bytes(), (source / "result.json").read_bytes()
        recovered = run("saved-recovery", f, source=source)
        receipt = json.loads((recovered / "backend-run.json").read_text())
        assert receipt["commands"] == [] and receipt["native_execution_inherited"]
        assert marker.read_bytes() == before_calls and (source / "result.json").read_bytes() == before_result
        assert sorted(p.name for p in (recovered / "kira").iterdir()) == ["preferred-masters", "targets"]
        context = json.loads((source / "interop.json").read_text())
        # A synthetic older native-format project uses a different valid alias
        # convention; public recovery must honor that saved mapping.
        historical = work / "historical-native-fixture"
        receipt = json.loads((source / "backend-run.json").read_text())
        old_aliases = context["invariant_aliases"]
        saved_aliases = [dict(scientific=item["scientific"], native=f"oldnative{i}") for i, item in enumerate(old_aliases, 1)]
        rename = [dict(scientific=old["native"], native=new["native"]) for old, new in zip(old_aliases, saved_aliases)]
        for name in ["result.json", "request-data.wl", "reduction-kinematics.wl", "kira/targets", "kira/preferred-masters",
                     "kira/jobs.yaml", "kira/config/kinematics.yaml", "kira/config/integralfamilies.yaml",
                     "kira/results/alias_native/masters.final", "kira/results/alias_native/kira_targets.m"]:
            destination = historical / name; destination.parent.mkdir(parents=True, exist_ok=True)
            text = (source / name).read_text()
            if name.startswith("kira/config/") or name.endswith("kira_targets.m"):
                text = ADAPTER.native_expression(text, rename)
            destination.write_text(text)
        receipt.update(invariant_aliases=saved_aliases, fixture_simulated_historical_aliases=True)
        receipt["native_outputs"]["native_rules"]["sha256"] = hashlib.sha256((historical / "kira/results/alias_native/kira_targets.m").read_bytes()).hexdigest()
        write(historical / "backend-run.json", receipt)
        write(historical / "interop.json", {**context, "invariant_aliases": saved_aliases})
        historical_output = run("historical-recovery", f, source=historical)
        assert json.loads((historical_output / "backend-run.json").read_text())["invariant_aliases"] == saved_aliases
        assert marker.read_bytes() == before_calls
        changed = copy.deepcopy(context); changed["invariant_aliases"][0]["native"] = "differentnative"
        write(source / "interop.json", changed)
        rejected = run("alias-binding-mismatch", f, "KIRA_ADAPTER_ERROR", source=source)
        assert not (rejected / "prepare.log").exists() and marker.read_bytes() == before_calls
        write(source / "interop.json", context)
        for mode, expected in [("unknown-coefficient", "UNDECLARED_NATIVE_COEFFICIENT"), ("missing-target", "UNREDUCED_NATIVE_OUTPUT"),
            ("basis-mismatch", "NATIVE_BASIS_MISMATCH"), ("source-changed", "SOURCE_BASIS_CHANGED"), ("nonlinear", "NATIVE_RULES_NOT_LINEAR")]:
            run(mode, f, expected, mode)
        run("dimension-expression", {**f, "dimension": "4-2*ep"})
        lower = family(["s"])
        legacy = run("legacy", lower)
        for name in ("backend-run.json", "interop.json"):
            old = json.loads((legacy / name).read_text()); del old["invariant_aliases"]; write(legacy / name, old)
        before_calls = marker.read_bytes()
        run("legacy-recovery", lower, source=legacy)
        assert marker.read_bytes() == before_calls
    (work / "Checks.wls").write_text(CHECK)
    with (work / "checks.log").open("w") as log:
        subprocess.run([runtime, "-file", str(work / "Checks.wls"), str(canon), str(work), "native" if args.native_kira else "fixtures"],
                       env=environment, stdout=log, stderr=subprocess.STDOUT, timeout=30, check=True)
    facts = json.loads((work / "facts.json").read_text())
    assert all(facts.values())
    write(work / "evidence.json", {"all_expected": True, "unit_tests": units.testsRun, "cases": records, "facts": facts,
        "components": components, "native_execution": bool(args.native_kira), "kernel_concurrency": 1, "reducer_concurrency": 1,
        "scope": "one installed uppercase symbolic bubble" if args.native_kira else "native-format fixtures and import-only recovery; no native Kira"})


if __name__ == "__main__":
    main()
