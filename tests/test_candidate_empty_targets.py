#!/usr/bin/env python3
"""Zero and master-only candidate target lists through the public bridge/core gates.

Uses neutral analytic inputs and supplied empty rules; dispatches no reducer.
--readback-only checks retained public outputs without repeating their steps.
"""
import argparse
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys


READBACK = r'''{canon,base}=Rest[$ScriptCommandLine];
Get[FileNameJoin[{canon,"mma","lib","MethodCardCore.wl"}]];
read[name_] := CanonMethodCard`ReadWLData[FileNameJoin[{base,name}]];
masters=read["masters.wl"]["masters"]; coordinate=First[read["family.wl"]["variables"]];
facts=<||>;
Do[
 bridge=read[kind<>"-reduce/candidate-ibp-bridge.wl"];
 targets=read[kind<>"-reduce/reduction-targets.wl"];
 record=First[bridge["candidates"]];
 facts[kind<>"/empty-targets"] = targets["targets"]==={} && bridge["reducer_targets"]==={};
 facts[kind<>"/source-order"] = targets["masters"]===masters && bridge["masters"]===masters;
 facts[kind<>"/candidate-support-and-derivatives"] = (#1["integral"] & /@ record["targets"])===
   If[kind==="zero",{},{First[masters]}] &&
   record["derivatives"]===<|coordinate->0|> && record["reduced_derivatives"]===<|coordinate->0|>;
 bridgePath=CanonMethodCard`WriteWLArtifact[bridge,base,"bridge-"<>CreateUUID[]<>".wl"];
 targetsPath=CanonMethodCard`WriteWLArtifact[targets,base,"targets-"<>CreateUUID[]<>".wl"];
 facts[kind<>"/exact-bridge-roundtrip"] = StringQ[bridgePath] && CanonMethodCard`ReadWLData[bridgePath]===bridge;
 facts[kind<>"/exact-target-roundtrip"] = StringQ[targetsPath] && CanonMethodCard`ReadWLData[targetsPath]===targets,
 {kind,{"zero","master-only"}}];
facts["zero/rank-rejects-zero"] = First[read["zero-reduce/candidate-ibp-bridge.wl"]["candidates"]]["expression"]===0 &&
 read["zero-route/core-candidates.wl"]["reduced_rank"]===0 && read["zero-route/core-candidates.wl"]["candidates"]==={};
facts["master-only/full-source-row"] = First[read["master-only-reduce/candidate-ibp-bridge.wl"]["candidates"]]["expression"]===First[masters] &&
 First[read["master-only-route/core-candidates.wl"]["candidates"]]["full_new_basis_rows"]==={{1,0}};
Export[FileNameJoin[{base,"empty-targets-readback.json"}],facts,"RawJSON"];
Print[InputForm[<|"checks"->Length[facts],"failed"->Keys[Select[facts,!TrueQ[#]&]]|>]];
Exit[If[And@@Values[facts],0,1]];
'''


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--work', required=True, type=Path)
    parser.add_argument('--readback-only', action='store_true')
    args = parser.parse_args()
    canon = Path(os.environ.get('CANON_TEST_SOURCE', Path(__file__).resolve().parents[1]))
    work = args.work.resolve()
    components = json.loads(os.environ['CANON_COMPONENTS'])
    environment = dict(os.environ, CANON_TEST_PUBLIC_CHILD='1')
    fixture = runpy.run_path(str(canon / 'tests/test_candidate_coefficient_binding.py'))

    def run(step, tag, payload, expected):
        request, output = work / (tag + '.json'), work / tag
        request.write_text(json.dumps({'schema': 'canon-neu/script-input/v1', 'task_id': tag,
            'step': step, 'sector': {'id': 1}, 'payload': payload}, indent=2) + '\n')
        command = [sys.executable, str(canon / 'run_step.py'), str(request), str(output)]
        for manifest in components:
            command += ['--components', manifest]
        with (work / (tag + '.log')).open('w') as log:
            process = subprocess.run(command, env=environment, stdout=log, stderr=subprocess.STDOUT)
        result = json.loads((output / 'result.json').read_text())
        assert process.returncode == 0 and (result['status'], result['code']) == expected, result
        cases.append({'case': tag, 'command': command, 'returncode': process.returncode, 'result': result})
        return output

    if args.readback_only:
        cases = json.loads((work / 'receipt.json').read_text())['public_cases']
    else:
        work.mkdir(parents=True)
        inputs = {'family.wl': fixture['FAMILY'], 'masters.wl': fixture['MASTERS'],
            'basis.wl': fixture['BASIS'], 'cut.wl': fixture['CUT'].replace('(eps-1/2)/x', '0'),
            'derivatives.wl': fixture['DERIVATIVES'].replace('"constant"->1', '"constant"->0'),
            'rules.wl': '<|"masters"->{G[1],G[0]},"rules"->{}|>'}
        for name, text in inputs.items():
            (work / name).write_text(text + '\n')
        cases = []
        for kind, factor in [('zero', '0'), ('master-only', '1')]:
            (work / (kind + '.wl')).write_text('<|"proposal_id"->"' + kind + '",'
                '"candidate_pool"-><|"remaining"->0,"pool_exhausted"->True|>,"method_evidence"-><||>,'
                '"tool_provenance"-><|"scope"->"generic zero/empty target fixture"|>,"candidates"->{<|'
                '"candidate_id"->"' + kind + '","normalization"-><|"factor"->' + factor + '|>,'
                '"exact_definition"->HoldComplete[j[neutral,1]]|>}|>\n')
            reduced = run('REDUCE_CANDIDATE_IBP', kind + '-reduce', {
                'integral_candidates': {'path': kind + '.wl'}, 'prepared_family': {'path': 'family.wl'},
                'master_basis': {'path': 'masters.wl'}, 'prepared_derivatives': {'path': 'derivatives.wl'},
                'derivative_operator_selection': 'prepared-affine', 'ibp_reduction': {'path': 'rules.wl'}},
                ('PASS', 'CANDIDATES_REDUCED'))
            assert not (reduced / 'ibp').exists() and not (reduced / 'ibp-input.json').exists()
            routed = run('ROUTE_CORE_CANDIDATES', kind + '-route', {
                'prepared_family': {'path': 'family.wl'}, 'sector_basis': {'path': 'basis.wl'},
                'sector_cut_de': {'path': 'cut.wl'},
                'candidate_ibp_bridge': {'path': str(reduced / 'candidate-ibp-bridge.wl')}},
                ('PROVISIONAL', 'CORE_CANDIDATES_ROUTED'))
            run('CHECK_CORE', kind + '-check', {'sector_basis': {'path': 'basis.wl'},
                'sector_cut_de': {'path': 'cut.wl'}, 'core_candidates': {'path': str(routed / 'core-candidates.wl')}},
                ('FAIL', 'CORE_FAIL') if kind == 'zero' else ('PASS', 'CORE_PASS'))

    expected = {'reduce': ('PASS', 'CANDIDATES_REDUCED'), 'route': ('PROVISIONAL', 'CORE_CANDIDATES_ROUTED')}
    for case in cases:
        tag = case['case']
        status = expected.get(tag.rsplit('-', 1)[-1],
            ('FAIL', 'CORE_FAIL') if tag == 'zero-check' else ('PASS', 'CORE_PASS'))
        result = json.loads((work / tag / 'result.json').read_text())
        assert (result['status'], result['code']) == status, result
    helper = work / 'empty-targets-readback.wls'
    helper.write_text(READBACK)
    runtime = os.environ.get('CANON_WOLFRAMSCRIPT') or shutil.which('wolframscript')
    process = subprocess.run([runtime, '-file', str(helper), str(canon), str(work)],
        env=environment, capture_output=True, text=True)
    (work / 'empty-targets-readback.log').write_text(process.stdout + process.stderr)
    facts = json.loads((work / 'empty-targets-readback.json').read_text())
    receipt = {'public_cases': cases, 'components': components, 'facts': facts,
        'all_pass': process.returncode == 0 and all(facts.values()), 'readback_returncode': process.returncode,
        'public_replay': not args.readback_only, 'native_invocations': 0}
    receipt_name = 'receipt-readback.json' if args.readback_only else 'receipt.json'
    (work / receipt_name).write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'public_cases': len(cases), 'checks': len(facts), 'all_pass': receipt['all_pass']}))
    assert receipt['all_pass'], facts


if __name__ == '__main__':
    main()
