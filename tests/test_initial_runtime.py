"""INITIAL loading compatibility, source immutability and stream lifetime."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import unittest

import test_initial_core as core


@unittest.skipUnless(core.AVAILABLE, "requires a declared Wolfram runtime")
class InitialRuntimeTest(unittest.TestCase):
    def setUp(self):
        self.host = core.InitialCoreTest("runTest")
        self.host.setUp()

    def tearDown(self):
        self.host.tearDown()

    def execute(self, body):
        script = self.host.outputs / "load-runtime.wls"
        script.write_text('Get[' + json.dumps(str(core.ROOT / "mma/lib/InitialRuntime.wl"))
                          + '];\n' + body + '\nQuit[If[And@@(TrueQ/@checks),0,1]];\n')
        code, stdout = self.host.execute(script)
        self.assertEqual(code, 0, stdout)

    def test_unknown_source_keeps_file_context_relative_loading_and_threads(self):
        entry = self.host.components / "custom.wl"
        neighbor = self.host.components / "relative.wl"
        neighbor.write_text('"relative-value"')
        entry.write_text('BeginPackage["CustomInitialRuntime`"]\n'
                         'call::usage="Custom callable.";\n'
                         'Begin["`Private`"]\n'
                         'source=$InputFileName;\n'
                         'relative=Get[FileNameJoin[{DirectoryName[$InputFileName],"relative.wl"}]];\n'
                         'Options[call]={"NThreads"->1};\n'
                         'call[OptionsPattern[]]:={source,relative,OptionValue["NThreads"]};\n'
                         'End[]\nEndPackage[]\n')
        original = entry.read_bytes()
        self.execute('entry=' + json.dumps(str(entry)) + ''';
r=CanonInitialRuntime`LoadInitial[entry];
checks={AssociationQ[r],r["adapter","applied"]===False,
  r["source","sha256"]===FileHash[entry,"SHA256","HexString"],
  r["adapter","sha256"]===FileHash[r["adapter","path"],"SHA256","HexString"],
  CustomInitialRuntime`call["NThreads"->3]==={entry,"relative-value",3}};
Print[InputForm[checks]];''')
        self.assertEqual(entry.read_bytes(), original)

    def test_missing_source_reports_load_failure(self):
        failed = self.host.components / "returns-failed.wl"
        failed.write_text('$Failed\n')
        self.execute('checks={Quiet[CanonInitialRuntime`LoadInitial['
                     + json.dumps(str(self.host.components / "missing.wl")) + ']]===$Failed, '
                     + 'CanonInitialRuntime`LoadInitial[' + json.dumps(str(failed)) + ']===$Failed};')

    @unittest.skipUnless(os.environ.get("CANON_INITIAL_CORE_RUNTIME_OPTIONS"),
                         "requires the declared native INITIAL/FiniteFlow entries")
    def test_known_source_stream_loading_and_error_abort_cleanup(self):
        options_path = Path(os.environ["CANON_INITIAL_CORE_RUNTIME_OPTIONS"])
        options = json.loads(options_path.read_text())
        def path(key):
            value = Path(options[key])
            return value if value.is_absolute() else (options_path.parent / value).resolve()
        entry = core.ROOT / "external/INITIAL/INITIAL.m"
        original = hashlib.sha256(entry.read_bytes()).hexdigest()
        self.assertEqual(original, "4b4fe726f45484f31b909dc34eef85d77068b3d6dfaf3404163f8f706fc3888c")
        body = 'entry=' + json.dumps(str(entry)) + ';\n'
        body += '$LibraryPath=Prepend[$LibraryPath,' + json.dumps(str(path("finite_flow_library").parent)) + '];\n'
        body += 'Get[' + json.dumps(str(path("finite_flow_package_file"))) + '];\n'
        body += '''before=Streams[];
r=CanonInitialRuntime`LoadInitial[entry];
checks={AssociationQ[r],r["adapter","applied"]===True,
  r["source","sha256"]===FileHash[entry,"SHA256","HexString"],
  Streams[]===before,Length[DownValues[INITIAL`TCalc]]>0,
  Length[DownValues[INITIAL`equStep]]>0};
aborted=CheckAbort[Block[{Get=(Abort[]&)},CanonInitialRuntime`LoadInitial[entry]],"caught"];
checks=Join[checks,{aborted==="caught",Streams[]===before}];
probe::load="Injected package load error.";
failed=Quiet[Block[{Get=(Message[probe::load]&)},CanonInitialRuntime`LoadInitial[entry]]];
checks=Join[checks,{failed===$Failed,Streams[]===before}];
Print[InputForm[checks]];'''
        self.execute(body)
        self.assertEqual(hashlib.sha256(entry.read_bytes()).hexdigest(), original)


if __name__ == "__main__":
    unittest.main()
