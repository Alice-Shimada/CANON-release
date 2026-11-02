"""Public-entry regression for durable DlogBasis phase evidence, using neutral fixtures."""

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
KERNEL = os.environ.get("CANON_WOLFRAM_KERNEL") or shutil.which("WolframKernel")


@unittest.skipUnless(KERNEL, "requires a WolframKernel; no external scientific packages")
class DlogBasisProgressTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.work = Path(self.temporary.name)
        self.addCleanup(self.temporary.cleanup)
        package = self.work / "provider"
        (package / "Kernel").mkdir(parents=True)
        self.entry = package / "DlogBasis.wl"
        self.entry.write_text(
            'If[Environment["CANON_DLOG_FIXTURE_PAUSE"] === "package_load", Pause[120]];\n'
            'Get[FileNameJoin[{DirectoryName[$InputFileName], "Kernel", "DlogBasis.wl"}]];\n'
        )
        self.implementation = package / "Kernel" / "DlogBasis.wl"
        self.implementation.write_text('''
BeginPackage["DlogBasis`"];
Options[DlogBasisSearch] = {"LoopSpecifications" -> {}, "NumeratorDegreeBound" -> 0,
  "DotDegreeBound" -> 0, "NumeratorPositions" -> Automatic,
  "FiniteFlowPackageFile" -> Automatic, "ResidualBackend" -> "Current",
  "SingularExecutable" -> "Singular"};
DlogBasisSearch[family_, sector_, OptionsPattern[]] := Module[{candidates},
  If[Environment["CANON_DLOG_FIXTURE_PAUSE"] === "dlogbasis_search", Pause[120]];
  candidates = Table[DlogIntegral["neutral", {i, 0}], {i, 1, 3}];
  Export[Environment["CANON_DLOG_FIXTURE_PROBE"], <|
    "generated_count" -> Length[candidates], "sector" -> sector,
    "numerator_bound" -> OptionValue["NumeratorDegreeBound"],
    "dot_bound" -> OptionValue["DotDegreeBound"],
    "numerator_positions" -> ToString[OptionValue["NumeratorPositions"], InputForm]
  |>, "RawJSON"];
  <|"ScientificStatus" -> "NeutralFixture",
    "CandidateCombinations" -> candidates,
    "CandidateLattice" -> <|"CandidateCount" -> 6|>,
    "RepresentedCandidates" -> Range[6],
    "CandidateChartCompleteQ" -> True,
    "AffineFiniteConstantResiduesVerifiedQ" -> False,
    "ConstantLeadingSingularityCertifiedQ" -> False,
    "UniformTranscendentalityCertifiedQ" -> False,
    "CanonicalBasisCertifiedQ" -> False|>
];
EndPackage[];
''')
        (self.work / "family.wl").write_text('''
If[Environment["CANON_DLOG_FIXTURE_PAUSE"] === "family_load", Pause[120]];
<|"Family" -> <|"Propagators" -> {p, q}, "LoopMomenta" -> {k},
  "KinematicVariables" -> {x}|>|>
''')
        (self.work / "prepared.wl").write_text('''
<|"topology" -> "neutral", "variables" -> {CANON`DEData`x},
  "regulator" -> CANON`DEData`eps, "family_data" -> <|"path" -> "family.wl"|>|>
''')
        self.value = {
            "schema": "canon-neu/script-input/v1", "task_id": "T-NEUTRAL-PROGRESS",
            "step": "PROPOSE_INTEGRAL_CANDIDATES", "sector": {"id": 1},
            "payload": {
                "prepared_family": {"path": "prepared.wl"},
                "family_identity": {"family_id": "neutral"},
                "sector_identity": {"id": 1},
                "dimension_policy": {"spacetime_dimension": 4},
                "numerator_or_power_counting_policy": {"definition": {
                    "numerator_degree": 1, "max_added_dots": 2,
                    "max_dots_per_propagator": 2}},
                "candidate_budget": {"maximum": 1, "unit": "PROVIDER_CANDIDATE"},
                "candidate_unit": "NORMALIZED_LINEAR_COMBINATION",
                "normalization_policy": {
                    "convention": "first-integral-coefficient-outside-definition",
                    "factors": {"placement": "normalization.factor"}},
                "method_options": {
                    "package_entry": str(self.entry), "package_revision": "neutral-v1",
                    "finite_flow_package_file": "unused-FiniteFlow.m",
                    "loop_order": [1], "loop_dimensions": [4]}}}
        self.override = self.work / "components.json"
        self.override.write_text(json.dumps({
            "schema": "canon-neu/components/v1", "steps": {
                "PROPOSE_INTEGRAL_CANDIDATES": {
                    "command": [KERNEL, "-noinit", "-noprompt", "-script",
                                str(ROOT / "methods/dlogbasis/run.wls")],
                    "instructions": str(ROOT / "methods/dlogbasis/SKILL.md")}}}))
        self.environment = os.environ.copy()
        for name in ("OMP_NUM_THREADS", "MKL_NUM_THREADS", "OPENBLAS_NUM_THREADS",
                     "NUMEXPR_NUM_THREADS"):
            self.environment[name] = "1"

    def command(self, tag):
        request = self.work / (tag + ".json")
        request.write_text(json.dumps(self.value))
        output = self.work / tag
        selected = json.loads(os.environ.get("CANON_TEST_COMPONENTS", "[]")) or [
            str(ROOT / "components/profiles/custom-kira.json")]
        command = [sys.executable, str(ROOT / "run_step.py"), str(request), str(output)]
        for manifest in [*selected, str(self.override)]:
            command += ["--components", manifest]
        return command, request, output

    def test_family_data_symbols_share_prepared_context(self):
        self.implementation.write_text(self.implementation.read_text().replace(
            'candidates = Table[DlogIntegral["neutral", {i, 0}], {i, 1, 3}];',
            'candidates = Table[First[family["KinematicVariables"]] DlogIntegral["neutral", {i, 0}], {i, 1, 3}];'))
        evidence = []
        for name in ("bare", "foreign"):
            if name == "foreign":
                path = self.work / "family.wl"
                path.write_text(path.read_text().replace('"KinematicVariables" -> {x}',
                                                        '"KinematicVariables" -> {Foreign`x}'))
                path = self.work / "prepared.wl"
                path.write_text(path.read_text().replace('CANON`DEData`x', 'Foreign`x'))
            command, _, output = self.command("context-" + name)
            probe = self.work / (name + "-probe.json")
            environment = dict(self.environment, CANON_DLOG_FIXTURE_PROBE=str(probe))
            completed = subprocess.run(command, cwd=ROOT, env=environment,
                                       capture_output=True, text=True, timeout=30)
            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
            result = json.loads((output / "result.json").read_text())
            self.assertEqual((result["status"], result["code"]),
                             ("PROVISIONAL", "INTEGRAL_CANDIDATES"))
            self.assertEqual(result["summary"]["entry_sha256"], hashlib.sha256(self.entry.read_bytes()).hexdigest())
            self.assertEqual(result["summary"]["candidate_count"], 1)
            self.assertEqual(result["summary"]["available_candidate_count"], 3)
            for key in ("affine_finite_constant_residues_verified",
                        "constant_leading_singularity_certified",
                        "uniform_transcendentality_certified", "canonical_basis_certified"):
                self.assertIs(result["summary"][key], False)
            check = self.work / (name + "-check.wls")
            check.write_text('''
Get[FileNameJoin[{Environment["CANON_DLOG_FIXTURE_CANON"],"mma","lib","MethodCardCore.wl"}]];
{canon, artifactPath, preparedPath, factsPath}=CanonMethodCard`ScriptArguments[];
artifact=CanonMethodCard`ReadWLData[artifactPath]; prepared=CanonMethodCard`ReadWLData[preparedPath];
candidate=First[artifact["candidates"]]; coordinate=First[prepared["variables"]];
facts=<|"prefactor_uses_prepared_variable"->(candidate["normalization","factor"]===coordinate),
  "single_integral_definition"->(ReleaseHold[candidate["exact_definition"]]===CANON`DEData`j[CANON`DEData`neutral,1,0]),
  "not_scientific_acceptance"->(artifact["tool_provenance","tool_revision"]==="neutral-v1")|>;
Export[factsPath,facts,"RawJSON"]; Exit[If[And@@Values[facts],0,1]];
''')
            facts_path = self.work / (name + "-facts.json")
            checked = subprocess.run([KERNEL, "-noinit", "-noprompt", "-script", str(check), str(ROOT),
                str(output / "integral-candidates.wl"), str(self.work / "prepared.wl"), str(facts_path)],
                capture_output=True, text=True, timeout=30,
                env=dict(environment, CANON_DLOG_FIXTURE_CANON=str(ROOT)))
            self.assertEqual(checked.returncode, 0, checked.stdout + checked.stderr)
            evidence.append({"case": name, "status": result["status"], "code": result["code"],
                "summary": result["summary"], "facts": json.loads(facts_path.read_text())})
        if os.environ.get("CANON_TEST_EVIDENCE"):
            Path(os.environ["CANON_TEST_EVIDENCE"]).write_text(json.dumps({
                "scope": "neutral stub DlogBasis provider serialization; no installed search",
                "cases": evidence}, indent=2) + "\n")

    def diagnostic_roundtrip(self, tag, provider_expression, expected_status, expected_code):
        # Replace only the neutral stub's public search, retaining its declared options.
        self.implementation.write_text(self.implementation.read_text() +
            '\nDownValues[DlogBasis`DlogBasisSearch] = {};\n'
            'DlogBasis`DlogBasisSearch[family_, sector_, OptionsPattern[]] := ' +
            provider_expression + ';\n')
        expected = self.work / (tag + '-expected.wl')
        expected.write_text('<|"provider_result" -> ' + provider_expression + '|>\n')
        command, _, output = self.command(tag)
        completed = subprocess.run(command, cwd=ROOT, env=self.environment,
                                   capture_output=True, text=True, timeout=30)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        result = json.loads((output / 'result.json').read_text())
        self.assertEqual((result['status'], result['code']), (expected_status, expected_code))
        descriptor = result['artifacts']['diagnostic']
        self.assertEqual(descriptor['type'], 'mathematica-expression')
        diagnostic = output / descriptor['path']
        self.assertTrue(diagnostic.is_file())
        check = self.work / (tag + '-readback.wls')
        check.write_text('''
Get[FileNameJoin[{Environment["CANON_DLOG_FIXTURE_CANON"],"mma","lib","MethodCardCore.wl"}]];
{artifactPath, expectedPath, factsPath}=CanonMethodCard`ScriptArguments[];
artifact=CanonMethodCard`ReadWLData[artifactPath]; expected=CanonMethodCard`ReadWLData[expectedPath];
actual=artifact["provider_result"]; data=If[FailureQ[actual],actual[[2]],actual];
facts=<|"exact_provider_result"->SameQ[actual,expected["provider_result"]],
  "schema"->(artifact["schema"]==="canon-neu/integral-proposal-diagnostic/v1"),
  "method"->(artifact["method_id"]==="dlogbasis-refine-search"),
  "public_entry"->(artifact["public_entry"]==="DlogBasis`DlogBasisSearch"),
  "revision"->(artifact["tool_provenance","tool_revision"]==="neutral-v1"),
  "entry_hash"->(artifact["tool_provenance","entry_sha256"]===
    FileHash[artifact["tool_provenance","entry"],"SHA256","HexString"]),
  "implementation_hashes"->And@@Map[Function[item,
    item["sha256"]===FileHash[item["path"],"SHA256","HexString"]],
    artifact["tool_provenance","implementation_files"]],
  "absent_fields_preserved"->And@@Map[!KeyExistsQ[data,#]&,
    {"DimensionOnlyNormalization","RemainingVariables","ResidualVariables"}]|>;
Export[factsPath,facts,"RawJSON"]; Exit[If[And@@Values[facts],0,1]];
''')
        facts_path = self.work / (tag + '-facts.json')
        checked = subprocess.run([KERNEL, '-noinit', '-noprompt', '-script', str(check),
            str(diagnostic), str(expected), str(facts_path)],
            capture_output=True, text=True, timeout=30,
            env=dict(self.environment, CANON_DLOG_FIXTURE_CANON=str(ROOT)))
        self.assertEqual(checked.returncode, 0, checked.stdout + checked.stderr)
        if os.environ.get('CANON_TEST_EVIDENCE'):
            evidence_path = Path(os.environ['CANON_TEST_EVIDENCE'])
            evidence_path.with_name(evidence_path.stem + '-' + tag + evidence_path.suffix).write_text(
                json.dumps({'scope': 'neutral stub serialization; no installed search',
                    'case': tag, 'result': result, 'facts': json.loads(facts_path.read_text())},
                    indent=2) + '\n')
        return result

    def test_empty_candidates_preserve_nested_diagnostic(self):
        result = self.diagnostic_roundtrip('empty', r'''
<|"ScientificStatus"->"NeutralUnresolvedCuts", "CandidateCombinations"->{},
  "CandidateLattice"-><|"CandidateCount"->6|>, "RepresentedCandidates"->Range[3],
  "CandidateChartCompleteQ"->False, "AffineFiniteConstantResiduesVerifiedQ"->False,
  "ConstantLeadingSingularityCertifiedQ"->False, "UniformTranscendentalityCertifiedQ"->False,
  "CanonicalBasisCertifiedQ"->False,
  "GeneralizedCuts"->{Failure["NeutralUnsupportedPair",<|
    "UnsupportedBackendData"-><|"backend"->"sentinel",
      "cover"->HoldComplete[NeutralDiagnostics`u^2+2]|>,
    "Nested"->Failure["NeutralInner",<|"payload"->17/23|>]|>]},
  "Opaque"->HoldComplete[NeutralDiagnostics`u^2-5]|>
''', 'INCONCLUSIVE', 'METHOD_EXHAUSTED')
        summary = result['summary']
        self.assertEqual(summary['reason'],
                         'DlogBasisSearch produced no candidates within the requested budget')
        self.assertEqual(summary['candidate_count'], 0)
        self.assertEqual(summary['represented_candidate_count'], 3)
        for key in ('candidate_chart_complete', 'affine_finite_constant_residues_verified',
                    'constant_leading_singularity_certified',
                    'uniform_transcendentality_certified', 'canonical_basis_certified'):
            self.assertIs(summary[key], False)

    def test_direct_failure_preserves_exact_diagnostic(self):
        result = self.diagnostic_roundtrip('failure', r'''
Failure["NeutralSearchFailure",<|"MessageTemplate"->"Neutral provider failure",
  "NestedCut"->Failure["NeutralNestedCut",<|
    "Sentinel"->{1/3,HoldComplete[NeutralDiagnostics`u]}|>],
  "Opaque"->HoldComplete[NeutralDiagnostics`u^2-5]|>]
''', 'ERROR', 'DLOGBASIS_SEARCH_FAILED')
        self.assertEqual(set(result['summary']), {'failure_tag', 'failure', 'entry'})
        self.assertEqual(result['summary']['failure_tag'], 'NeutralSearchFailure')

    def records(self, output):
        path = output / "dlogbasis-progress.jsonl"
        if not path.exists():
            return []
        # A killed append can leave an incomplete final line; prior records remain readable.
        lines = path.read_bytes().splitlines(keepends=True)
        return [json.loads(line) for line in lines if line.endswith(b"\n")]

    def test_interruption_preserves_entered_boundary_without_scientific_result(self):
        for phase in ("package_load", "family_load", "dlogbasis_search"):
            with self.subTest(phase=phase):
                command, request, output = self.command(phase)
                environment = dict(self.environment, CANON_DLOG_FIXTURE_PAUSE=phase)
                process = subprocess.Popen(command, cwd=ROOT, env=environment,
                                           stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                           text=True, start_new_session=True)
                try:
                    deadline = time.monotonic() + 20
                    while time.monotonic() < deadline and process.poll() is None:
                        rows = self.records(output)
                        if any(r["phase"] == phase and r["event"] == "entered" for r in rows):
                            break
                        time.sleep(0.05)
                    if process.poll() is None:
                        os.killpg(process.pid, signal.SIGKILL)
                    stdout, stderr = process.communicate(timeout=10)
                finally:
                    if process.poll() is None:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.communicate()
                rows = self.records(output)
                self.assertTrue(rows, stdout + stderr)
                self.assertEqual((rows[-1]["phase"], rows[-1]["event"]), (phase, "entered"),
                                 stdout + stderr)
                self.assertFalse((output / "result.json").exists())
                self.assertEqual(rows[0]["details"]["request"], self.value)
                self.assertEqual(rows[0]["details"]["input_sha256"],
                                 hashlib.sha256(request.read_bytes()).hexdigest())
                identity = next(r["details"] for r in rows
                                if r["phase"] == "package_load" and r["event"] == "entered")
                self.assertEqual(identity["package_revision"], "neutral-v1")
                self.assertEqual({Path(f["path"]): f["sha256"] for f in identity["implementation_files"]},
                                 {p: hashlib.sha256(p.read_bytes()).hexdigest()
                                  for p in (self.entry, self.implementation)})

    def test_candidate_cap_changes_output_only_after_provider_returns(self):
        probes = []
        for cap in (1, 2):
            self.value["payload"]["candidate_budget"]["maximum"] = cap
            command, _, output = self.command("cap" + str(cap))
            probe = self.work / ("probe" + str(cap) + ".json")
            environment = dict(self.environment, CANON_DLOG_FIXTURE_PROBE=str(probe))
            completed = subprocess.run(command, cwd=ROOT, env=environment,
                                       capture_output=True, text=True, timeout=30)
            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
            result = json.loads((output / "result.json").read_text())
            self.assertEqual((result["status"], result["code"]),
                             ("PROVISIONAL", "INTEGRAL_CANDIDATES"))
            self.assertEqual(result["summary"]["available_candidate_count"], 3)
            self.assertEqual(result["summary"]["candidate_count"], cap)
            self.assertFalse(result["summary"]["uniform_transcendentality_certified"])
            probes.append(json.loads(probe.read_text()))
            rows = self.records(output)
            search = next(r["details"] for r in rows
                          if r["phase"] == "dlogbasis_search" and r["event"] == "entered")
            self.assertEqual(search["expected_lattice_count"], 6)
            self.assertEqual(search["candidate_budget_scope"],
                             "returned_directions_after_provider_return")
            events = [(r["phase"], r["event"]) for r in rows]
            self.assertLess(events.index(("dlogbasis_search", "returned")),
                            events.index(("candidate_conversion", "entered")))
            self.assertEqual(rows[-1]["details"],
                             {"available_candidate_count": 3, "returned_candidate_count": cap})
            readback = self.work / "readback.wls"
            readback.write_text('''
Get[FileNameJoin[{Environment["CANON_DLOG_FIXTURE_CANON"], "mma", "lib", "MethodCardCore.wl"}]];
artifact = CanonMethodCard`ReadWLData[Environment["CANON_DLOG_FIXTURE_ARTIFACT"]];
checks = MapIndexed[Function[{candidate, position},
  candidate["normalization"]["factor"] === 1 &&
  ReleaseHold[candidate["exact_definition"]] ===
    CANON`DEData`j[CANON`DEData`neutral, First[position], 0]
], artifact["candidates"]];
Quit[If[And @@ checks, 0, 1]];
''')
            checked = subprocess.run(
                [KERNEL, "-noinit", "-noprompt", "-script", str(readback)],
                env=dict(self.environment, CANON_DLOG_FIXTURE_CANON=str(ROOT), CANON_DLOG_FIXTURE_ARTIFACT=
                         str(output / "integral-candidates.wl")),
                capture_output=True, text=True, timeout=30)
            self.assertEqual(checked.returncode, 0, checked.stdout + checked.stderr)
        self.assertEqual(probes[0], probes[1])
        self.assertEqual(probes[0]["generated_count"], 3)


if __name__ == "__main__":
    unittest.main()
