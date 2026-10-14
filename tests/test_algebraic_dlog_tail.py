"""Algebraic residue normalization uses the unchanged public sector workflow."""
from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
KERNEL = Path(os.environ.get("CANON_WOLFRAM_KERNEL") or shutil.which("WolframKernel") or "WolframKernel").resolve()
SECTOR = {"id": 7, "propagator_count": 3}

FIXTURES = r'''
Get["CORE_PATH"];
base = "OUTPUT_PATH";
vars = {x,y,z};
letters = {(x+Sqrt[x^2+y])/(x-Sqrt[x^2+y]), (x+Sqrt[x^2+z])/(x-Sqrt[x^2+z])};
rs = Normal /@ {SparseArray[{{1,2}->1,{4,2}->1},{4,4}],SparseArray[{{4,3}->1},{4,4}]};
known = DiagonalMatrix[{1/(1+eps),1/(1+eps),1/(1+2 eps),1}];
target = Table[eps Total[MapThread[#1 Together[D[#2,v]/#2] &,{rs,letters}]],{v,vars}];
mixed = Map[Together,known.#.Inverse[known],{2}] & /@ target;
previousT = DiagonalMatrix[{2,3,5}];
lift = DiagonalMatrix[{2,3,5,1}];
raw = Map[Together,lift.#.Inverse[lift],{2}] & /@ mixed;
sector = <|"id"->7,"propagator_count"->3|>;
lowerSector = <|"id"->3,"propagator_count"->2|>;
family = "algebraic-dlog-tail";
basis = <|"schema"->"canon-neu/sector-basis/v1","family_id"->family,
  "basis_id"->"current","sector"->sector,"basis"->{j4}|>;
cut = Join[KeyDrop[basis,"schema"],<|"schema"->"canon-neu/sector-cut-de/v1",
  "coefficient_domain"->"exact-rational-functions","variables"->vars,"regulator"->eps,
  "matrices"->ConstantArray[{{0}},Length[vars]],"sector_boundaries"->{{1,1}}|>];
pool = Join[KeyDrop[cut,{"schema","matrices","sector_boundaries"}],
  <|"schema"->"canon-neu/core-candidates/v1","source_basis"->{j4},
  "candidate_group_pool"-><|"declared"->1,"eligible"->1,"remaining"->0,"pool_exhausted"->True|>,
  "convention"->"old_basis = transformation . new_basis",
  "method"-><|"id"->"identity-fixture","tool"->"none"|>,
  "candidates"->{<|"candidate_id"->"identity","member_candidate_ids"->{"identity"},
    "construction_rejection"->None,"transformation"->{{1}},"transformed_matrices"->ConstantArray[{{0}},Length[vars]],
    "full_new_basis_rows"->{{1}},"provider_evidence"-><||>|>}|>];
previous = <|"schema"->"canon-neu/accepted-prefix/v1","family_id"->family,
  "source_basis"->{j1,j2,j3},"basis"->Inverse[previousT].{j1,j2,j3},
  "transformation"->previousT,"variables"->vars,"regulator"->eps,"alphabet"->letters,
  "matrices"->(#[[1;;3,1;;3]] & /@ mixed),"sector_trace"->{lowerSector},
  "candidate_trace"->{<|"sector"->lowerSector|>}|>;
previous = Join[<|"prefix_id"->"sha256:"<>Hash[previous,"SHA256","HexString"]|>,previous];
objects = <|"basis"->basis,"cut"->cut,"pool"->pool,"previous"->previous,
  "ordered"-><|"schema"->"canon-neu/ordered-master-de/v1","family_id"->family,
    "basis_id"->"raw","basis"->{j1,j2,j3,j4},"variables"->vars,"regulator"->eps,"matrices"->raw|>,
  "prepared"-><|"family_ref"->family,"basis_ref"->"raw","variables"->vars,"regulator"->eps|>,
  "masters"-><|"family_ref"->family,"basis_ref"->"raw","masters"->{j1,j2,j3,j4}|>,
  "manifest"-><|"sectors"->{lowerSector,sector}|>|>;
KeyValueMap[Put[#2,FileNameJoin[{base,#1<>".wl"}]] &,objects];
'''


@unittest.skipUnless(KERNEL.is_file(), "requires a declared WolframKernel")
class AlgebraicDLogTailTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        retained = os.environ.get("CANON_TEST_ALGEBRAIC_TAIL_OUTPUT_ROOT")
        self.directory = Path(retained).resolve() / self._testMethodName if retained else Path(self.temp.name).resolve()
        self.directory.mkdir(parents=True, exist_ok=not bool(retained))
        self.environment = dict(os.environ)
        for key in ("OMP_NUM_THREADS", "MKL_NUM_THREADS", "OPENBLAS_NUM_THREADS", "VECLIB_MAXIMUM_THREADS"):
            self.environment[key] = "1"
        self.index = 0
        script = self.directory / "fixtures.wls"
        script.write_text(FIXTURES.replace("CORE_PATH", str(ROOT / "mma/lib/MethodCardCore.wl"))
                          .replace("OUTPUT_PATH", str(self.directory)))
        self.kernel(script)
        steps = {"CHECK_CORE": "mma/CheckSectorCore.wls", "BUILD_FULL_DE": "mma/BuildFullSectorDE.wls",
                 "SOLVE_TAIL": "mma/SolveTail.wls", "CHECK_CANONICAL": "mma/CheckCanonical.wls",
                 "COMMIT_SECTOR": "mma/CommitSector.wls", "FINAL_CHECK": "mma/CheckFullSystem.wls"}
        cards = {"CHECK_CORE": "canon-check-core", "BUILD_FULL_DE": "canon-build-full-de",
                 "SOLVE_TAIL": "canon-solve-tail", "CHECK_CANONICAL": "canon-check-canonical",
                 "COMMIT_SECTOR": "canon-commit-sector", "FINAL_CHECK": "canon-final-check"}
        self.manifest = self.directory / "components.json"
        self.manifest.write_text(json.dumps({"schema": "canon-neu/components/v1", "steps": {
            step: {"command": [sys.executable, str(ROOT / "tests/wolfram_kernel_launcher.py"),
                               str(KERNEL), "-noinit", "-noprompt", "-script", str(ROOT / script_path)],
                   "instructions": str(ROOT / "skills" / cards[step] / "SKILL.md")}
            for step, script_path in steps.items()}}))

    def tearDown(self):
        self.temp.cleanup()

    def kernel(self, script):
        p = subprocess.run([sys.executable, str(ROOT / "tests/wolfram_kernel_launcher.py"),
            str(KERNEL), "-noinit", "-noprompt", "-script", str(script)], cwd=ROOT,
            env=self.environment, text=True, capture_output=True, timeout=120)
        script.with_suffix(".log").write_text(p.stdout + p.stderr)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)

    def ref(self, name):
        return {"type": "mathematica-expression", "path": str(self.directory / f"{name}.wl")}

    @staticmethod
    def artifact(run, key):
        return {"type": "mathematica-expression", "path": str(run[1] / run[0]["artifacts"][key]["path"])}

    def invoke(self, step, payload):
        self.index += 1
        request, output = self.directory / f"input-{self.index}.json", self.directory / f"output-{self.index}"
        request.write_text(json.dumps({"schema": "canon-neu/script-input/v1", "task_id": f"dlog-{self.index}",
            "step": step, "sector": None if step == "FINAL_CHECK" else SECTOR, "payload": payload}))
        manifests = [ROOT / "components/profiles/custom-kira.json", ROOT / "components/local-jobs/components.json",
                     self.manifest]
        command = [sys.executable, str(ROOT / "run_step.py"), str(request), str(output)]
        command.extend(arg for manifest in manifests for arg in ("--components", str(manifest)))
        p = subprocess.run(command, cwd=ROOT, env=self.environment, text=True, capture_output=True, timeout=120)
        output.with_suffix(".log").write_text(p.stdout + p.stderr)
        result_path = output / "result.json"
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr + (result_path.read_text() if result_path.exists() else ""))
        return json.loads((output / "result.json").read_text()), output

    def full_de(self):
        core = self.invoke("CHECK_CORE", {"sector_basis": self.ref("basis"), "sector_cut_de": self.ref("cut"),
            "core_candidates": self.ref("pool")})
        self.assertEqual(core[0]["code"], "CORE_PASS")
        full = self.invoke("BUILD_FULL_DE", {"ordered_master_de": self.ref("ordered"), "sector_cut_de": self.ref("cut"),
            "core_candidates": self.ref("pool"), "core_transform": self.artifact(core, "core_transform"),
            "declared_alphabet": None, "accepted_prefix": self.ref("previous")})
        self.assertEqual(full[0]["status"], "PASS")
        return self.artifact(full, "full_sector_de"), self.artifact(core, "core_transform")

    def test_same_workflow_reaches_final_check_and_rejects_tampered_gauge(self):
        full, core = self.full_de()
        tail = self.invoke("SOLVE_TAIL", {"full_sector_de": full, "core_transform": core})
        self.assertEqual((tail[0]["status"], tail[0]["code"]), ("PASS", "TAIL_READY"))
        self.assertEqual(tail[0]["summary"]["method"], "algebraic-dlog-epsilon-normalization")
        self.assertNotIn("method_messages", tail[0]["artifacts"])
        check = self.invoke("CHECK_CANONICAL", {"full_sector_de": full,
            "sector_transform": self.artifact(tail, "sector_transform")})
        self.assertEqual(check[0]["code"], "CANONICAL_PASS")
        commit = self.invoke("COMMIT_SECTOR", {"previous_accepted_prefix": self.ref("previous"),
            "sector_basis": self.ref("basis"), "sector_transform": self.artifact(tail, "sector_transform"),
            "canonical_sector_de": self.artifact(check, "canonical_sector_de")})
        self.assertEqual(commit[0]["summary"]["accepted_master_count"], 4)
        final = self.invoke("FINAL_CHECK", {"prepared_family": self.ref("prepared"), "master_basis": self.ref("masters"),
            "sector_manifest": self.ref("manifest"), "ordered_master_de": self.ref("ordered"),
            "accepted_prefix": self.artifact(commit, "accepted_prefix")})
        self.assertEqual((final[0]["status"], final[0]["code"]), ("PASS", "ALL_PASS"))
        script = self.directory / "tamper.wls"
        transform = self.artifact(tail, "sector_transform")["path"]
        script.write_text(f'v=Get[{json.dumps(transform)}];\n'
                          f'Put[Join[v,<|"transformed_matrices"->0 v["transformed_matrices"]|>],'
                          f'{json.dumps(str(self.directory / "tampered.wl"))}];\n')
        self.kernel(script)
        rejected = self.invoke("CHECK_CANONICAL", {"full_sector_de": full, "sector_transform": self.ref("tampered")})
        self.assertEqual(rejected[0]["status"], "FAIL")
        self.assertFalse(rejected[0]["summary"]["full_checks"]["exact_gauge"])

    def test_existing_wall_budget_reports_incomplete_without_backend(self):
        full, core = self.full_de()
        tail = self.invoke("SOLVE_TAIL", {"full_sector_de": full, "core_transform": core,
            "method_options": {"max_wall_seconds": 0.001}})
        self.assertEqual((tail[0]["status"], tail[0]["code"]), ("INCONCLUSIVE", "TAIL_UNSOLVED"))
        self.assertEqual(tail[0]["summary"]["builtin_completion"]["dlog_epsilon_normalization"]["stage"], "wall_budget")
        self.assertEqual(tail[0]["artifacts"], {})

    def test_rational_post_d_repair_uses_the_same_workflow_through_final_check(self):
        rational = r'''
vars={x}; letters={x,x-1};
rs=Normal /@ {SparseArray[{{1,2}->1,{4,2}->1},{4,4}],
  SparseArray[{{4,3}->1},{4,4}]};
normalization=DiagonalMatrix[{1/(1+eps),1/(1+eps),1/(1+2 eps),1}];
shear=IdentityMatrix[4];
shear[[4,1;;3]]={1/(eps x^2),1/((1+eps)(x+1)),x^2/eps};
known=normalization.shear;
target={eps (rs[[1]]/x+rs[[2]]/(x-1))};
mixed={Map[Together,(known.First[target]+D[known,x]).Inverse[known],{2}]};
'''
        start, end = FIXTURES.index("vars ="), FIXTURES.index("previousT =")
        script = self.directory / "rational-fixtures.wls"
        script.write_text((FIXTURES[:start] + rational + FIXTURES[end:])
                          .replace("CORE_PATH", str(ROOT / "mma/lib/MethodCardCore.wl"))
                          .replace("OUTPUT_PATH", str(self.directory)))
        self.kernel(script)
        # A controlled completed D frame isolates the module's new post-D
        # capability. Exact independent checks below use the original source.
        entry = self.directory / "completed-d.m"
        entry.write_text('''BeginPackage["CANONICA`"];
eps; VerbosityLevel; DDeltaNumeratorDegree;
TransformOffDiagonalBlock[v_,b_,t_,a_,___]:={t,a};
TransformDlogToEpsForm[___]:=Abort[];
EndPackage[];
''')
        full, core = self.full_de()
        tail = self.invoke("SOLVE_TAIL", {"full_sector_de": full, "core_transform": core,
            "method_options": {"package_entry": str(entry)}})
        self.assertEqual(tail[0]["code"], "TAIL_READY")
        evidence = tail[0]["summary"]["backend"]["dlog_epsilon_normalization"]
        self.assertGreater(evidence["pole_repair"]["corrections"], 0)
        check = self.invoke("CHECK_CANONICAL", {"full_sector_de": full,
            "sector_transform": self.artifact(tail, "sector_transform")})
        self.assertEqual(check[0]["code"], "CANONICAL_PASS")
        self.assertTrue(all(check[0]["summary"]["full_checks"].values()))
        commit = self.invoke("COMMIT_SECTOR", {"previous_accepted_prefix": self.ref("previous"),
            "sector_basis": self.ref("basis"), "sector_transform": self.artifact(tail, "sector_transform"),
            "canonical_sector_de": self.artifact(check, "canonical_sector_de")})
        final = self.invoke("FINAL_CHECK", {"prepared_family": self.ref("prepared"),
            "master_basis": self.ref("masters"), "sector_manifest": self.ref("manifest"),
            "ordered_master_de": self.ref("ordered"),
            "accepted_prefix": self.artifact(commit, "accepted_prefix")})
        self.assertEqual((final[0]["status"], final[0]["code"]), ("PASS", "ALL_PASS"))


if __name__ == "__main__":
    unittest.main()
