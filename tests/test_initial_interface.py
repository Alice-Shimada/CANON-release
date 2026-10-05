"""Explicit INITIAL contracts route by step and retain legacy validation scope."""
from __future__ import annotations

import json
import unittest

import test_initial_core as core
import test_method_cards as cards


@unittest.skipUnless(core.AVAILABLE and cards.KERNEL.is_file(), "requires configured Wolfram runtime")
class InitialInterfaceTest(unittest.TestCase):
    def setUp(self):
        self.seed = core.InitialCoreTest("runTest")
        self.seed.setUp()
        self.legacy = cards.MethodCardIntegrationTest("runTest")
        self.legacy.setUp()

    def tearDown(self):
        self.seed.tearDown()
        self.legacy.tearDown()

    def test_stable_core_entry_and_direct_alias_emit_same_candidate(self):
        main, main_output = self.seed.run_provider()
        alias, alias_output = self.seed.run_provider(entry=core.ROOT / "methods/initial-core/run.wls")
        self.assertEqual(main["summary"]["interface"], alias["summary"]["interface"])
        self.seed.algebra_assert('''With[{a=First[main["candidates"]],b=First[alias["candidates"]]},
          {a["transformation"]===b["transformation"],
           a["full_new_basis_rows"]===b["full_new_basis_rows"],
           a["candidate_id"]===b["candidate_id"]}]''', files=(
            ("main", main_output / "core-candidates.wl"),
            ("alias", alias_output / "core-candidates.wl")))

    def test_failed_core_never_dispatches_official_reference_validation(self):
        result, output = self.seed.run_provider(mode="degree",
                                                expected=("INCONCLUSIVE", "METHOD_EXHAUSTED"))
        self.assertEqual(result["summary"]["interface"]["role"], "core-candidate-provider")
        self.assertEqual(result["summary"]["ut_conclusion"], "none")
        self.assertNotIn("ut_evidence", result["artifacts"])
        self.assertFalse((output / "ut-evidence.wl").exists())

    def test_legacy_payload_cannot_silently_change_a_core_request(self):
        payload = {"candidate": {"family_id": "initial-official-massless-3l4p"}}
        result, _ = self.seed.run_provider(payload=payload, expected=("ERROR", "INVALID_INPUT"))
        self.assertEqual(result["summary"]["interface"]["role"], "core-candidate-provider")

    def test_unsupported_step_rejects_before_creating_output(self):
        task = {"schema": "canon-neu/script-input/v1", "task_id": "invalid-step",
                "step": "CHECK_UT_EVIDENCE", "payload": {}}
        request = self.seed.root / "invalid-step.json"
        request.write_text(json.dumps(task))
        output = self.seed.outputs / "invalid-step"
        code, stdout = self.seed.execute(core.ROOT / "methods/initial/run.wls", request, output)
        self.assertEqual(code, 2, stdout)
        self.assertIn("INVALID_INITIAL_STEP", stdout)
        self.assertFalse(output.exists())

    def checker_rejection_request(self, task_id, options):
        request = self.legacy.run_root / f"{task_id}.json"
        request.write_text(json.dumps({"schema": "canon-neu/script-input/v1",
            "task_id": task_id, "step": "CHECK_UT_EVIDENCE",
            "payload": {"candidate": {}, "checker_options": options}}))
        return request

    def test_checker_rejections_preserve_component_and_reference_directories(self):
        components = self.legacy.run_root / "protected-components"
        components.mkdir()
        references = self.legacy.run_root / "protected-reference"
        references.mkdir()
        reference_alias = self.legacy.run_root / "reference-parent-alias"
        reference_alias.symlink_to(references, target_is_directory=True)
        physical = self.legacy.run_root / "physical-component"
        physical.mkdir()
        initial = physical / "INITIAL.wl"
        initial.write_text("(* Never execute this checker component. *)")
        initial_alias = components / "INITIAL.wl"
        initial_alias.symlink_to(initial)
        options = {"package_entry": str(initial_alias), "reference_directory": str(references)}
        for index, script in enumerate((core.ROOT / "mma/CheckUTEvidence.wls",
                                      core.ROOT / "examples/initial-official-ladder/check.wls")):
            for number, parent in enumerate((components, references, reference_alias, physical)):
                with self.subTest(entry=script, protected_parent=parent.name):
                    task_id = f"checker-protected-{index}-{number}"
                    request = self.checker_rejection_request(task_id, options)
                    output = parent / task_id
                    code, stdout = self.seed.execute(script, request, output)
                    self.assertEqual(code, 2, stdout)
                    self.assertFalse(output.exists())
                    self.assertEqual(initial.read_text(), "(* Never execute this checker component. *)")
        self.assertEqual(set(components.iterdir()), {initial_alias})
        self.assertEqual(set(references.iterdir()), set())
        self.assertEqual(set(physical.iterdir()), {initial})

    def test_checker_requires_new_output_with_existing_parent(self):
        for index, script in enumerate((core.ROOT / "mma/CheckUTEvidence.wls",
                                      core.ROOT / "examples/initial-official-ladder/check.wls")):
            request = self.checker_rejection_request(f"checker-location-{index}", {})
            existing = self.legacy.run_root / f"existing-output-{index}"
            existing.mkdir()
            marker = existing / "untouched.txt"
            marker.write_text("existing caller data")
            missing = self.legacy.run_root / f"missing-parent-{index}" / "output"
            for output in (existing, missing):
                with self.subTest(entry=script, output=output):
                    code, stdout = self.seed.execute(script, request, output)
                    self.assertEqual(code, 2, stdout)
            self.assertEqual(set(existing.iterdir()), {marker})
            self.assertEqual(marker.read_text(), "existing caller data")
            self.assertFalse(missing.parent.exists())

    def test_official_alias_and_example_publish_scoped_compatibility_results(self):
        install = self.legacy.run_root / "interface-components"
        install.mkdir()
        reference = install / "reference"
        reference.mkdir()
        initial = install / "INITIAL.wl"
        binding = install / "FiniteFlow.wl"
        native = install / "native.bin"
        native.write_bytes(b"fixture-only library identity")
        binding.write_text('BeginPackage["FiniteFlow`"]; Begin["`Private`"];\n'
                           f'fflowlib={json.dumps(str(native))}; End[]; EndPackage[];')
        initial.write_text('TCalc[a_,f_,v_,e_,opts___]:=IdentityMatrix[26];\n'
                           'basisChange[a_,t_,v_,opts___]:=a;')
        (reference / "AMatrix_ladder.m").write_text('DiagonalMatrix[Join[{eps/x},ConstantArray[0,25]]]')
        (reference / "initial_basis_ladder.m").write_text(
            'Join[{G[2,{1,1,1,1,1,1,1,1,1,1,-1,0,0,0,0}]},Array[b,25]]')
        (reference / "TMatrix_ladder_to_UT.m").write_text('IdentityMatrix[26]')
        components = dict(zip(cards.INITIAL_COMPONENT_KEYS, map(str, (initial, binding, native, reference))))
        for suffix, script, check_script in (
            ("alias", core.ROOT / "methods/initial/run.wls", core.ROOT / "mma/CheckUTEvidence.wls"),
            ("example", core.ROOT / "examples/initial-official-ladder/run.wls",
             core.ROOT / "examples/initial-official-ladder/check.wls")):
            with self.subTest(entry=suffix):
                provider_id = f"official-{suffix}"
                output = self.legacy.run_root / f"provider-{suffix}"
                result = self.legacy.run_wls(script,
                    self.legacy.initial_provider_input(provider_id, components=components), output)
                interface = result["summary"]["interface"]
                self.assertEqual(interface["role"], "official-reference-validation")
                self.assertEqual(interface["lifecycle"], "compatibility")
                self.assertFalse(interface["core_selection_eligible"])
                self.assertEqual(result["summary"]["workflow_action"], "none")
                self.assertEqual(set(result["artifacts"]), {"ut_evidence"})
                evidence = output / result["artifacts"]["ut_evidence"]["path"]
                checked = self.legacy.run_wls(check_script,
                    self.legacy.initial_checker_input(f"checked-{suffix}", provider_id, evidence, components),
                    self.legacy.run_root / f"checked-{suffix}")
                self.assertEqual(checked["code"], "VERIFIED_EVIDENCE")
                self.assertEqual(checked["summary"]["interface"], interface)

        # Old receipts need no new metadata; policy claims cannot widen the scope.
        for suffix, expression in (
            ("old", 'KeyDrop[original,"interface"]'),
            ("forged-role", 'Append[original,"interface"-><|"role"->"core-candidate-provider",'
             '"core_selection_eligible"->True,"workflow_action"->"SEARCH_CORE"|>]')):
            with self.subTest(metadata=suffix):
                receipt = self.legacy.run_root / f"receipt-{suffix}.wl"
                path = json.dumps(str(receipt))
                self.seed.algebra_assert(
                    f'(Put[{expression},{path}];{{FileType[{path}]===File}})',
                    files=(("original", evidence),))
                checked = self.legacy.run_wls(core.ROOT / "mma/CheckUTEvidence.wls",
                    self.legacy.initial_checker_input(f"metadata-{suffix}", provider_id,
                                                      receipt, components),
                    self.legacy.run_root / f"metadata-{suffix}")
                self.assertEqual(checked["code"], "VERIFIED_EVIDENCE")
                self.assertEqual(checked["summary"]["interface"], interface)


if __name__ == "__main__":
    unittest.main()
