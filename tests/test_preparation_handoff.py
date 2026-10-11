#!/usr/bin/env python3
"""Public preparation/discovery/derivative handoff regressions; synthetic data only."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from test_workflow_boundaries import WL, wl


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--canon', required=True, type=Path)
    ap.add_argument('--work', required=True, type=Path)
    ap.add_argument('--observe', action='store_true')
    args = ap.parse_args()
    root, work = args.canon.resolve(), args.work.resolve()
    work.mkdir(parents=True, exist_ok=False)
    records = []

    def artifact(name, value):
        path = work / (name + '.wl')
        path.write_text(wl(value) + '\n')
        return {'path': str(path)}

    def pin(ref):
        return {**ref, 'sha256': hashlib.sha256(Path(ref['path']).read_bytes()).hexdigest()}

    def run(name, step, payload, code, error=False, collision=None, components=(), status=None, exit_code=None):
        destination = work / name
        if collision:
            destination.mkdir()
            (destination / collision).write_text('retained old output\n')
        request = work / (name + '.json')
        request.write_text(json.dumps(dict(schema='canon-neu/script-input/v1', task_id=name,
            step=step, sector={'id': 1, 'propagator_count': 1}, payload=payload)))
        command = [sys.executable, str(root / 'run_step.py'), str(request), str(destination)]
        if components:
            command += [item for component in components for item in ('--components',str(component))]
        else:
            command += ['--defaults']
        p = subprocess.run(command,
            cwd=root, env=os.environ.copy(), capture_output=True, text=True, timeout=60)
        destination.mkdir(exist_ok=True)
        (destination / 'process.log').write_text(p.stdout + p.stderr)
        result_path = destination / 'result.json'
        try:
            result = json.loads(result_path.read_text())
        except (FileNotFoundError, json.JSONDecodeError):
            result = {}
        expected = (status or ('ERROR' if error else 'PASS'), code)
        matched = (result.get('status'), result.get('code')) == expected and p.returncode == (int(error) if exit_code is None else exit_code)
        if error:
            matched = matched and result.get('artifacts') == {}
        if collision:
            matched = matched and (destination / collision).read_text() == 'retained old output\n'
        record = dict(case=name, step=step, expected=list(expected), result=result,
                      returncode=p.returncode, matched=matched)
        records.append(record)
        (work / 'evidence.json').write_text(json.dumps(dict(all_pass=all(r['matched'] for r in records), cases=records), indent=2))
        print(name, result.get('status'), result.get('code'), flush=True)
        if not args.observe:
            assert matched, record
        return {'path': str(destination / 'prepared-family.wl')}

    common = dict(schema='canon-neu/prepared-family/v1', family_ref='handoff', basis_ref='raw',
        topology='B', integral_head='B', parameters=WL('{d,x}'), variables=WL('{x}'), regulator=WL('eps'),
        dimension_rule=WL('(d->4-2eps)'), index_order=['D1'], propagator_slots=[1], sector_convention='positive physical slots')
    derivative = artifact('derivatives', WL('<|"schema"->"canon.prepared-derivatives/v2","denominator_count"->1,"operators"-><|x->{<|"constant"->1,"linear"->{}|>}|>|>'))
    derivative_pin = pin(derivative)
    master_text = work / 'masters.txt'
    master_text.write_text('B[1]\n')
    master_ref = pin({'path': str(master_text)})
    family = artifact('family', {})
    spec = {**common, 'schema':'canon-neu/family-spec/v1', 'family_data':family['path'],
        'prepared_derivatives':derivative['path'], 'ordered_masters':str(master_text)}
    spec_ref = artifact('spec', spec)
    prepared = {**common, 'ordered_masters':master_ref, 'prepared_derivatives':derivative_pin}
    prepared_ref = artifact('prepared', prepared)
    run('prepare-valid', 'PREPARE', {'family_spec':pin(spec_ref)}, 'OK')
    run('prepare-spec-pin', 'PREPARE', {'family_spec':{**spec_ref,'sha256':'0'*64}}, 'SOURCE_HASH_MISMATCH', True)
    run('prepare-missing-source', 'PREPARE', {'family_spec':artifact('missing-spec',{**spec,'family_data':str(work/'absent.wl')})}, 'MISSING_ARTIFACT', True)
    run('prepare-write-collision', 'PREPARE', {'family_spec':spec_ref}, 'ARTIFACT_WRITE_FAILED', True, 'prepared-family.wl')
    run('discover-valid', 'DISCOVER', {'prepared_family':prepared_ref}, 'SECTORS_READY')
    run('discover-prepared-pin', 'DISCOVER', {'prepared_family':{**prepared_ref,'sha256':'0'*64}}, 'SOURCE_HASH_MISMATCH', True)
    run('discover-master-pin', 'DISCOVER', {'prepared_family':artifact('wrong-pin',{**prepared,'ordered_masters':{**master_ref,'sha256':'0'*64}})}, 'SOURCE_HASH_MISMATCH', True)
    run('discover-write-collision', 'DISCOVER', {'prepared_family':prepared_ref}, 'ARTIFACT_WRITE_FAILED', True, 'master-basis.wl')
    for name, text in [('duplicate','B[1]\nB[1]\n'), ('arity','B[1,2]\n'),
                       ('noninteger','B[1/2]\n'), ('mixed-head','B[1]\nC[2]\n'), ('syntax','B[\n')]:
        p = work / (name + '.txt'); p.write_text(text)
        source = {**prepared,'ordered_masters':pin({'path':str(p)})}
        run('discover-'+name,'DISCOVER',{'prepared_family':artifact(name,source)},'INVALID_MASTER_SOURCE',True)
    masters = artifact('basis',dict(family_ref='handoff',basis_ref='raw',masters=WL('{B[1]}')))
    sectors = artifact('sectors',dict(family_ref='handoff',propagator_slots=[1],sectors=[dict(id=1,propagator_count=1,sector_bits=[1])]))
    reduction = artifact('reduction',WL('<|"masters"->{B[1]},"rules"->{B[2]->eps/x B[1]}|>'))
    mapped_derivative = artifact('mapped-derivatives',WL(Path(derivative['path']).read_text().replace('x->','Source`sx->')))
    mapped_spec = artifact('mapped-spec',{**spec,'prepared_derivatives':mapped_derivative['path'],
        'operator_source_symbol_map':{'Source`sx':'x'}})
    mapped_prepared = run('prepare-symbol-map','PREPARE',{'family_spec':mapped_spec},'OK')
    run('targets-through-prepared-map','PREPARE_REDUCTION_TARGETS',dict(prepared_family=mapped_prepared,
        master_basis=masters),'REDUCTION_TARGETS_READY')
    for step in ['PREPARE_REDUCTION_TARGETS','BUILD_CUT_DE']:
        label = 'targets' if step=='PREPARE_REDUCTION_TARGETS' else 'build'
        payload = dict(prepared_family=prepared_ref,master_basis=masters)
        if step=='BUILD_CUT_DE':
            payload.update(sector_manifest=sectors,ibp_reduction=reduction)
        code = 'REDUCTION_TARGETS_READY' if label=='targets' else 'OK'
        run(label+'-embedded-valid',step,payload,code)
        run(label+'-explicit-valid',step,{**payload,'prepared_derivatives':derivative_pin},code)
        wrong_embedded=artifact(label+'-bad-embedded',{**prepared,'prepared_derivatives':{**derivative_pin,'sha256':'0'*64}})
        run(label+'-embedded-pin',step,{**payload,'prepared_family':wrong_embedded},'SOURCE_HASH_MISMATCH',True)
        run(label+'-explicit-pin',step,{**payload,'prepared_derivatives':{**derivative_pin,'sha256':'0'*64}},'SOURCE_HASH_MISMATCH',True)
        run(label+'-explicit-overrides-embedded',step,{**payload,'prepared_family':wrong_embedded,'prepared_derivatives':derivative_pin},code)
        # This is changed content, not merely an invented checksum.
        changed=artifact(label+'-changed',WL(Path(derivative['path']).read_text().replace('"constant"->1','"constant"->2')))
        run(label+'-changed-source',step,{**payload,'prepared_derivatives':{**changed,'sha256':derivative_pin['sha256']}},'SOURCE_HASH_MISMATCH',True)

    scalar_spec = root/'components/parameterization/examples/scalar-spec.wl'
    parameterization = [root/'components/parameterization/components.json']
    for label, digest, expected in [('valid',master_ref['sha256'],'PARAMETERIZATION_READY'),('invalid','0'*64,'SOURCE_HASH_MISMATCH')]:
        value = WL('Join[Get['+wl(str(scalar_spec))+'],<|"ordered_masters"->'+wl({**master_ref,'sha256':digest})+'|>]')
        run('parameterization-master-pin-'+label,'PREPARE',{'family_spec':artifact('parameter-'+label,value)},expected,
            error=label=='invalid',components=parameterization,status='FAIL' if label=='invalid' else 'PASS')

    # Existing analytic scalar family, no new physical family or native IBP.
    physical = WL('Get['+wl(str(root/'components/parameterization/Parameterization.wl'))+'];'
        'CanonParameterization`ParameterizeFamily[Get['+wl(str(scalar_spec))+']]["family"]')
    physical_ref = artifact('physical-family',physical)
    run('physical-valid','PREPARE_DERIVATIVES',{'family_data':physical_ref},'PHYSICAL_DERIVATIVES_READY')
    run('physical-write-collision','PREPARE_DERIVATIVES',{'family_data':physical_ref},'ARTIFACT_WRITE_FAILED',
        True,'prepared-derivatives.wl',status='FAIL')

    # A mismatching hash must be rejected before loading a substitute provider.
    marker = work/'provider-loaded.txt'
    provider = work/'provider.wl'
    provider.write_text('Export['+wl(str(marker))+',"loaded","Text"];Quit[71];')
    for label, role in [('prepared','prepared_family'),('family','family_data')]:
        value = {**prepared,'family_data':pin(family)}
        if role=='family_data':value['family_data']['sha256']='0'*64
        ref = artifact('dlog-'+label,value)
        if role=='prepared_family':ref['sha256']='0'*64
        run('dlog-'+label+'-pin','PROPOSE_INTEGRAL_CANDIDATES',dict(prepared_family=ref,
            method_options={'package_entry':str(provider)}),'SOURCE_HASH_MISMATCH',True,exit_code=0)
        if not args.observe:assert not marker.exists()
    print(json.dumps({'cases':len(records),'matched':sum(r['matched'] for r in records)}))


if __name__ == '__main__':
    main()
