#!/usr/bin/env python3
"""Public regression for exact complex inputs, point geometry, and artifact handoff.

All inputs are neutral fixtures. No native reducer or research state is used.
"""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import shutil
import sys
from test_workflow_boundaries import WL, wl


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--canon',type=Path,required=True)
    ap.add_argument('--work',type=Path,required=True)
    ap.add_argument('--observe',action='store_true',help='record baseline behavior without asserting repaired outcomes')
    args=ap.parse_args();root=args.canon.resolve();work=args.work.resolve();work.mkdir(parents=True,exist_ok=False)
    records=[]
    components=[root/'components'/p/'components.json' for p in ('parameterization','point-de','dlog-reconstruction')]
    flags=[item for p in components for item in ('--components',str(p))]
    def artifact(name,value):
        p=work/(name+'.wl');p.write_text(wl(value)+'\n');return {'path':str(p)}
    def run(name,step,payload,code,status='FAIL',collision=None):
        out=work/name;request=work/(name+'.json')
        request.write_text(json.dumps(dict(schema='canon-neu/script-input/v1',task_id=name,step=step,payload=payload),indent=2))
        if collision:
            out.mkdir();(out/collision).write_text('<|"stale"->True|>\n')
        p=subprocess.run([sys.executable,str(root/'run_step.py'),str(request),str(out),*flags],cwd=root,env=os.environ.copy(),capture_output=True,text=True,timeout=120)
        out.mkdir(exist_ok=True);(out/'process.log').write_text(p.stdout+p.stderr)
        result=json.loads((out/'result.json').read_text()) if (out/'result.json').exists() else {}
        ok=(result.get('status'),result.get('code'))==(status,code) and ((p.returncode==0)==(status in ('PASS','PROVISIONAL','INCONCLUSIVE') or step in ('RECONSTRUCT_DLOG','CHECK_RECONSTRUCTION')))
        records.append(dict(case=name,step=step,expected=[status,code],matched=ok,exit_code=p.returncode,result=result))
        (work/'evidence.json').write_text(json.dumps(dict(observe=args.observe,cases=records,all_pass=all(r['matched'] for r in records)),indent=2))
        print(name,result.get('status'),result.get('code'),flush=True)
        if not args.observe:assert ok,records[-1]
        return result,out
    def ref(result,out,key):return {'path':str(out/result['artifacts'][key]['path'])}
    x,eps,d,l,p=map(WL,['x','eps','d','l','p'])
    spec=dict(schema='canon-neu/parameterization-spec/v1',chart_type='scalar-products',family_ref='fixture',basis_ref='raw',chart_id='x',topology='fixture',integral_head='B',variables=[x],dimension=d,regulator=eps,dimension_rule=WL('d->4-2eps'),loop_momenta=[l],external_momenta=[p],scalar_products=WL('{{p,p}->x}'),propagator_momenta=[l,WL('l-p')],propagator_masses_squared=[0,0],index_order=['D1','D2'],propagator_slots=[1,2],top_level_sectors=[3],invariants=[dict(name=x,mass_dimension=2)],point=WL('{x->2}'))
    good=artifact('spec',spec)
    run('parameter-exact','PREPARE',dict(family_spec=good),'PARAMETERIZATION_READY','PASS')
    for name,updates,code in [('complex-point',dict(point=WL('{x->(1.+I)}')),'INVALID_EXACT_POINT'),('dimension-rule',dict(dimension_rule=WL('x->4-2eps')),'INVALID_DECLARED_SYMBOLS'),('negative-sector',dict(top_level_sectors=[-1]),'INVALID_PROPAGATOR_ORDER'),('isp-sector',dict(propagator_slots=[1],top_level_sectors=[3]),'INVALID_PROPAGATOR_ORDER')]:
        run('parameter-'+name,'PREPARE',dict(family_spec=artifact('spec-'+name,{**spec,**updates})),code)
    run('parameter-stale-output','PREPARE',dict(family_spec=good),'ARTIFACT_WRITE_FAILED',collision='family-data.wl')
    example=root/'components/point-de/examples'
    prep_payload={key:{'path':str(example/name)} for key,name in [('family_data','family.wl'),('master_basis','masters.wl'),('candidates','candidates.wl'),('point_spec','point.wl')]}
    run('point-prepare-exact','PREPARE_POINT',prep_payload,'POINT_PREPARED','PASS')
    family=WL('Join[Get['+wl(str(example/'family.wl'))+'],<|"propagators"->{(l+1)^2,(l-p1-p2)^2,(l-p1)^2,(l-p3)^2,(l-p4)^2}|>]')
    run('point-nonlinear-routing','PREPARE_POINT',{**prep_payload,'family_data':artifact('nonlinear-family',family)},'NONLINEAR_OR_UNDECLARED_MOMENTUM')
    candidate=WL('Join[Get['+wl(str(example/'candidates.wl'))+'],<|"rows"->{{<|"indices"->{1,1,0,0,0},"numerator"->sp[undeclared,p1]|>}}|>]')
    run('point-undeclared-numerator-momentum','PREPARE_POINT',{**prep_payload,'candidates':artifact('bad-momentum-candidate',candidate)},'NONLINEAR_OR_UNDECLARED_MOMENTUM')
    prepared=dict(schema='canon-neu/prepared-point/v1',family_id='fixture',basis_id='candidate',chart_id='x',frame_id='identity',scope={'case':'neutral'},variables=[x],regulator=eps,point=WL('{x->2}'),dimension_rule=WL('d->4-2eps'),masters=[WL('B[1]')],expressions=[WL('B[1]')],candidate_derivatives=[[WL('eps B[1]')]],master_derivatives=[[WL('eps B[1]')]],frame=[[1]],frame_derivatives=[[[0]]],targets=[WL('B[1]')],source_basis_id='raw',candidate_basis_id='candidate',convention='D[basis, variables[[i]]] = matrices[[i]] . basis')
    pref=artifact('prepared',prepared);rules=artifact('rules',WL('{}'));payload=dict(prepared_point=pref,ibp_reduction={**rules,'symbolic':True})
    run('point-build-exact','BUILD_POINT_DE',payload,'POINT_DE_BUILT','PASS')
    for name,coeff,code,status in [('exact-complex',WL('I eps'),'POINT_DE_BUILT','PASS'),('exact-root',WL('Root[#^5-#-1&,1]eps'),'POINT_DE_BUILT','PASS'),('inexact-complex',WL('(1.+I)eps'),'NONLINEAR_OR_INEXACT_REDUCTION','FAIL'),('unresolved-scalar',WL('unknown eps'),'UNRESOLVED_POINT_COEFFICIENT','FAIL')]:
        pnew={**prepared,'candidate_derivatives':[[WL(str(coeff)+' B[1]')]],'master_derivatives':[[WL(str(coeff)+' B[1]')]]}
        run('point-build-'+name,'BUILD_POINT_DE',{**payload,'prepared_point':artifact(name,pnew)},code,status)
    run('point-missing-directions','BUILD_POINT_DE',{**payload,'prepared_point':artifact('missing-directions',{**prepared,'candidate_derivatives':[]})},'INVALID_PREPARED_POINT')
    dup=artifact('duplicate-rules',WL('{B[2]->B[1],B[2]->2B[1]}'))
    run('point-duplicate-reduction','BUILD_POINT_DE',{**payload,'ibp_reduction':{**dup,'symbolic':True}},'INVALID_REDUCTION_RULES')
    wrong=artifact('wrong-reduction-masters',dict(masters=[WL('B[2]')],rules=[]))
    run('point-wrong-reduction-masters','BUILD_POINT_DE',{**payload,'ibp_reduction':{**wrong,'symbolic':True}},'SOURCE_BASIS_MISMATCH')
    alias_prepared={**prepared,'expressions':[WL('B[2]')],'candidate_derivatives':[[WL('(1+2eps)B[1]')]],'targets':[WL('B[1]'),WL('B[2]')]}
    alias_rules=artifact('alias-rules',WL('<|"masters"->{x[1]},"rules"->{x[2]->x x[1]}|>'))
    result,where=run('point-native-head-scalar-collision','BUILD_POINT_DE',dict(prepared_point=artifact('alias-prepared',alias_prepared),
        ibp_reduction={**alias_rules,'symbolic':True,'integral_head':'x'}),'POINT_DE_BUILT','PASS')
    if result.get('code')=='POINT_DE_BUILT':
        probe=work/'alias-check.wls';receipt=work/'alias-check.json'
        probe.write_text('a=Get['+wl(str(where/'projection.wl'))+'];Export['+wl(str(receipt))+',<|"projection_is_two"->(a["projection"]==={{2}})|>,"RawJSON"];')
        check=subprocess.run([os.environ.get('CANON_WOLFRAMSCRIPT','wolframscript'),'-file',str(probe)],capture_output=True,text=True,timeout=30)
        fact=json.loads(receipt.read_text())['projection_is_two'];records[-1]['projection_is_two']=fact;records[-1]['matched'] &= fact
        if not args.observe:assert check.returncode==0 and fact,(check.stdout,check.stderr)
    run('point-stale-output','BUILD_POINT_DE',payload,'ARTIFACT_WRITE_FAILED',collision='de-sample.wl')
    digest=hashlib.sha256(Path(pref['path']).read_bytes()).hexdigest()
    run('point-pinned-hash-valid','BUILD_POINT_DE',{**payload,'prepared_point':{**pref,'sha256':digest.upper()}},'POINT_DE_BUILT','PASS')
    run('point-rule-hash-mismatch','BUILD_POINT_DE',{**payload,'ibp_reduction':{**rules,'symbolic':True,'sha256':'0'*64}},'SOURCE_HASH_MISMATCH')
    run('point-pinned-hash-mismatch','BUILD_POINT_DE',{**payload,'prepared_point':{**pref,'sha256':'0'*64}},'SOURCE_HASH_MISMATCH')

    identity=dict(family_id='sample-fixture',basis_id='one-master',chart_id='complex-x',frame_id='identity',scope={'case':'neutral'},variables=[x],regulator=eps,convention='D[basis, variables[[i]]] = matrices[[i]] . basis')
    arithmetic=dict(mode='high_precision',precision=60,residual_tolerance='10^-10',rank_tolerance='10^-12',recognition_tolerance='10^-12',max_denominator=1000,max_numerator=1000)
    sample_refs={}
    for mode in ('exact','high','machine'):
        refs=[]
        for i in range(1,5):
            coefficient='1/(3('+str(i)+'+I))'
            if mode!='exact':coefficient='N['+coefficient+(','+'80' if mode=='high' else '')+']'
            sref=artifact(mode+'-sample-'+str(i),{**identity,'schema':'canon-neu/de-sample/v1','point':WL('{x->'+str(i)+'+I}'),'matrices':[WL('{{eps ('+coefficient+')}}')]})
            refs.append(dict(id=mode+'-'+str(i),path=sref['path']))
        sample_refs[mode]=refs
        setref=artifact(mode+'-set',{**identity,'schema':'canon-neu/de-sample-set/v1','training':refs[:3],'validation':refs[3:]})
        letterref=artifact(mode+'-letters',{**identity,'schema':'canon-neu/raw-letters/v1','labels':['x'],'letters':[x]})
        rp=dict(sample_set=setref,raw_letters=letterref,arithmetic=({'mode':'exact'} if mode=='exact' else arithmetic))
        result,out=run('reconstruct-'+mode,'RECONSTRUCT_DLOG',rp,'INSUFFICIENT_INPUT_PRECISION' if mode=='machine' else 'DLOG_RECONSTRUCTED','ERROR' if mode=='machine' else 'PROVISIONAL')
        if mode=='machine':
            run('reconstruct-inexact-in-exact-mode','RECONSTRUCT_DLOG',{**rp,'arithmetic':{'mode':'exact'}},'INEXACT_DATA_IN_EXACT_MODE','ERROR')
        if mode=='high':
            badletters=artifact('inexact-complex-letters',{**identity,'schema':'canon-neu/raw-letters/v1','labels':['x'],'letters':[WL('(1.+I)x')]})
            run('reconstruct-inexact-analytic-letter','RECONSTRUCT_DLOG',{**rp,'raw_letters':badletters},'INVALID_RAW_LETTERS','ERROR')
        if result.get('code')=='DLOG_RECONSTRUCTED':
            cref=ref(result,out,'reconstruction')
            run('check-'+mode,'CHECK_RECONSTRUCTION',dict(sample_set=setref,raw_letters=letterref,reconstruction=cref),'RECONSTRUCTION_VALIDATED','PASS')
            if mode=='high':
                tampered=artifact('bounded-reconstruction',WL('With[{c=Get['+wl(cref['path'])+']},Join[c,<|"arithmetic"->Join[c["arithmetic"],<|"max_denominator"->1|>]|>]]'))
                bound_path=Path(cref['path']).with_name('bounded.wl');bound_path.write_text(Path(tampered['path']).read_text());tampered={'path':str(bound_path)}
                run('check-recognition-bounds','CHECK_RECONSTRUCTION',dict(sample_set=setref,raw_letters=letterref,reconstruction=tampered),'RATIONAL_RECOGNITION_BOUND_EXCEEDED','ERROR')
    run('collect-inexact-complex','COLLECT_DE_SAMPLES',dict(training=sample_refs['machine'][:3],validation=sample_refs['machine'][3:]),'SAMPLE_IDENTITY_MISMATCH')
    run('collect-exact-complex','COLLECT_DE_SAMPLES',dict(training=sample_refs['exact'][:3],validation=sample_refs['exact'][3:]),'DE_SAMPLES_COLLECTED','PASS')
    run('collect-pinned-hash-mismatch','COLLECT_DE_SAMPLES',dict(training=[{**sample_refs['exact'][0],'sha256':'0'*64}],validation=sample_refs['exact'][3:]),'SOURCE_HASH_MISMATCH')
    frozen=[]
    for i,item in enumerate(sample_refs['exact']):
        p=work/('frozen-'+str(i)+'.wl');shutil.copyfile(item['path'],p);frozen.append({**item,'path':str(p)})
    result,where=run('collect-pinned-handoff','COLLECT_DE_SAMPLES',dict(training=frozen[:3],validation=frozen[3:]),'DE_SAMPLES_COLLECTED','PASS')
    pinned=ref(result,where,'de_sample_set')
    sample=Path(frozen[0]['path']);sample.write_text(sample.read_text()+'\n(* changed after collection *)\n')
    run('reconstruct-changed-collected-sample','RECONSTRUCT_DLOG',dict(sample_set=pinned,
        raw_letters={'path':str(work/'exact-letters.wl')},arithmetic={'mode':'exact'}),'SOURCE_HASH_MISMATCH','ERROR')
    print('CASES',len(records),'MATCHED',sum(r['matched'] for r in records))


if __name__=='__main__':main()
