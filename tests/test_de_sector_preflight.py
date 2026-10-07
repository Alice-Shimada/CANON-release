#!/usr/bin/env python3
"""Verify sector rejection precedes DE construction and valid public builds survive."""
import argparse
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--canon', type=Path, required=True)
    parser.add_argument('--build-script', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--components', type=Path, action='append', default=[])
    args = parser.parse_args()
    root, script, output = args.canon.resolve(), args.build_script.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    tree = output / 'tree'
    lib = tree / 'mma/lib'
    lib.mkdir(parents=True)
    shutil.copyfile(script, tree / 'mma/BuildSectorCutDE.wls')
    for name in ['MethodCardCore.wl', 'SectorDE.wl', 'method-card']:
        (lib / name).symlink_to((script.parent / 'lib' / name).resolve(), target_is_directory=name == 'method-card')
    marker = output / 'full-build-called.wl'
    (lib / 'DEBuilder.wl').write_text('''BeginPackage["CANON`DEBuilder`"];
BuildDifferentialEquations::usage = "neutral call marker";
BuildDifferentialEquations[args___] := (Put[True, ''' + json.dumps(str(marker)) + ''']; $Failed);
EndPackage[];
''')
    def write(name, value):
        path = output / name
        path.write_text(value)
        return {'type': 'mathematica-expression', 'path': str(path)}
    prepared = write('prepared.wl', '''<|"family_ref" -> "neutral", "basis_ref" -> "neutral-basis",
"parameters" -> {d,x}, "variables" -> {x}, "regulator" -> eps,
"dimension_rule" -> (d -> 4 - 2 eps), "index_order" -> {"D1"}|>\n''')
    basis = write('basis.wl', '<|"family_ref" -> "neutral", "basis_ref" -> "neutral-basis", "masters" -> {f[1]}|>\n')
    sectors = write('sectors.wl', '''<|"family_ref" -> "neutral", "propagator_slots" -> {1},
"sectors" -> {<|"id" -> 1, "propagator_count" -> 1, "sector_bits" -> {1}|>}|>\n''')
    derivatives = write('derivatives.wl', '''<|"schema" -> "canon.prepared-derivatives/v2", "denominator_count" -> 1,
"operators" -> <|x -> {<|"constant" -> 0, "linear" -> {<|"denominator" -> 1, "coefficient" -> d/x|>}|>}|>|>\n''')
    reduction = write('reduction.wl', '<|"masters" -> {f[1]}, "rules" -> {}|>\n')
    manifest = output / 'components.json'
    manifest.write_text(json.dumps({'schema': 'canon-neu/components/v1', 'steps': {'BUILD_CUT_DE': {
        'command': ['{wolframscript}', '-file', str(tree / 'mma/BuildSectorCutDE.wls')],
        'instructions': str(root / 'skills/canon-build-cut-de/SKILL.md')}}}, indent=2) + '\n')
    cases = [('null', None), ('unknown-id', {'id': 2, 'propagator_count': 1}),
             ('wrong-count', {'id': 1, 'propagator_count': 2})]
    records = []
    for name, sector in cases + [('valid-marker', {'id': 1, 'propagator_count': 1}),
                                  ('valid-real', {'id': 1, 'propagator_count': 1})]:
        if name == 'valid-real':
            (lib / 'DEBuilder.wl').unlink()
            (lib / 'DEBuilder.wl').symlink_to((script.parent / 'lib/DEBuilder.wl').resolve())
        if marker.exists():
            marker.unlink()
        request = output / (name + '.json')
        request.write_text(json.dumps({'schema': 'canon-neu/script-input/v1', 'step': 'BUILD_CUT_DE',
            'task_id': 'neutral-sector-preflight', 'sector': sector, 'payload': {
                'prepared_family': prepared, 'master_basis': basis, 'sector_manifest': sectors,
                'prepared_derivatives': derivatives, 'ibp_reduction': reduction}}, indent=2) + '\n')
        destination = output / name
        cmd = [sys.executable, str(root / 'run_step.py'), str(request), str(destination)]
        for selection in args.components + [manifest]:
            cmd += ['--components', str(selection.resolve())]
        started = time.monotonic()
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                                start_new_session=True, env=dict(os.environ, PYTHONDONTWRITEBYTECODE='1'))
        try:
            stdout, _ = proc.communicate(timeout=60)
        except subprocess.TimeoutExpired:
            os.killpg(proc.pid, signal.SIGKILL)
            stdout, _ = proc.communicate()
            (output / (name + '.log')).write_text(stdout)
            raise
        (output / (name + '.log')).write_text(stdout)
        result = json.loads((destination / 'result.json').read_text())
        if name == 'valid-real':
            assert result['status'] == 'PASS' and result['summary']['full_master_count'] == 1, result
        else:
            assert result['status'] == 'ERROR' and result['code'] == 'INVALID_DIFFERENTIAL_EQUATION', result
            assert marker.exists() == (name == 'valid-marker'), name
        records.append({'case': name, 'elapsed_seconds': time.monotonic() - started,
                        'returncode': proc.returncode, 'build_called_marker': marker.exists(), 'result': result})
    receipt = {'all_pass': True, 'checks': records, 'scope': 'neutral sector preflight plus unchanged real exact builder',
               'selected_components': [str(p.resolve()) for p in args.components], 'kernel_concurrency': 1}
    (output / 'evidence.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'all_pass': True, 'cases': len(records), 'evidence': str(output / 'evidence.json')}))


if __name__ == '__main__':
    main()
