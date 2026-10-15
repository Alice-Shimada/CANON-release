"""Representation tests only. These are not mathematical IBP checks."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import importlib.util
spec = importlib.util.spec_from_file_location("ibp_rule_view", Path(__file__).resolve().parents[1] / "mma/lib/ibp_rule_view.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
create_view, RHS, Unsupported = module.create_view, module.RHS, module.Unsupported


def fixture(rules, *, masters="j[1, 0]", extra=""):
    return ('<|"schema" -> "canon-neu/ibp-reduction/v1", '
            '"family_ref" -> "f", "basis_ref" -> "b", '
            f'"masters" -> {{{masters}}}, "rules" -> {{{rules}}}{extra}|>\n').encode()


def contract(raw, targets=None):
    return {"source_sha256": hashlib.sha256(raw).hexdigest(),
            "family_ref": "f", "basis_ref": "b", "integral_head": "j", "index_count": 2,
            "coefficient_symbols": ["x", "d"], "expected_masters": [[1, 0]],
            "required_targets": [[2, 0]] if targets is None else targets}


class ViewTests(unittest.TestCase):
    def run_view(self, raw, declarations=None, **options):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            source, dest = root / "in.wl", root / "view.wl"
            source.write_bytes(raw)
            try:
                report = create_view(source, declarations or contract(raw), dest, **options)
            except Exception:
                self.assertFalse(dest.exists(), "invalid inputs must not publish a view")
                self.assertEqual([source], list(root.iterdir()), "temporary file leaked")
                raise
            return report, dest.read_bytes()

    def test_selected_bytes_and_all_master_order_preserved(self):
        raw = fixture(" j[2, 0] -> (x^2*j[1, 0])/(1 + d), j[0, 2] -> 0")
        report, view = self.run_view(raw)
        self.assertIn(b" j[2, 0] -> (x^2*j[1, 0])/(1 + d)", view)
        self.assertNotIn(b"j[0, 2]", view)
        self.assertEqual((2, 1), (report["source_rules"], report["selected_rules"]))
        self.assertEqual(hashlib.sha256(view).hexdigest(), report["output_sha256"])

    def test_every_chunk_boundary(self):
        raw = fixture("j[2, 0] -> x*(j[1, 0])/(d-4), j[0, 2] -> 0")
        for size in (1, 2, 3, 7, 23, 128):
            with self.subTest(size=size):
                self.run_view(raw, chunk_bytes=size)

    def test_zero_rule_and_master_identity_need_no_rule(self):
        raw = fixture("j[2, 0] -> 0")
        report, _ = self.run_view(raw, contract(raw, [[1, 0], [2, 0]]))
        self.assertEqual(report["selected_rules"], 1)

    def test_other_head_arity_and_signed_indices(self):
        raw = fixture("FI`k[-1, 2, 0] -> x*FI`k[0, 1, 0]", masters="FI`k[0, 1, 0]")
        declarations = contract(raw, [[-1, 2, 0]])
        declarations.update(integral_head="FI`k", index_count=3, expected_masters=[[0, 1, 0]])
        report, view = self.run_view(raw, declarations, chunk_bytes=7)
        self.assertEqual(report["selected_rules"], 1)
        self.assertIn(b"FI`k[-1, 2, 0]", view)

    def test_empty_rule_list(self):
        raw = fixture("")
        report, _ = self.run_view(raw, contract(raw, [[1, 0]]))
        self.assertEqual(report["selected_rules"], 0)

    def test_missing_target(self):
        with self.assertRaisesRegex(Unsupported, "missing required"):
            self.run_view(fixture("j[0, 2] -> 0"))

    def test_duplicate_unselected_lhs(self):
        with self.assertRaisesRegex(Unsupported, "duplicate rule"):
            self.run_view(fixture("j[0, 2] -> 0, j[2, 0] -> 0, j[0, 2] -> 0"))

    def test_master_redefinition(self):
        with self.assertRaisesRegex(Unsupported, "master redefinition"):
            self.run_view(fixture("j[2, 0] -> 0, j[1, 0] -> j[1, 0]"))

    def test_receipt_or_declared_hash_cannot_cover_changed_source(self):
        raw = fixture("j[2, 0] -> 0")
        declarations = contract(raw)
        with self.assertRaisesRegex(Unsupported, "SHA256 mismatch"):
            self.run_view(raw + b" ", declarations)

    def test_source_basis_identity(self):
        raw = fixture("j[2, 0] -> 0")
        declarations = contract(raw)
        declarations["basis_ref"] = "different"
        with self.assertRaisesRegex(Unsupported, "identity mismatch"):
            self.run_view(raw, declarations)

    def test_source_master_permutation_is_preserved(self):
        raw = fixture("j[2, 0] -> 0", masters="j[0, 1], j[1, 0]")
        declarations = contract(raw)
        declarations["expected_masters"] = [[1, 0], [0, 1]]
        report, view = self.run_view(raw, declarations)
        self.assertIn(b"{j[0, 1], j[1, 0]}", view)
        self.assertEqual(report["masters"], 2)

    def test_broken_export_and_unsupported_payloads(self):
        for raw in [fixture("j[2, 0] -> (x*j[1, 0]"), fixture("j[2, 0] :> 0"),
                    fixture("j[2, 0] -> 0", extra=', "other" -> 1'),
                    fixture("j[2, 0] -> 0,")]:
            with self.subTest(raw=raw), self.assertRaises(Unsupported):
                self.run_view(raw)

    def test_rule_budget(self):
        with self.assertRaisesRegex(Unsupported, "byte budget"):
            self.run_view(fixture("j[2, 0] -> x*j[1, 0]"), max_rule_bytes=10)

    def test_time_budget_leaves_no_partial_view(self):
        with self.assertRaisesRegex(Unsupported, "time budget"):
            self.run_view(fixture("j[2, 0] -> 0"), max_seconds=-1)

    def test_atomic_publication_failure_removes_temporary_file(self):
        with mock.patch.object(module.os, "link", side_effect=OSError("publication interrupted")):
            with self.assertRaisesRegex(OSError, "publication interrupted"):
                self.run_view(fixture("j[2, 0] -> 0"))

    def test_changed_source_during_scan_is_rejected(self):
        original = Path.stat
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            source, dest = root/'in.wl', root/'view.wl'
            raw = fixture("j[2, 0] -> 0")
            source.write_bytes(raw)
            before = original(source)
            after = mock.Mock(st_dev=before.st_dev, st_ino=before.st_ino,
                              st_size=before.st_size, st_mtime_ns=before.st_mtime_ns+1)
            calls = 0

            def changing_stat(path, *args, **kwargs):
                nonlocal calls
                if path == source:
                    calls += 1
                    return before if calls==1 else after
                return original(path, *args, **kwargs)

            with mock.patch.object(Path, "stat", changing_stat):
                with self.assertRaisesRegex(Unsupported, "source changed"):
                    create_view(source, contract(raw), dest)
            self.assertFalse(dest.exists())
            self.assertEqual([source], list(root.iterdir()))

    def test_invalid_independent_integral(self):
        raw = fixture("j[2, 0] -> 0")
        declarations = contract(raw, [[True, 0]])
        with self.assertRaisesRegex(Unsupported, "invalid integral"):
            self.run_view(raw, declarations)

    def test_publish_does_not_overwrite(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            raw = fixture("j[2, 0] -> 0")
            source, dest = root / "in.wl", root / "view.wl"
            source.write_bytes(raw)
            dest.write_bytes(b"retained")
            with self.assertRaises(FileExistsError):
                create_view(source, contract(raw), dest)
            self.assertEqual(dest.read_bytes(), b"retained")

    def test_cli_distinguishes_input_change_from_unsupported_representation(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            source, declaration, view = root/'source.wl', root/'contract.json', root/'view.wl'
            raw = fixture("j[2, 0] -> 0")
            declarations = contract(raw)
            for value, expected in ((raw+b' ', 'INPUT_CHANGED'),
                                    (fixture("j[2, 0] -> Sqrt[x]*j[1,0]"), 'UNSUPPORTED'),
                                    (fixture("j[2, 0] -> 0").replace(b'"f"', b'"\xff"'), 'UNSUPPORTED')):
                with self.subTest(expected=expected, value=value):
                    source.write_bytes(value)
                    declaration.write_text(json.dumps(declarations))
                    p = subprocess.run([sys.executable, module.__file__, str(source), str(declaration), str(view)],
                                       capture_output=True, text=True, timeout=10)
                    self.assertEqual(p.returncode, 0, p.stderr)
                    self.assertEqual(json.loads(p.stdout)['status'], expected)
                    self.assertFalse(view.exists())

    def test_rhs_closed_exact_linear_shapes(self):
        for raw in [b"0", b"j[1,0]", b"x*j[1,0]/(d-4)",
                    b"(x^2+1)*j[1,0] - j[1,0]/(x+1)",
                    b"123456789\\\n0123456789*j[1,0]"]:
            with self.subTest(raw=raw):
                RHS(raw, contract(b"")).check()

    def test_rhs_rejects_unclosed_nonlinear_and_unsupported(self):
        for raw in [b"j[0,1]", b"j[1,0]*j[1,0]", b"1/j[1,0]", b"x+j[1,0]",
                    b"Sqrt[x]*j[1,0]", b"x^(1/2)*j[1,0]", b"1.2*j[1,0]",
                    b"z*j[1,0]", b"1/0*j[1,0]", b"0^-1*j[1,0]",
                    b"Run[\"bad\"]", b"j[1,0]^2", b"I*j[1,0]"]:
            with self.subTest(raw=raw), self.assertRaises(Unsupported):
                RHS(raw, contract(b"")).check()


if __name__ == "__main__":
    unittest.main(verbosity=2)
