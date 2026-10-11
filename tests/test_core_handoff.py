"""A passing core must survive completion beside malformed unused proposals."""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import time
import unittest

import test_core_contract as core


@unittest.skipUnless(core.KERNEL.is_file(), "requires configured Wolfram runtime")
class CoreHandoffTest(unittest.TestCase):
    def setUp(self):
        self.gate = core.CoreContractIntegrationTest("runTest")
        self.gate.setUp()

    def tearDown(self):
        self.gate.tearDown()

    def build_full(self, candidates, *, expected=("PASS", "OK"), core_updates=(),
                   inputs=None, ordered_text=None, accepted_text=None):
        self.gate.run_check({"core_candidates": candidates} | (inputs or {}))
        directory = self.gate.run_root / str(self.gate.counter)
        payload = json.loads((directory / "input.json").read_text())["payload"]
        core_path = directory / "output/core-transform.wl"
        if core_updates:
            text = core_path.read_text()
            for old, new in core_updates:
                self.assertIn(old, text)
                text = text.replace(old, new)
            core_path = directory / "changed-core.wl"
            core_path.write_text(text)
        ordered = directory / "ordered.wl"
        ordered.write_text(ordered_text or '''<|"schema"->"canon-neu/ordered-master-de/v1",
          "family_id"->"fixture-libra-tutorial-1", "basis_id"->"libra-tutorial/full",
          "basis"->{j1,j2},"variables"->{x},"regulator"->eps,
          "matrices"->Get[CUT]["matrices"]|>'''.replace(
              "CUT", json.dumps(str(directory / "sector_cut_de.wl"))))
        payload.update({"ordered_master_de": {"type": "mathematica-expression", "path": str(ordered)},
                        "core_transform": {"type": "mathematica-expression", "path": str(core_path)},
                        "accepted_prefix": None, "declared_alphabet": None})
        if accepted_text:
            accepted = directory / "accepted.wl"
            accepted.write_text(accepted_text)
            payload["accepted_prefix"] = {"type": "mathematica-expression", "path": str(accepted)}
        request = directory / "full-input.json"
        request.write_text(json.dumps({"schema": "canon-neu/script-input/v1", "task_id": "handoff",
                                      "step": "BUILD_FULL_DE", "sector": {"id": 3, "propagator_count": 2},
                                      "payload": payload}))
        output = directory / "full-output"
        completed = subprocess.run([sys.executable, str(core.ROOT / "tests/wolfram_kernel_launcher.py"),
            str(core.KERNEL), "-noinit", "-noprompt", "-script",
            os.environ.get("CANON_TEST_BUILD_FULL_DE_ENTRY",
                           str(core.ROOT / "mma/BuildFullSectorDE.wls")), str(request), str(output)],
            env=os.environ.copy(), capture_output=True, text=True, timeout=60, cwd=core.ROOT)
        time.sleep(2)
        self.assertEqual(completed.returncode, int(expected[0] == "ERROR"),
                         completed.stdout + completed.stderr)
        result = json.loads((output / "result.json").read_text())
        self.assertEqual((result["status"], result["code"]), expected, result)
        return result, output

    def candidates(self, *, malformed=False, wrong_rows=False):
        good = core.CANDIDATE.replace('"construction_rejection" -> None,',
                '"member_candidate_ids" -> {"seed:1", "seed:2"}, "construction_rejection" -> None,')
        if wrong_rows:
            good = good.replace('"full_new_basis_rows" -> {{1, -x}, {0, 1}}',
                                '"full_new_basis_rows" -> IdentityMatrix[2]')
        text = core.CANDIDATES.replace(core.CANDIDATE, good)
        if malformed:
            bad = good.replace('"tutorial:1"', '"unused:bad"').replace(
                '"full_new_basis_rows" -> {{1, -x}, {0, 1}}',
                '"full_new_basis_rows" -> {{1}}')
            text = text.replace(good, good + "," + bad)
            text = text.replace('"declared" -> 1', '"declared" -> 2').replace(
                '"eligible" -> 1', '"eligible" -> 2')
        return text

    def test_unused_malformed_rows_do_not_poison_selected_full_completion(self):
        result, output = self.build_full(self.candidates(malformed=True))
        self.assertEqual(result["summary"]["candidate_ids"], ["tutorial:1"])
        self.assertEqual(result["summary"].get("rejected_completion_ids"), [])
        artifact = " ".join((output / "full-sector-de.wl").read_text().split())
        self.assertNotIn('"unused:bad"', artifact)
        self.assertIn('"first_core_candidate_id" -> "tutorial:1"', artifact)

    def test_unverified_inverse_proposal_cannot_change_checked_core_on_handoff(self):
        result, output = self.build_full(self.candidates(wrong_rows=True),
                                        expected=("ERROR", "INVALID_CORE_COMPLETION"))
        self.assertEqual(result["summary"]["preferred_next_route"], "FIX_INPUT")
        self.assertFalse((output / "full-sector-de.wl").exists())

    def test_core_receipt_must_bind_selected_candidate_identity(self):
        self.build_full(self.candidates(), expected=("ERROR", "INVALID_FULL_DE_INPUT"),
                        core_updates=(( '"candidate_id" -> "tutorial:1"',
                                        '"candidate_id" -> "unrelated:1"'),))

    def test_algebraic_current_rows_preserve_nonzero_normalized_lower_columns(self):
        basis = self.gate.inputs["sector_basis"].replace("{j1, j2}", "{j}")
        cut = self.gate.inputs["sector_cut_de"].replace("{j1, j2}", "{j}")
        cut = cut[:cut.index('"matrices" ->')] + '"matrices" -> {{{(1/2+eps)/x}}}|>'
        candidate = '''<|"candidate_id"->"algebraic:lower", "member_candidate_ids"->{"seed"},
          "construction_rejection"->None,"transformation"->{{Sqrt[x]}},
          "full_new_basis_rows"->{{3,1/Sqrt[x]}},"transformed_matrices"->{{{eps/x}}}|>'''
        candidates = core.CANDIDATES.replace(core.CANDIDATE, candidate).replace(
            '"source_basis" -> {j1, j2}', '"source_basis" -> {lower, j}').replace(
            "{j1, j2}", "{j}").replace('"exact-rational-functions"', '"exact-algebraic-functions"')
        ordered = '''<|"schema"->"canon-neu/ordered-master-de/v1", "family_id"->"fixture-libra-tutorial-1",
          "basis_id"->"full", "basis"->{lower,j}, "variables"->{x},"regulator"->eps,
          "matrices"->{{{(1+eps)/x,0},{0,(1/2+eps)/x}}}|>'''
        accepted = '''<|"schema"->"canon-neu/accepted-prefix/v1", "source_basis"->{lower},
          "family_id"->"fixture-libra-tutorial-1","variables"->{x},"regulator"->eps,
          "basis"->{normalizedLower},"transformation"->{{x}},"prefix_id"->"lower-prefix",
          "matrices"->{{{eps/x}}}|>'''
        result, output = self.build_full(candidates, inputs={"sector_basis": basis,"sector_cut_de": cut},
                                        ordered_text=ordered, accepted_text=accepted)
        self.assertEqual(result["summary"]["rejected_completion_ids"], [])
        assertion = output.parent / "assert-algebraic-lower.wls"
        assertion.write_text('Get['+json.dumps(str(core.ROOT / "mma/lib/MethodCardCore.wl"))+'];\n'
            'full=Get['+json.dumps(str(output / "full-sector-de.wl"))+'];\n'
            '''c=First[full["candidates"]];expectedRows={{1,0},{3 x,1/Sqrt[x]}};
            ok=full["source_basis"]==={normalizedLower,j} &&
              c["candidate_id"]==="algebraic:lower" &&
              CanonMethodCard`ZeroMatrixQ[c["new_basis_rows"]-expectedRows] &&
              CanonMethodCard`ZeroMatrixQ[c["full_transformation"].expectedRows-IdentityMatrix[2]] &&
              CanonMethodCard`ZeroMatrixQ[First[full["source_matrices"]].c["full_transformation"]-
                D[c["full_transformation"],x]-c["full_transformation"].First[c["transformed_matrices"]]];
            Print[InputForm[ok]];Quit[If[TrueQ[ok],0,1]];''')
        p = subprocess.run([sys.executable,str(core.ROOT / "tests/wolfram_kernel_launcher.py"),
            str(core.KERNEL),"-noinit","-noprompt","-script",str(assertion)],
            env=os.environ.copy(),capture_output=True,text=True,timeout=60,cwd=core.ROOT)
        time.sleep(2)
        self.assertEqual(p.returncode,0,p.stdout+p.stderr)


if __name__ == "__main__":
    unittest.main()
