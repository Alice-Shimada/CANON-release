#!/usr/bin/env python3
"""Public-step regression for object binding, exact domains and prefix handoff.

Synthetic algebra only; never starts a native reducer or touches research state.
"""
import argparse
import copy
import json
import os
from pathlib import Path
import subprocess
import sys


class WL(str):
    pass


def wl(value):
    if isinstance(value, WL):
        return str(value)
    if value is None:
        return 'Null'
    if isinstance(value, bool):
        return 'True' if value else 'False'
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, dict):
        return '<|' + ','.join(wl(k)+'->'+wl(v) for k, v in value.items()) + '|>'
    if isinstance(value, list):
        return '{' + ','.join(map(wl, value)) + '}'
    return str(value)


def sealed(value):
    return WL('With[{p='+wl(value)+'},Join[<|"prefix_id"->"sha256:"<>Hash[p,"SHA256","HexString"]|>,p]]')


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--canon', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    args = ap.parse_args()
    root, out = args.canon.resolve(), args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    records = []

    def artifact(name, value):
        p = out/(name+'.wl')
        p.write_text(wl(value)+'\n')
        return {'path': str(p)}

    def run(name, step, payload, expected=('PASS', 'OK'), sector=None, method=None):
        request = out/(name+'.json')
        destination = out/name
        request.write_text(json.dumps(dict(schema='canon-neu/script-input/v1', task_id=name,
            step=step, sector=sector, payload=payload), indent=2))
        command = [sys.executable, str(root/'run_step.py'), '--defaults', str(request), str(destination)]
        if method:command += ['--method',method]
        p = subprocess.run(command,
                           env=os.environ.copy(), capture_output=True, text=True, timeout=120)
        destination.mkdir(exist_ok=True)
        (destination/'process.log').write_text(p.stdout+p.stderr)
        path = destination/'result.json'
        result = json.loads(path.read_text()) if path.exists() else {}
        record = dict(case=name, step=step, returncode=p.returncode, expected=list(expected), result=result)
        records.append(record)
        (out/'evidence.json').write_text(json.dumps({'cases': records, 'all_pass': False}, indent=2))
        actual = (result.get('status'), result.get('code'))
        assert actual == expected, record
        assert p.returncode == (1 if expected[0]=='ERROR' else 0), record
        print(name, *actual, flush=True)
        return result, destination

    def result_ref(result, dest, key):
        return {'path': str(dest/result['artifacts'][key]['path'])}

    x, eps, l, j, k, h = map(WL, ['x','eps','l','j','k','h'])
    sector0 = dict(id=1, propagator_count=1)
    sector = dict(id=3, propagator_count=2)
    base = dict(schema='canon-neu/sector-basis/v1', sector=sector, family_id='boundary', basis_id='raw/3', basis=[j,k])
    cut = {**base, 'schema':'canon-neu/sector-cut-de/v1', 'coefficient_domain':'exact-rational-functions',
           'variables':[x], 'regulator':eps, 'matrices':[WL('{{eps/x,0},{0,eps/(1-x)}}')], 'sector_boundaries':[[1,2]]}
    candidate = dict(candidate_id='selected', member_candidate_ids=['j','k'], construction_rejection=WL('None'),
        transformation=WL('DiagonalMatrix[{2,3}]'), transformed_matrices=cut['matrices'],
        full_new_basis_rows=WL('{{0,1/2,0,0},{0,0,1/3,0}}'))
    pool = {key:cut[key] for key in ('sector','family_id','basis_id','basis','variables','regulator')}
    pool.update(schema='canon-neu/core-candidates/v1', coefficient_domain='exact-algebraic-functions',
        convention='old_basis = transformation . new_basis', source_basis=[l,j,k,h], method={'id':'fixture'},
        candidate_group_pool=dict(declared=1, eligible=1, remaining=0, pool_exhausted=True), candidates=[candidate])
    base_ref, cut_ref, pool_ref = artifact('basis',base), artifact('cut',cut), artifact('pool',pool)
    core_payload=dict(sector_basis=base_ref, sector_cut_de=cut_ref, core_candidates=pool_ref)
    core_result, core_dir = run('core-good','CHECK_CORE',core_payload,('PASS','CORE_PASS'),sector)
    core_ref = result_ref(core_result,core_dir,'core_transform')
    reversed_sector=dict(reversed(list(sector.items())))
    reversed_pool={**pool,'sector':reversed_sector}
    run('core-record-key-order','CHECK_CORE',{**core_payload,'core_candidates':artifact('reversed-sector-pool',reversed_pool)},
        ('PASS','CORE_PASS'),reversed_sector)
    backend=out/'AbortedCANONICA.wl'
    backend.write_text('BeginPackage["CANONICA`"];CANONICA`RecursivelyTransformSectors;CANONICA`ExtractIrreducibles;CANONICA`CheckEpsForm;CANONICA`SectorBoundariesFromDE;'
        'CANONICA`RecursivelyTransformSectors[___]:=Abort[];EndPackage[];')
    run('canonica-interruption','SEARCH_CORE',dict(sector_basis=base_ref,sector_cut_de=cut_ref,
        method_options={'package_entry':str(backend)}),('ERROR','EXECUTION_INTERRUPTED'),sector,'canonica')
    for field, value in [('family_id','other'),('basis_id','other'),('basis',[k,j]),('variables',[WL('y')]),('regulator',WL('eta')),('sector',sector0)]:
        changed=copy.deepcopy(pool);changed[field]=value
        run('core-mismatch-'+field,'CHECK_CORE',{**core_payload,'core_candidates':artifact('mismatch-'+field,changed)},
            ('ERROR','INVALID_INPUT'),sector)
    run('core-mismatch-basis-artifact','CHECK_CORE',{**core_payload,'sector_basis':artifact('reordered-basis',{**base,'basis':[k,j]})},
        ('ERROR','INVALID_INPUT'),sector)
    for name, transform, matrices in [('shape',WL('{{1}}'),cut['matrices']),
            ('inexact',WL('DiagonalMatrix[{1.,1}]'),cut['matrices']),
            ('transcendental',WL('DiagonalMatrix[{Sin[x],1}]'),cut['matrices']),
            ('missing-direction',candidate['transformation'],[])]:
        changed=copy.deepcopy(pool);changed['candidates'][0].update(transformation=transform,transformed_matrices=matrices)
        run('core-'+name,'CHECK_CORE',{**core_payload,'core_candidates':artifact('pool-'+name,changed)},('ERROR','INVALID_INPUT'),sector)
    for name, transform in [('algebraic',WL('DiagonalMatrix[{Sqrt[2],1}]')),('epsilon-singular',WL('DiagonalMatrix[{1/eps,eps}]'))]:
        changed=copy.deepcopy(pool);changed['candidates'][0]['transformation']=transform
        run('core-'+name,'CHECK_CORE',{**core_payload,'core_candidates':artifact('pool-'+name,changed)},('PASS','CORE_PASS'),sector)
    bad_pool=copy.deepcopy(pool);bad_pool['candidate_group_pool']['eligible']=2
    run('core-pool-count','CHECK_CORE',{**core_payload,'core_candidates':artifact('pool-count',bad_pool)},('ERROR','INVALID_INPUT'),sector)

    trace0=[dict(sector=sector0,current_basis_id='raw/1',candidate_id='lower',member_candidate_ids=['l'],method='fixture')]
    lower=dict(schema='canon-neu/accepted-prefix/v1',family_id='boundary',source_basis=[l],basis=[l],
        transformation=[[1]],variables=[x],regulator=eps,alphabet=[x],matrices=[WL('{{eps/x}}')],
        sector_trace=[sector0],candidate_trace=trace0,convention='old_source_basis = transformation . accepted_basis')
    lower_ref=artifact('lower',sealed(lower))
    ordered=dict(schema='canon-neu/ordered-master-de/v1',family_id='boundary',basis_id='raw',basis=[l,j,k,h],
        variables=[x],regulator=eps,coefficient_domain='exact-rational-functions',
        matrices=[WL('DiagonalMatrix[{eps/x,eps/x,eps/(1-x),eps/(1+x)}]')])
    ordered_ref=artifact('ordered',ordered)
    full_payload=dict(ordered_master_de=ordered_ref,sector_cut_de=cut_ref,core_candidates=pool_ref,core_transform=core_ref,
                      accepted_prefix=lower_ref,declared_alphabet=artifact('alphabet',{'letters':[x,WL('1-x')]}))
    full_result,full_dir=run('full-good','BUILD_FULL_DE',full_payload,sector=sector)
    full_ref=result_ref(full_result,full_dir,'full_sector_de')
    for name,prefix in [('missing',{'path':str(out/'missing-prefix.wl')}),
                        ('wrong-type',artifact('wrong-prefix-type',WL('{}')))]:
        result,dest=run('full-invalid-prefix-'+name,'BUILD_FULL_DE',
            {**full_payload,'accepted_prefix':prefix},('ERROR','INVALID_FULL_DE_INPUT'),sector)
        assert result['artifacts']=={} and (dest/'process.log').stat().st_size < 16384
    eager=copy.deepcopy(pool);eager['candidates'].append({**candidate,'candidate_id':'unused','full_new_basis_rows':[[1]]})
    eager_ref=artifact('unused-alternative',eager)
    run('full-skips-unused-completion','BUILD_FULL_DE',{**full_payload,'core_candidates':eager_ref},sector=sector)
    run('full-explicit-pool-validates-all','BUILD_FULL_DE',{**full_payload,'core_candidates':eager_ref,'complete_candidate_pool':True},
        ('ERROR','INVALID_FULL_DE_INPUT'),sector)
    changed=copy.deepcopy(pool);changed['candidates'][0]['full_new_basis_rows']=WL('{{0,1/2,0,1},{0,0,1/3,0}}')
    run('full-no-discarded-higher-master','BUILD_FULL_DE',{**full_payload,'core_candidates':artifact('outside-prefix',changed)},
        ('ERROR','INVALID_FULL_DE_INPUT'),sector)
    changed=copy.deepcopy(pool);changed['candidates'][0]['full_new_basis_rows']=WL('{{0,1,0,0},{0,0,1,0}}')
    run('full-binds-checked-cut-rows','BUILD_FULL_DE',{**full_payload,'core_candidates':artifact('wrong-full-rows',changed)},
        ('ERROR','INVALID_CORE_COMPLETION'),sector)
    changed={**ordered,'matrices':[WL('{{eps/x,0,0,1},{0,eps/x,0,0},{0,0,eps/(1-x),0},{0,0,0,eps/(1+x)}}')]}
    run('full-no-discarded-higher-coupling','BUILD_FULL_DE',{**full_payload,'ordered_master_de':artifact('unclosed-ordered',changed)},
        ('ERROR','INVALID_FULL_DE_INPUT'),sector)

    run('full-record-key-order','BUILD_FULL_DE',full_payload,sector=reversed_sector)
    tail_result,tail_dir=run('tail-good','SOLVE_TAIL',dict(full_sector_de=full_ref,core_transform=core_ref),('PASS','TAIL_READY'),sector)
    trans_ref=result_ref(tail_result,tail_dir,'sector_transform')
    run('tail-record-key-order','SOLVE_TAIL',dict(full_sector_de=full_ref,core_transform=core_ref),('PASS','TAIL_READY'),reversed_sector)
    canonical_payload=dict(full_sector_de=full_ref,sector_transform=trans_ref)
    can_result,can_dir=run('canonical-good','CHECK_CANONICAL',canonical_payload,('PASS','CANONICAL_PASS'),sector)
    can_ref=result_ref(can_result,can_dir,'canonical_sector_de')
    run('canonical-record-key-order','CHECK_CANONICAL',canonical_payload,('PASS','CANONICAL_PASS'),reversed_sector)
    def changed_artifact(name, source, updates, seal=False):
        expression='Join[Get['+wl(source['path'])+'],'+wl(updates)+']'
        return artifact(name,sealed(WL('KeyDrop['+expression+',"prefix_id"]')) if seal else WL(expression))
    for name,updates in [('identity',{'family_id':'other'}),('order',{'source_basis':[j,l,k]}),
                        ('empty-directions',{'transformed_matrices':[]}),('singular',{'transformation':WL('ConstantArray[0,{3,3}]')})]:
        r=changed_artifact('transform-'+name,trans_ref,updates)
        run('canonical-'+name,'CHECK_CANONICAL',{**canonical_payload,'sector_transform':r},('ERROR','INVALID_CANONICAL_INPUT'),sector)
    commit_payload=dict(previous_accepted_prefix=lower_ref,sector_basis=base_ref,sector_transform=trans_ref,canonical_sector_de=can_ref)
    commit_result,commit_dir=run('commit-good','COMMIT_SECTOR',commit_payload,sector=sector)
    accepted_ref=result_ref(commit_result,commit_dir,'accepted_prefix')
    run('commit-record-key-order','COMMIT_SECTOR',commit_payload,sector=reversed_sector)
    for name,updates in [('unchecked',{'full_checks':{}}),('other-transform',{'transformation':WL('IdentityMatrix[3]')}),('other-prefix',{'accepted_prefix_id':'other'})]:
        r=changed_artifact('canonical-'+name,can_ref,updates)
        run('commit-'+name,'COMMIT_SECTOR',{**commit_payload,'canonical_sector_de':r},('ERROR','INVALID_COMMIT_INPUT'),sector)
    manifest_ref=artifact('manifest',dict(schema='canon-neu/sector-manifest/v1',family_ref='boundary',sectors=[sector0,sector]))
    run('cursor-good','NEXT_SECTOR',dict(sector_manifest=manifest_ref,accepted_prefix=accepted_ref))
    for name,trace in [('wrong-order',[sector,sector0]),('duplicate',[sector0,sector0]),('overflow',[sector0,sector,dict(id=7,propagator_count=3)])]:
        r=changed_artifact('trace-'+name,accepted_ref,{'sector_trace':trace},True)
        run('cursor-'+name,'NEXT_SECTOR',dict(sector_manifest=manifest_ref,accepted_prefix=r),('ERROR','INVALID_SECTOR_TRACE'))
    final_ordered={**ordered,'basis':[l,j,k],'matrices':[WL('DiagonalMatrix[{eps/x,eps/x,eps/(1-x)}]')]}
    final_payload=dict(prepared_family=artifact('prepared',dict(schema='canon-neu/prepared-family/v1',family_ref='boundary',basis_ref='raw',variables=[x],regulator=eps)),
        master_basis=artifact('masters',dict(schema='canon-neu/master-basis/v1',family_ref='boundary',basis_ref='raw',masters=[l,j,k])),
        sector_manifest=manifest_ref,ordered_master_de=artifact('final-ordered',final_ordered),accepted_prefix=accepted_ref)
    run('final-good','FINAL_CHECK',final_payload,('PASS','ALL_PASS'))
    reversed_trace=[dict(reversed(list(s.items()))) for s in (sector0,sector)]
    ordered_keys=changed_artifact('reversed-trace-keys',accepted_ref,{'sector_trace':reversed_trace},True)
    run('cursor-record-key-order','NEXT_SECTOR',dict(sector_manifest=manifest_ref,accepted_prefix=ordered_keys))
    run('final-record-key-order','FINAL_CHECK',{**final_payload,'accepted_prefix':ordered_keys},('PASS','ALL_PASS'))
    wrong=changed_artifact('wrong-basis',accepted_ref,{'basis':[l,j,k]},True)
    run('final-basis-definition','FINAL_CHECK',{**final_payload,'accepted_prefix':wrong},('FAIL','FULL_SYSTEM_FAIL'))
    singular=changed_artifact('singular-prefix',accepted_ref,{'transformation':WL('ConstantArray[0,{3,3}]')},True)
    run('final-singular','FINAL_CHECK',{**final_payload,'accepted_prefix':singular},('FAIL','FULL_SYSTEM_FAIL'))
    for name,updates in [('matrix-shape',{'matrices':[]}),('inexact',{'matrices':[WL('DiagonalMatrix[{1.0 eps/x,eps/x,eps/(1-x)}]')]})]:
        r=changed_artifact('prefix-'+name,accepted_ref,updates,True)
        run('final-'+name,'FINAL_CHECK',{**final_payload,'accepted_prefix':r},('ERROR','INVALID_FINAL_INPUT'))
    run('final-unknown-backend','FINAL_CHECK',{**final_payload,'method_options':{'gauge_backend':'typo'}},('ERROR','INVALID_FINAL_INPUT'))
    scale_full=dict(schema='canon-neu/full-prefix-candidates/v1',family_id='scale-fixture',sector=sector,
        current_basis_id='scale',accepted_prefix_id='lower',source_basis=[l,j],variables=[x],regulator=eps,
        alphabet=[x],convention='old_prefix_basis = full_transformation . candidate_prefix_basis',block_boundaries=dict(lower_dimension=1,current_dimension=1),
        source_matrices=[WL('{{0,0},{1/(eps^3*x),0}}')],candidates=[dict(candidate_id='scale',member_candidate_ids=['scale'],
            full_transformation=WL('IdentityMatrix[2]'),new_basis_rows=WL('IdentityMatrix[2]'),transformed_matrices=[WL('{{0,0},{1/(eps^3*x),0}}')])])
    sf=artifact('scale-full',scale_full)
    scale_core=dict(schema='canon-neu/core-transform/v1',candidate_id='scale',basis_id='scale',basis=[j],
        family_id='scale-fixture',sector=sector,variables=[x],regulator=eps,checks={'pass':True})
    result,dest=run('tail-epsilon-normalization','SOLVE_TAIL',dict(full_sector_de=sf,core_transform=artifact('scale-core',scale_core),
        method_options={'package_entry':str(out/'nonexistent-backend.m')}),('PASS','TAIL_READY'),sector)
    assert result['summary']['method']=='epsilon-tail-normalization',result
    run('tail-epsilon-independent-check','CHECK_CANONICAL',dict(full_sector_de=sf,sector_transform=result_ref(result,dest,'sector_transform')),('PASS','CANONICAL_PASS'),sector)
    run('tail-missing-candidate','SOLVE_TAIL',dict(full_sector_de=sf,
        core_transform=artifact('missing-core',{**scale_core,'candidate_id':'absent'})),('ERROR','INVALID_TAIL_INPUT'),sector)
    malformed=copy.deepcopy(scale_full);malformed['candidates'] *= 2
    run('tail-duplicate-candidate','SOLVE_TAIL',dict(full_sector_de=artifact('duplicate-tail',malformed),
        core_transform=artifact('duplicate-core',scale_core)),('ERROR','INVALID_TAIL_INPUT'),sector)
    run('tail-wrong-core-family','SOLVE_TAIL',dict(full_sector_de=sf,
        core_transform=artifact('wrong-tail-core',{**scale_core,'family_id':'other'})),('ERROR','INVALID_TAIL_INPUT'),sector)
    run('tail-missing-direction','SOLVE_TAIL',dict(full_sector_de=artifact('bad-tail-matrices',{**scale_full,'source_matrices':[]}),
        core_transform=artifact('bad-tail-core',scale_core)),('ERROR','INVALID_TAIL_INPUT'),sector)
    nonlinear=copy.deepcopy(scale_full)
    nonlinear['source_matrices']=[WL('{{0,0},{1/(1+eps*x)^2,0}}')]
    nonlinear['candidates'][0]['transformed_matrices']=nonlinear['source_matrices']
    nf=artifact('nonlinear-tail',nonlinear);nc=artifact('nonlinear-core',scale_core)
    run('tail-missing-backend','SOLVE_TAIL',dict(full_sector_de=nf,core_transform=nc,
        method_options={'package_entry':str(out/'absent.m')}),('ERROR','TOOL_UNAVAILABLE'),sector)
    unavailable=out/'MissingTailInterface.m';unavailable.write_text('Null;')
    run('tail-invalid-backend-interface','SOLVE_TAIL',dict(full_sector_de=nf,core_transform=nc,
        method_options={'package_entry':str(unavailable)}),('ERROR','TOOL_ERROR'),sector)
    for name,response,expected in [('abort','Abort[]',('ERROR','EXECUTION_INTERRUPTED')),
            ('wrong-shape','{IdentityMatrix[1],{}}',('INCONCLUSIVE','TAIL_UNSOLVED')),
            ('singular','{ConstantArray[0,{2,2}],{}}',('INCONCLUSIVE','TAIL_UNSOLVED')),
            ('inexact','{1. IdentityMatrix[2],{}}',('INCONCLUSIVE','TAIL_UNSOLVED'))]:
        entry=out/('TailBackend-'+name+'.m')
        entry.write_text('BeginPackage["CANONICA`"];CANONICA`TransformOffDiagonalBlock;CANONICA`TransformDlogToEpsForm;CANONICA`eps;'
            'CANONICA`TransformOffDiagonalBlock[___]:='+response+';CANONICA`TransformDlogToEpsForm[___]:=$Failed;EndPackage[];')
        run('tail-backend-'+name,'SOLVE_TAIL',dict(full_sector_de=nf,core_transform=nc,
            method_options={'package_entry':str(entry)}),expected,sector)
    wrong=changed_artifact('wrong-convention',accepted_ref,{'convention':'new=transformation.old'},True)
    run('final-convention','FINAL_CHECK',{**final_payload,'accepted_prefix':wrong},('FAIL','FULL_SYSTEM_FAIL'))
    family=dict(family_ref='empty',basis_ref='empty-source',topology='neutral',parameters=[WL('d'),x],variables=[x],regulator=eps,
        dimension_rule=WL('d->4-2eps'),index_order=['D1'],sector_convention='positive indices')
    proposal=dict(proposal_id='manual-empty',candidate_pool=dict(remaining=0,pool_exhausted=True),method_evidence={'method_id':'manual'},
        tool_provenance={},candidates=[dict(candidate_id='f1',normalization={'factor':1},exact_definition=WL('HoldComplete[j[neutral,1]]'))])
    derivatives=dict(schema='canon.prepared-derivatives/v2',variables=[x],denominator_count=1,
        operators={x:[dict(constant=0,linear=[])]},exact_strategy={'propagator_slots':[1]})
    # The symbolic operator key is written explicitly, not as a string field.
    derivative_ref=artifact('empty-derivative',WL(wl(derivatives).replace('"x"->','x->')))
    result,dest=run('empty-targets-no-reducer','REDUCE_CANDIDATE_IBP',dict(integral_candidates=artifact('empty-proposal',proposal),
        prepared_family=artifact('empty-family',family),master_basis=artifact('empty-masters',dict(masters=[WL('f[1]')],basis_ref='empty-source',index_order=['D1'])),
        prepared_derivatives=derivative_ref,derivative_operator_selection='prepared-affine'),('PASS','CANDIDATES_REDUCED'),sector)
    assert not (dest/'ibp-input.json').exists() and not (dest/'ibp').exists()
    (out/'evidence.json').write_text(json.dumps({'cases':records,'all_pass':True,
        'scope':'Synthetic public workflow boundaries, exact algebraic positive cases and malformed-input rejection; no native IBP or family campaign.'},indent=2))
    print('PASS',len(records),'public-step cases')


if __name__=='__main__':
    main()
