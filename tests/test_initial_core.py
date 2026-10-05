"""INITIAL core protocol and exact seed algebra; fake provider does not certify UT."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/fixtures/initial_core"
KERNEL_RAW = os.environ.get("CANON_WOLFRAM_KERNEL") or shutil.which("WolframKernel")
WRAPPER_RAW = os.environ.get("CANON_TEST_WOLFRAM_WRAPPER")
AVAILABLE = bool(WRAPPER_RAW and Path(WRAPPER_RAW).is_file()) or bool(
    KERNEL_RAW and Path(KERNEL_RAW).expanduser().is_file())


@unittest.skipUnless(AVAILABLE, "requires a declared Wolfram kernel or test wrapper")
class InitialCoreTest(unittest.TestCase):
    def setUp(self):
        receipt = os.environ.get("CANON_INITIAL_CORE_RUNTIME_RECEIPT_DIRECTORY")
        if self._testMethodName == "test_official_ladder_isomorphic_runtime" and receipt:
            self.temporary = None
            self.root = Path(receipt).resolve()
            self.root.mkdir()
        else:
            self.temporary = tempfile.TemporaryDirectory(prefix="canon-initial-core-")
            self.root = Path(self.temporary.name)
        self.inputs = self.root / "inputs"
        self.inputs.mkdir()
        self.outputs = self.root / "outputs"
        self.outputs.mkdir()
        self.components = self.root / "components"
        self.components.mkdir()
        for name in ("sector-basis.wl", "sector-cut-de.wl", "seed-request.wl", "normalization-receipt.txt"):
            shutil.copyfile(FIXTURES / name, self.inputs / name)
        for name in ("fake-finiteflow.wl", "fake-initial.wl"):
            shutil.copyfile(FIXTURES / name, self.components / name)
        self.library = self.components / "fake-native-library"
        self.library.write_text("fixture library path only")
        evidence_path = self.inputs / "normalization-receipt.txt"
        self.evidence = ('<|"status" -> "established", "kind" -> "official-reference", '
                         '"statement" -> "Algebra fixture normalization, not physical UT evidence", '
                         '"source" -> <|"path" -> "normalization-receipt.txt", "sha256" -> "'
                         + hashlib.sha256(evidence_path.read_bytes()).hexdigest() + '"|>|>')
        self.seed_rows = '''<|"schema" -> "canon-neu/initial-seed-rows/v1",
          "sector" -> <|"id" -> 3, "propagator_count" -> 2|>,
          "family_id" -> "initial-core-algebra", "basis_id" -> "initial-core-algebra/3",
          "basis" -> {j1,j2}, "variables" -> {x}, "regulator" -> eps,
          "source_basis" -> {lower,j1,j2},
          "seeds" -> {<|"id" -> "normalized-seed", "full_new_basis_row" -> {1/(1+x),x,1},
            "normalization_evidence" -> EVIDENCE|>}|>'''.replace("EVIDENCE", self.evidence)
        (self.inputs / "seed-rows.wl").write_text(self.seed_rows)
        self.options = {
            "package_entry": str(self.components / "fake-initial.wl"),
            "finite_flow_package_file": str(self.components / "fake-finiteflow.wl"),
            "finite_flow_library": str(self.library), "initial_identity": "test-fake-initial",
            "finiteflow_identity": "test-fake-finiteflow", "threads": 4,
            "timeout_seconds": 30, "max_iterations": 7, "max_degree": 40, "max_primes": 5,
        }
        self.payload = {key: {"type": "mathematica-expression", "path": str(self.inputs / file)}
                        for key, file in {"sector_basis": "sector-basis.wl", "sector_cut_de": "sector-cut-de.wl",
                                          "seed_request": "seed-request.wl", "seed_rows": "seed-rows.wl"}.items()}
        self.counter = 0

    def tearDown(self):
        if self.temporary:
            self.temporary.cleanup()

    def execute(self, script, *args, timeout=65, mode=""):
        env = os.environ.copy()
        env["CANON_INITIAL_FAKE_LIBRARY"] = str(self.library)
        env["CANON_INITIAL_FAKE_MODE"] = mode
        for name in ("OMP_NUM_THREADS", "MKL_NUM_THREADS", "OPENBLAS_NUM_THREADS", "VECLIB_MAXIMUM_THREADS"):
            env[name] = "1"
        command = ([WRAPPER_RAW, str(script), *map(str, args)] if WRAPPER_RAW else
                   [sys.executable, str(ROOT / "tests/wolfram_kernel_launcher.py"),
                    str(Path(KERNEL_RAW).expanduser().resolve()), "-noinit", "-noprompt", "-script",
                    str(script), *map(str, args)])
        process = subprocess.Popen(command, cwd=self.outputs, env=env, text=True,
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            stdout, _ = process.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.communicate(timeout=3)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.communicate()
            raise
        # Match the existing harness's libomp process-registration settling time.
        time.sleep(2)
        if self._testMethodName == "test_official_ladder_isomorphic_runtime" and not self.temporary:
            log_root = self.root / "execution-logs"
            log_root.mkdir(exist_ok=True)
            number = len(list(log_root.glob("*.log"))) + 1
            (log_root / f"{number:02d}-{Path(script).name}.log").write_text(stdout)
            (log_root / f"{number:02d}-{Path(script).name}.json").write_text(json.dumps({
                "command": command, "exit_code": process.returncode}, indent=2) + "\n")
        return process.returncode, stdout

    def run_provider(self, *, options=None, payload=None, expected=("PROVISIONAL", "CANDIDATE_TRANSFORMATION"),
                     mode="", output=None, entry=None):
        self.counter += 1
        task = {"schema": "canon-neu/script-input/v1", "task_id": f"initial-core-{self.counter}",
                "step": "SEARCH_CORE", "sector": {"id": 3, "propagator_count": 2},
                "payload": (payload if payload is not None else self.payload) |
                           {"method_options": options if options is not None else self.options}}
        input_path = self.root / f"input-{self.counter}.json"
        input_path.write_text(json.dumps(task))
        output = output or self.outputs / str(self.counter)
        code, stdout = self.execute(entry or ROOT / "methods/initial/run.wls", input_path, output, mode=mode)
        if expected is None:
            self.assertEqual(code, 2, stdout)
            self.assertFalse(output.exists(), stdout)
            return None, output
        self.assertTrue((output / "result.json").is_file(), stdout)
        result = json.loads((output / "result.json").read_text())
        self.assertEqual((result["status"], result["code"]), expected, result)
        self.assertEqual(code, 1 if expected[0] == "ERROR" else 0, stdout)
        if expected[0] != "PROVISIONAL":
            self.assertEqual(result["artifacts"], {})
            self.assertFalse((output / "core-candidates.wl").exists())
        return result, output

    def algebra_assert(self, expression, *, files=()):
        self.counter += 1
        script = self.outputs / f"assert-{self.counter}.wls"
        script.write_text('Get[' + json.dumps(str(ROOT / "mma/lib/MethodCardCore.wl")) + '];\n'
                          'Get[' + json.dumps(str(ROOT / "methods/initial-core/SeedSystem.wl")) + '];\n'
                          + '\n'.join(name + '=Get[' + json.dumps(str(path)) + '];' for name, path in files)
                          + '\nchecks=' + expression + ';\nPrint[InputForm[checks]];\n'
                          'Quit[If[And@@(TrueQ/@Flatten[checks]),0,1]];\n')
        code, stdout = self.execute(script)
        self.assertEqual(code, 0, stdout)

    def test_single_seed_lower_columns_and_independent_core_gate(self):
        result, output = self.run_provider()
        self.assertEqual(result["summary"]["interface"]["role"], "core-candidate-provider")
        self.assertEqual(result["summary"]["interface"]["lifecycle"], "active")
        self.assertFalse(result["summary"]["interface"]["reference_equality_required"])
        self.assertTrue(all(result["summary"]["provider_prechecks"].values()))
        self.algebra_assert('''With[{c=First[a["candidates"]], call=First[calls]}, {
          Length[calls]===1, call["take_row"]===1, call["threads"]===4,
          call["max_iterations"]===7, call["max_degree"]===40, call["max_primes"]===5,
          a["source_basis"]==={lower,j1,j2},
          c["full_new_basis_rows"]==={{1/(1+x),x,1},{-x/(1+x),-x^2,1-x}},
          CanonMethodCard`ZeroMatrixQ[c["full_new_basis_rows"][[All,{2,3}]]-Inverse[c["transformation"]]],
          a["method","source_seed_rows"]==={{1/(1+x),x,1}},
          a["method","initial_runtime","adapter","applied"]===False,
          a["method","initial_runtime","source","sha256"]===
            FileHash[a["method","components","package_entry","path"],"SHA256","HexString"],
          StringLength[a["method","source_basis_sha256"]]===64,
          a["method","inputs","seed_rows","sha256"]===HASH}]'''.replace(
            "HASH", json.dumps(hashlib.sha256((self.inputs / "seed-rows.wl").read_bytes()).hexdigest())),
            files=(("a", output / "core-candidates.wl"), ("calls", output / "tcalc-calls.wl")))
        task = {"schema": "canon-neu/script-input/v1", "task_id": "initial-core-independent",
                "step": "CHECK_CORE", "sector": {"id": 3, "propagator_count": 2},
                "payload": {key: self.payload[key] for key in ("sector_basis", "sector_cut_de")} |
                           {"core_candidates": {"path": str(output / "core-candidates.wl")}}}
        check_input = self.root / "check-input.json"
        check_input.write_text(json.dumps(task))
        check_output = self.outputs / "check"
        code, stdout = self.execute(ROOT / "mma/CheckSectorCore.wls", check_input, check_output)
        self.assertEqual(code, 0, stdout)
        checked = json.loads((check_output / "result.json").read_text())
        self.assertEqual((checked["status"], checked["code"]), ("PASS", "CORE_PASS"), checked)

    def test_multiple_seeds_use_row_count_pairs(self):
        request = (self.inputs / "seed-request.wl").read_text().replace('{"normalized-seed"}',
            '{"normalized-seed","second-seed"}').replace('"derivative_counts" -> {2}',
            '"derivative_counts" -> {1,1}')
        (self.inputs / "seed-request.wl").write_text(request)
        second = '<|"id" -> "second-seed", "full_new_basis_row" -> {0,0,1}, "normalization_evidence" -> ' + self.evidence + '|>'
        (self.inputs / "seed-rows.wl").write_text(self.seed_rows.replace('|>}|>', '|>,' + second + '}|>'))
        _, output = self.run_provider()
        self.algebra_assert('{Length[calls]===1,First[calls]["take_row"]==={{1,1},{2,1}}}',
                            files=(("calls", output / "tcalc-calls.wl"),))

    def bridge_payload(self, *, expression="(d-3)/(1+x) lower + x j1+j2"):
        bridge_path = self.inputs / "bridge.wl"
        bridge_path.write_text('<|"schema" -> "canon-neu/candidate-ibp-bridge/v1",'
            '"family_ref" -> "initial-core-algebra", "basis_ref" -> "full-masters", "variables" -> {x},'
            '"masters" -> {lower,j1,j2}, "candidates" -> {<|"candidate_id" -> "normalized-seed",'
            '"reduced_expression" -> ' + expression + '|>}|>')
        family_path = self.inputs / "family.wl"
        family_path.write_text('<|"schema" -> "canon-neu/prepared-family/v1",'
            '"family_ref" -> "initial-core-algebra", "basis_ref" -> "full-masters",'
            '"variables" -> {x}, "regulator" -> eps, "dimension_rule" -> (d->4-2eps)|>')
        # Dimension substitution is checked exactly; choose normalized row equal to the row fixture.
        bridge_path.write_text(bridge_path.read_text().replace('(d-3)', '(d-3+2eps)'))
        request_path = self.inputs / "seed-request.wl"
        request_path.write_text(request_path.read_text()[:-3] + ', "normalization_evidence" -> '
            '<|"normalized-seed" -> ' + self.evidence + '|>|>\n')
        return {key: value for key, value in self.payload.items() if key != "seed_rows"} | {
            "candidate_ibp_bridge": {"path": str(bridge_path)}, "prepared_family": {"path": str(family_path)}}

    def test_bridge_dimension_rule_preserves_full_lower_row(self):
        payload = self.bridge_payload()
        _, output = self.run_provider(payload=payload)
        self.algebra_assert('{a["method","source_seed_rows"]==={{1/(1+x),x,1}},'
                            'KeyExistsQ[a["method","inputs"],"candidate_ibp_bridge"]}',
                            files=(("a", output / "core-candidates.wl"),))

    def test_bridge_cannot_promote_provisional_candidate_or_unreduced_terms(self):
        payload = self.bridge_payload(expression="lower/(1+x)+x j1+j2+unreduced[1]")
        result, _ = self.run_provider(payload=payload, expected=("ERROR", "INVALID_INPUT"))
        self.assertEqual(result["summary"]["stage"], "bridge_reduction")
        (self.inputs / "bridge.wl").write_text((self.inputs / "bridge.wl").read_text().replace('+unreduced[1]', ''))
        (self.inputs / "seed-request.wl").write_text((self.inputs / "seed-request.wl").read_text().replace(
            '"established"', '"provisional"'))
        self.run_provider(payload=payload, expected=("ERROR", "INVALID_SEED_EVIDENCE"))

    def test_unknown_options_missing_threads_and_hash_change(self):
        self.run_provider(options=self.options | {"unknown": 1}, expected=("ERROR", "INVALID_OPTIONS"))
        self.run_provider(options={k: v for k, v in self.options.items() if k != "threads"},
                          expected=("ERROR", "TOOL_CONFIGURATION"))
        payload = self.payload | {"seed_rows": self.payload["seed_rows"] | {"sha256": "0" * 64}}
        self.run_provider(payload=payload, expected=("ERROR", "INPUT_HASH_MISMATCH"))
        (self.inputs / "normalization-receipt.txt").write_text("changed evidence")
        self.run_provider(expected=("ERROR", "INPUT_HASH_MISMATCH"))

    def test_identity_order_counts_and_mutual_sources_reject_before_tool(self):
        request = (self.inputs / "seed-request.wl").read_text()
        for old, new in (("{j1,j2}", "{j2,j1}"), ('"derivative_counts" -> {2}', '"derivative_counts" -> {1}'),
                         ('{"normalized-seed"}', '{"absent-seed"}')):
            with self.subTest(new=new):
                (self.inputs / "seed-request.wl").write_text(request.replace(old, new))
                _, output = self.run_provider(expected=("ERROR", "INVALID_INPUT"))
                self.assertFalse((output / "tcalc-calls.wl").exists())
        (self.inputs / "seed-request.wl").write_text(request)
        self.run_provider(payload=self.payload | {"candidate_ibp_bridge": {"path": str(self.inputs / "absent")}},
                          expected=("ERROR", "INVALID_INPUT"))

    def test_rank_and_package_degree_failure_never_claim_non_ut(self):
        (self.inputs / "seed-rows.wl").write_text(self.seed_rows.replace('{1/(1+x),x,1}', '{1/(1+x),0,0}'))
        result, output = self.run_provider(expected=("INCONCLUSIVE", "METHOD_EXHAUSTED"))
        self.assertEqual(result["summary"]["stage"], "seed_projection")
        self.assertEqual(result["summary"]["rank"], 0)
        self.assertFalse((output / "tcalc-calls.wl").exists())
        (self.inputs / "seed-rows.wl").write_text(self.seed_rows)
        result, output = self.run_provider(mode="degree", expected=("INCONCLUSIVE", "METHOD_EXHAUSTED"))
        self.assertEqual(result["summary"]["stage"], "tcalc_degree")
        self.assertEqual(result["summary"]["ut_conclusion"], "none")
        self.assertEqual(result["summary"]["diagnostics"]["degree"]["status"], "package_degree_or_normalization_rejection")
        self.algebra_assert('{Length[calls]===1}', files=(("calls", output / "tcalc-calls.wl"),))

    def test_incomplete_reconstruction_timeout_and_failed_epsilon_precheck(self):
        for mode in ("partial", "identity", "corrupt_lower"):
            self.run_provider(mode=mode, expected=("INCONCLUSIVE", "METHOD_EXHAUSTED"))
        result, _ = self.run_provider(options=self.options | {"timeout_seconds": 2}, mode="timeout",
                                      expected=("INCONCLUSIVE", "METHOD_EXHAUSTED"))
        self.assertIn("timeout", result["summary"]["reason"])

    def test_nonlinear_seed_coefficients_and_alphabet_selection(self):
        (self.inputs / "seed-rows.wl").write_text(self.seed_rows.replace('{1/(1+x),x,1}', '{j1,x,1}'))
        self.run_provider(expected=("ERROR", "INVALID_INPUT"))
        (self.inputs / "seed-rows.wl").write_text(self.seed_rows)
        alphabet = self.inputs / "alphabet.wl"
        alphabet.write_text('<|"letters" -> {x,1+x}|>')
        payload = self.payload | {"declared_alphabet": {"path": str(alphabet)}}
        self.run_provider(payload=payload, expected=("ERROR", "INVALID_INPUT"))

        request = (self.inputs / "seed-request.wl").read_text().replace(',\n  "letters" -> {x,1+x}', '')
        (self.inputs / "seed-request.wl").write_text(request)
        self.run_provider(payload=payload)
        alphabet.write_text('<|"letters" -> {x,eps+x}|>')
        self.run_provider(payload=payload, expected=("ERROR", "INVALID_INPUT"))

    def test_harmless_package_message_requires_exact_result_checks(self):
        result, output = self.run_provider(mode="warning")
        self.assertTrue(all(result["summary"]["provider_prechecks"].values()))
        self.algebra_assert('{Length[calls]===1}', files=(("calls", output / "tcalc-calls.wl"),))

    def test_component_input_and_symlink_output_are_untouched(self):
        self.run_provider(output=self.components / "forbidden", expected=None)
        self.run_provider(output=self.inputs / "forbidden", expected=None)
        link = self.root / "component-link"
        link.symlink_to(self.components, target_is_directory=True)
        self.run_provider(output=link / "forbidden", expected=None)

    def test_component_and_input_file_alias_targets_are_protected(self):
        for name, declared in (("component", self.components / "fake-initial.wl"),
                               ("artifact", self.inputs / "seed-rows.wl")):
            with self.subTest(source=name):
                physical = self.root / f"physical-{name}"
                physical.mkdir()
                target = physical / declared.name
                declared.rename(target)
                declared.symlink_to(target)
                before = target.read_bytes()
                self.run_provider(output=physical / "forbidden", expected=None)
                self.assertEqual(target.read_bytes(), before)
                self.assertEqual(set(physical.iterdir()), {target})

    def test_external_evidence_aliases_are_protected_before_invalid_hash_outcome(self):
        evidence_root = self.root / "external-evidence"
        evidence_root.mkdir()
        receipt = evidence_root / "normalization-receipt.txt"
        shutil.copyfile(self.inputs / "normalization-receipt.txt", receipt)
        alias = self.root / "evidence-directory-alias"
        alias.symlink_to(evidence_root, target_is_directory=True)
        original = self.seed_rows.replace('"path" -> "normalization-receipt.txt"',
                                          '"path" -> ' + json.dumps(str(receipt)))
        original_hash = hashlib.sha256(receipt.read_bytes()).hexdigest()
        for bad_hash in (False, True):
            (self.inputs / "seed-rows.wl").write_text(
                original.replace(original_hash, "0" * 64) if bad_hash else original)
            for parent in (evidence_root, alias):
                with self.subTest(invalid_hash=bad_hash, parent=parent.name):
                    output = parent / f"forbidden-{self.counter + 1}"
                    self.run_provider(output=output, expected=None)
                    self.assertEqual(set(evidence_root.iterdir()), {receipt})

    def test_pure_derivative_rank_and_completion_algebra(self):
        self.algebra_assert('''With[{source={lower,j1,j2},current={j1,j2}},
          With[{p=CanonInitialCore`PrepareSeedSystem[{{eps/x,0},{0,2eps/x}},x,
            {{0,1,0}},source,current,{2}]}, {FailureQ[p],p[[2,"stage"]]==="psi_rank",p[[2,"rank"]]===1}]]''')

    @unittest.skipUnless(os.environ.get("CANON_INITIAL_CORE_RUNTIME_OPTIONS"),
                         "opt in with a verified runtime method_options JSON file")
    def test_official_ladder_isomorphic_runtime(self):
        """Native single-thread regression on the official ladder row permutation."""
        options_path = Path(os.environ["CANON_INITIAL_CORE_RUNTIME_OPTIONS"]).resolve()
        options = json.loads(options_path.read_text())
        options["threads"] = 1  # Exercise the empty first training batch in INITIAL 2.1.
        entry = Path(options["package_entry"])
        if not entry.is_absolute():
            entry = (options_path.parent / entry).resolve()
        expected_applied = hashlib.sha256(entry.read_bytes()).hexdigest() == (
            "4b4fe726f45484f31b909dc34eef85d77068b3d6dfaf3404163f8f706fc3888c")
        example = entry.parent / "examples/massless_3L4P"
        prepare = self.outputs / "prepare-official.wls"
        prepare.write_text('''root=INPUT_ROOT;
a=Get[A_PATH]; originalBasis=Get[BASIS_PATH];
permutation=Join[{2,1},Range[3,26]];
r=IdentityMatrix[26][[permutation]];
identity=<|"sector" -> <|"id" -> 1,"propagator_count" -> 10|>,
  "family_id" -> "initial-official-massless-3l4p", "basis_id" -> "official-isomorphic-order",
  "basis" -> originalBasis[[permutation]], "variables" -> {x}, "regulator" -> eps|>;
Put[Join[<|"schema" -> "canon-neu/sector-basis/v1"|>,KeyDrop[identity,{"variables","regulator"}]],root<>"/official-basis.wl"];
Put[Join[<|"schema" -> "canon-neu/sector-cut-de/v1","coefficient_domain" -> "exact-rational-functions",
  "matrices" -> {r.a.Transpose[r]}|>,identity],root<>"/official-cut.wl"];
source=<|"path" -> REFERENCE_PATH,"sha256" -> FileHash[REFERENCE_PATH,"SHA256","HexString"]|>;
evidence=<|"status" -> "established","kind" -> "official-reference",
  "statement" -> "Official INITIAL ladder first UT seed, D=4-2 eps, x=t/s; row 2 in permuted order",
  "source" -> source|>;
Put[Join[<|"schema" -> "canon-neu/initial-seed-rows/v1", "source_basis" -> identity["basis"],
  "seeds" -> {<|"id" -> "official-normalized-seed","full_new_basis_row" -> UnitVector[26,2],
    "normalization_evidence" -> evidence|>}|>,identity],root<>"/official-seeds.wl"];
Put[Join[<|"schema" -> "canon-neu/initial-seed-request/v1","seed_ids" -> {"official-normalized-seed"},
  "derivative_counts" -> {26},"letters" -> {x,1+x}|>,identity],root<>"/official-request.wl"];
Quit[0];
'''.replace("INPUT_ROOT", json.dumps(str(self.inputs)))
            .replace("A_PATH", json.dumps(str(example / "AMatrix_ladder.m")))
            .replace("BASIS_PATH", json.dumps(str(example / "initial_basis_ladder.m")))
            .replace("REFERENCE_PATH", json.dumps(str(example / "TMatrix_ladder_to_UT.m"))))
        code, stdout = self.execute(prepare)
        self.assertEqual(code, 0, stdout)
        payload = {key: {"path": str(self.inputs / name)} for key, name in {
            "sector_basis": "official-basis.wl", "sector_cut_de": "official-cut.wl",
            "seed_rows": "official-seeds.wl", "seed_request": "official-request.wl"}.items()}
        # Resolve every declared component relative to the runtime options file.
        for key in ("package_entry", "finite_flow_package_file", "finite_flow_library"):
            path = Path(options[key])
            options[key] = str(path if path.is_absolute() else (options_path.parent / path).resolve())
        task = {"schema": "canon-neu/script-input/v1", "task_id": "official-isomorphic-core",
                "step": "SEARCH_CORE", "sector": {"id": 1, "propagator_count": 10},
                "payload": payload | {"method_options": options}}
        task_path = self.root / "official-input.json"
        task_path.write_text(json.dumps(task))
        output = self.outputs / "official-provider"
        code, stdout = self.execute(ROOT / "methods/initial/run.wls", task_path, output,
                                    timeout=options["timeout_seconds"] + 30)
        self.assertEqual(code, 0, stdout)
        result = json.loads((output / "result.json").read_text())
        self.assertEqual((result["status"], result["code"]),
                         ("PROVISIONAL", "CANDIDATE_TRANSFORMATION"), result)
        self.algebra_assert('''{a["method","seed_ids"]==={"official-normalized-seed"},
          a["method","take_row"]===1,
          a["method","options","threads"]===1,
          a["method","initial_runtime","adapter","applied"]===EXPECTED_APPLIED,
          a["method","initial_runtime","source","sha256"]===
            FileHash[a["method","components","package_entry","path"],"SHA256","HexString"],
          First[a["candidates"]]["provider_evidence","source_gauge"]===True,
          a["method","source_seed_rows"]==={UnitVector[26,2]}}'''.replace(
              "EXPECTED_APPLIED", "True" if expected_applied else "False"),
          files=(("a", output / "core-candidates.wl"),))
        task["step"] = "CHECK_CORE"
        task["payload"] = {key: payload[key] for key in ("sector_basis", "sector_cut_de")} | {
            "core_candidates": {"path": str(output / "core-candidates.wl")}}
        task_path = self.root / "official-check.json"
        task_path.write_text(json.dumps(task))
        check = self.outputs / "official-check"
        code, stdout = self.execute(ROOT / "mma/CheckSectorCore.wls", task_path, check,
                                    timeout=options["timeout_seconds"])
        self.assertEqual(code, 0, stdout)
        result = json.loads((check / "result.json").read_text())
        self.assertEqual((result["status"], result["code"]), ("PASS", "CORE_PASS"), result)


if __name__ == "__main__":
    unittest.main()
