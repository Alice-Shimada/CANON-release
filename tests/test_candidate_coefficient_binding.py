#!/usr/bin/env python3
"""Actual-loader candidate coefficient-frame regression; no native science packages.

The neutral package fixture exercises the public Dlog adapter, not Dlog search
mathematics. Supplied analytic rules exercise import-only candidate reduction.
An optional --baseline source snapshot records the original missing derivative.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


PROVIDER = '''BeginPackage["DlogBasis`"];
Options[DlogBasisSearch] = {"LoopSpecifications"->{}, "NumeratorDegreeBound"->0,
 "DotDegreeBound"->0, "NumeratorPositions"->Automatic, "FiniteFlowPackageFile"->Automatic,
 "ResidualBackend"->"Current", "SingularExecutable"->"Singular"};
DlogBasisSearch[family_,sector_,OptionsPattern[]] := With[
 {coordinate=First[family["KinematicVariables"]], constant=family["Constant"]},
 <|"ScientificStatus"->"NeutralFixture", "CandidateCombinations"->{
 (1+constant) DimensionalRegulator^2/(1+DimensionalRegulator) Sqrt[coordinate]
  (DlogIntegral["neutral",{1}]+coordinate DlogIntegral["neutral",{0}])},
 "CandidateLattice"-><|"CandidateCount"->1|>, "RepresentedCandidates"->{1},
 "CandidateChartCompleteQ"->True, "AffineFiniteConstantResiduesVerifiedQ"->False,
 "ConstantLeadingSingularityCertifiedQ"->False, "UniformTranscendentalityCertifiedQ"->False,
 "CanonicalBasisCertifiedQ"->False|>];
EndPackage[];
'''
FAMILY = '''<|"family_ref"->"coefficient-fixture", "basis_ref"->"source-order",
 "chart_id"->"same-chart", "topology"->"neutral", "integral_head"->"G",
 "parameters"->{d,x,Constant`x}, "variables"->{x}, "regulator"->eps,
 "dimension_rule"->(d->4-2 eps), "sector_convention"->"positive indices", "index_order"->{"D1"}|>'''
DERIVATIVES = '''<|"schema"->"canon.prepared-derivatives/v2", "variables"->{x},
 "denominator_count"->1, "operators"-><|x->{<|"constant"->1,"linear"->{}|>}|>,
 "exact_strategy"-><|"propagator_slots"->{1}|>|>'''
MASTERS = '''<|"schema"->"canon-neu/master-basis/v1", "family_ref"->"coefficient-fixture",
 "basis_ref"->"source-order", "index_order"->{"D1"}, "masters"->{G[1],G[0]}|>'''
REDUCTION = '<|"masters"->{G[1],G[0]},"rules"->{G[2]->(d-3)/(2 x) G[1]}|>'
BASIS = '''<|"schema"->"canon-neu/sector-basis/v1", "sector"-><|"id"->1|>,
 "family_id"->"coefficient-fixture", "basis_id"->"cut-order", "basis"->{G[1]}|>'''
CUT = '''<|"schema"->"canon-neu/sector-cut-de/v1", "sector"-><|"id"->1|>,
 "family_id"->"coefficient-fixture", "basis_id"->"cut-order", "coefficient_domain"->"exact-rational-functions",
 "basis"->{G[1]}, "variables"->{x}, "regulator"->eps, "matrices"->{{{(eps-1/2)/x}}}|>'''

READBACK = r'''{canon,base,withBaseline}=Rest[$ScriptCommandLine];
Get[FileNameJoin[{canon,"mma","lib","MethodCardCore.wl"}]];
Get[FileNameJoin[{canon,"mma","lib","BaikovDerivative.wl"}]];
Get[FileNameJoin[{canon,"mma","lib","CandidateIBPBridge.wl"}]];
read[name_] := CanonMethodCard`ReadWLData[FileNameJoin[{base,name}]];
prepared=read["family.wl"]; masters=read["masters.wl"]; derivatives=read["derivatives.wl"];
coordinate=First[prepared["variables"]]; regulator=prepared["regulator"]; dimension=First[prepared["parameters"]];
integralHead=Head[First[masters["masters"]]];
prefactor=(1+Constant`x) regulator^2/(1+regulator) Sqrt[coordinate];
facts=<||>;
bridge=read["staged-reduce/candidate-ibp-bridge.wl"]; record=First[bridge["candidates"]];
proposal=read["staged-propose/integral-candidates.wl"];
group=First[read["staged-route/core-candidates.wl"]["candidates"]];
facts["producer/exact-frame-and-identities"] = proposal["coefficient_frame","variables"]==={Global`x} &&
 proposal["coefficient_frame","regulator"]===Global`eps && proposal["coefficient_frame","dimension"]===Global`d &&
 proposal["coefficient_frame","family_ref"]===prepared["family_ref"] && proposal["coefficient_frame","chart_id"]===prepared["chart_id"];
facts["binding/exact-algebraic-normalization-and-composition"] =
 Together[record["expression"]-prefactor(integralHead[1]+coordinate integralHead[0])]===0;
facts["binding/full-prefactor-derivative"] = Together[record["derivatives"][coordinate]-
 (prefactor/(2 coordinate) integralHead[1]+3 prefactor/2 integralHead[0]-prefactor integralHead[2])]===0;
facts["binding/regulator-profile-and-constant-retained"] =
 !FreeQ[record["expression"],Constant`x] && FreeQ[record["expression"],Global`x|Global`eps|Global`d];
facts["provenance/raw-normalization-and-definition-retained"] =
 record["normalization"]===First[proposal["candidates"]]["normalization"] &&
 record["exact_definition"]===First[proposal["candidates"]]["exact_definition"] && bridge["tool_provenance"]===proposal["tool_provenance"];
facts["ordering/master-target-and-full-subsector-row"] = bridge["masters"]===masters["masters"] &&
 Lookup[bridge["reducer_targets"],"integral"]==={integralHead[2]} &&
 Together[group["full_new_basis_rows"]-{{prefactor,coordinate prefactor}}]=== {{0,0}};
facts["routing/exact-epsilon-connection"] = Together[group["transformed_matrices"]-{{{regulator/coordinate}}}]=== {{{0}}};
facts["independent/positive-core-pass"] = read["staged-check/core-transform.wl"]["checks","pass"]===True;
negativeGroup=First[read["negative-route/core-candidates.wl"]["candidates"]];
facts["negative/binding-correct-nonlinear-epsilon-remains"] =
 Together[negativeGroup["transformed_matrices"]-{{{regulator^2/coordinate}}}]=== {{{0}}};
roundtrip=CanonMethodCard`WriteWLArtifact[bridge,base,"bridge-roundtrip-"<>CreateUUID[]<>".wl"];
facts["serialization/exact-public-reader-roundtrip"] = CanonMethodCard`ReadWLData[roundtrip]===bridge;
If[withBaseline==="yes",
 oldBridge=read["baseline-reduce/candidate-ibp-bridge.wl"]; oldRecord=First[oldBridge["candidates"]];
 oldGroup=First[read["baseline-route/core-candidates.wl"]["candidates"]];
 facts["original/actual-loader-preserves-distinct-contexts"] =
   !FreeQ[oldRecord["expression"],Global`x] && coordinate=!=Global`x;
 facts["original/prefactor-derivative-lost"] = Coefficient[oldRecord["derivatives"][coordinate],integralHead[1]]===0 &&
   Coefficient[oldRecord["derivatives"][coordinate],integralHead[0]]===0;
 facts["original/routed-connection-is-not-epsilon-form"] =
   !CanonMethodCard`EpsilonFactorizedQ[oldGroup["transformed_matrices"],regulator];
 recovered=read["recovery-reduce/candidate-ibp-bridge.wl"];
 facts["recovery/unchanged-saved-candidate-explicit-aliases"] =
   Together[First[recovered["candidates"]]["expression"]-record["expression"]]===0 &&
   First[recovered["candidates"]]["exact_definition"]===First[read["baseline-propose/integral-candidates.wl"]["candidates"]]["exact_definition"];
 facts["recovery/independent-core-pass"] = read["recovery-check/core-transform.wl"]["checks","pass"]===True
];

(* Each focused input passes through WriteWLArtifact and actual LoadArtifact. *)
caseDirectory=FileNameJoin[{base,"boundary-cases"}]; If[!DirectoryQ[caseDirectory],CreateDirectory[caseDirectory]];
loadCase[value_,name_] := Module[{path,task},
 path=CanonMethodCard`WriteWLArtifact[value,caseDirectory,name<>".wl"];
 task=<|"payload"-><|"item"-><|"path"->path|>|>|>;
 CanonMethodCard`LoadArtifact[task,FileNameJoin[{caseDirectory,"declaring.json"}],"item"]];
compile[value_,family_:prepared,physical_:derivatives] :=
 CANON`CandidateIBPBridge`CompileCandidateIBPTargets[loadCase[value,CreateUUID[]],
 loadCase[family,CreateUUID[]],masters,loadCase[physical,CreateUUID[]],"prepared-affine"];
errorQ[value_,reason_] := FailureQ[value] && value[[1]]==="SOURCE_BASIS_MISMATCH" && StringContainsQ[value[[2,"MessageTemplate"]],reason];
same=KeyDrop[proposal,{"coefficient_frame"}];
same["candidates"]= {<|"candidate_id"->"same-frame", "normalization"-><|"factor"->(dimension-4)/(1+regulator) Sqrt[coordinate]|>,
 "exact_definition"->(HoldComplete@@{integralHead[1]+coordinate integralHead[0]})|>};
sameCompiled=compile[same];
facts["compatibility/same-frame-symbolic-dimension"] = !FailureQ[sameCompiled] &&
 Together[First[sameCompiled["candidates"]]["expression"]-(dimension-4)/(1+regulator) Sqrt[coordinate](integralHead[1]+coordinate integralHead[0])]===0;
KeyValueMap[Function[{name,expression},
 bad=same;bad["candidates"]={Join[First[same["candidates"]],
   <|"exact_definition"->(HoldComplete@@{expression})|>]};
 facts["negative/integral-"<>name]=errorQ[compile[bad],"must be linear"]],
 <|"square"->integralHead[1]^2,"product"->integralHead[1] integralHead[0],
   "function"->Sin[integralHead[1]],"reciprocal"->1/integralHead[1],
   "fractional-power"->Sqrt[integralHead[1]],"offset"->(integralHead[1]+1)|>];
cancelled=same;cancelled["candidates"]={Join[First[same["candidates"]],
 <|"exact_definition"->(HoldComplete@@{(integralHead[1]+integralHead[0])^2-
 integralHead[1]^2-integralHead[0]^2-2 integralHead[1] integralHead[0]+integralHead[1]+coordinate integralHead[0]})|>]};
cancelledCompiled=compile[cancelled];
facts["compatibility/integral-polynomial-cancellation"] = !FailureQ[cancelledCompiled] &&
 First[cancelledCompiled["candidates"]]["expression"]===First[sameCompiled["candidates"]]["expression"];
external=same/.{coordinate->Global`x,regulator->Global`eps,dimension->Global`d};
aliased=Join[prepared,<|"operator_source_symbol_map"-><|"Global`x"->"x","Global`eps"->"eps","Global`d"->"d"|>|>];
facts["compatibility/legacy-explicit-coordinate-regulator-dimension-aliases"] =
 !FailureQ[compile[external,aliased]] && First[compile[external,aliased]["candidates"]]["expression"]===First[sameCompiled["candidates"]]["expression"];
unmapped=compile[external];
facts["negative/unmapped-external-coordinates"] = errorQ[unmapped,"Undeclared candidate coefficient symbols"] &&
 StringContainsQ[unmapped[[2,"MessageTemplate"]],"Global`x"] && StringContainsQ[unmapped[[2,"MessageTemplate"]],"Global`eps"];
conflicting=Join[prepared,<|"operator_source_symbol_map"-><|"q"->"x","CANON`DEData`q"->"eps"|>|>];
facts["negative/ambiguous-alias-source"] = errorQ[compile[same,conflicting],"ambiguous"];
conflicting=Join[prepared,<|"operator_source_symbol_map"-><|"x"->"eps"|>|>];
facts["negative/declared-identities-immutable"] = errorQ[compile[same,conflicting],"already declared"];
unknown=Join[prepared,<|"operator_source_symbol_map"-><|"Foreign`x"->"z"|>|>];
facts["negative/alias-target-undeclared"] = errorQ[compile[same,unknown],"target declared"];

multi=Join[prepared,<|"variables"->{Left`x,Right`x},"parameters"->{dimension,Left`x,Right`x}|>];
zeroPhysical=<|"variables"->multi["variables"],"operators"->AssociationMap[{<|"constant"->0,"linear"->{}|>}&,multi["variables"]],"exact_strategy"-><|"propagator_slots"->{1}|>|>;
distinct=Join[same,<|"coefficient_frame"-><|"family_ref"->prepared["family_ref"],"chart_id"->prepared["chart_id"],
 "variables"->{Left`x,Right`x},"regulator"->regulator,"dimension"->dimension,"constants"->{}|>|>];
distinct["candidates"]={<|"candidate_id"->"distinct", "normalization"-><|"factor"->1|>,
 "exact_definition"->HoldComplete[(Left`x+Right`x) CANON`DEData`G[1]]|>};
distinctCompiled=compile[distinct,multi,zeroPhysical];
facts["compatibility/declared-same-basename-identities-stay-distinct"] = !FailureQ[distinctCompiled] &&
 First[distinctCompiled["candidates"]]["derivatives"][Left`x]===integralHead[1] &&
 First[distinctCompiled["candidates"]]["derivatives"][Right`x]===integralHead[1];
ambiguous=distinct/.{Left`x->FirstFrame`x,Right`x->SecondFrame`x};
facts["negative/foreign-same-basename-frame-ambiguous"] = errorQ[compile[ambiguous,multi,zeroPhysical],"repeat ambiguously"];
explicitMulti=Join[multi,<|"operator_source_symbol_map"-><|"FirstFrame`x"->"Left`x","SecondFrame`x"->"Right`x"|>|>];
facts["compatibility/distinct-frame-requires-exact-aliases"] = !FailureQ[compile[ambiguous,explicitMulti,zeroPhysical]];

framed=Join[external,<|"coefficient_frame"->proposal["coefficient_frame"]|>];
bad=framed;bad["coefficient_frame"]=Join[bad["coefficient_frame"],<|"variables"->{Global`y}|>];
facts["negative/frame-coordinate-name-mismatch"] = errorQ[compile[bad],"names/order differ"];
ordered=Join[prepared,<|"variables"->{coordinate,CANON`DEData`y},"parameters"->{dimension,coordinate,CANON`DEData`y}|>];
orderedPhysical=Join[zeroPhysical,<|"variables"->ordered["variables"],"operators"->AssociationMap[{<|"constant"->0,"linear"->{}|>}&,ordered["variables"]]|>];
bad=framed;bad["coefficient_frame"]=Join[bad["coefficient_frame"],<|"variables"->{Global`y,Global`x}|>];
facts["negative/frame-coordinate-reordering"] = errorQ[compile[bad,ordered,orderedPhysical],"names/order differ"];
bad=framed;bad["coefficient_frame"]=Join[bad["coefficient_frame"],<|"chart_id"->"different-chart"|>];
facts["negative/frame-chart-mismatch"] = errorQ[compile[bad],"same prepared family"];
bad=framed;bad["coefficient_frame"]=Join[bad["coefficient_frame"],<|"family_ref"->"different-family"|>];
facts["negative/frame-family-mismatch"] = errorQ[compile[bad],"same prepared family"];
bad=framed;bad["coefficient_frame"]=Join[bad["coefficient_frame"],<|"dimension"->4|>];
facts["negative/numeric-dimension-is-not-symbol-alias"] = errorQ[compile[bad],"numeric constants cannot be rebound"];
bad=framed;bad["coefficient_frame"]=Join[bad["coefficient_frame"],<|"constants"->{Global`x}|>];
facts["negative/frame-constant-coordinate-collision"] = errorQ[compile[bad],"constants must remain independent"];

numericFamily=Join[prepared,<|"parameters"->{4,coordinate},"dimension_rule"->{}|>];
numeric=framed; numeric["coefficient_frame"]=Join[numeric["coefficient_frame"],<|"dimension"->4,"constants"->{}|>];
numeric["candidates"]={<|"candidate_id"->"numeric", "normalization"-><|"factor"->4+Global`x|>,
 "exact_definition"->HoldComplete[CANON`DEData`j[CANON`DEData`neutral,1]]|>};
numericCompiled=compile[numeric,numericFamily];
facts["compatibility/numeric-dimension-literal-preserved"] = !FailureQ[numericCompiled] &&
 First[numericCompiled["candidates"]]["expression"]===(4+coordinate) integralHead[1] &&
 FreeQ[numericCompiled["coefficient_symbol_bindings"],HoldPattern[4->_]];
indexedFamily=Join[prepared,<|"variables"->{CANON`DEData`u[1]},"parameters"->{dimension,CANON`DEData`u[1]}|>];
indexedPhysical=Join[zeroPhysical,<|"variables"->indexedFamily["variables"],"operators"-><|CANON`DEData`u[1]->{<|"constant"->0,"linear"->{}|>}|>|>];
indexed=framed;indexed["coefficient_frame"]=Join[indexed["coefficient_frame"],<|"variables"->{External`u[1]},"constants"->{}|>];
indexed["candidates"]={<|"candidate_id"->"indexed", "normalization"-><|"factor"->External`u[1]|>,
 "exact_definition"->HoldComplete[CANON`DEData`j[CANON`DEData`neutral,1]]|>};
indexedCompiled=compile[indexed,indexedFamily,indexedPhysical];
indexedLoaded=loadCase[indexed,CreateUUID[]]; indexedFamilyLoaded=loadCase[indexedFamily,CreateUUID[]];
indexedBinding=CANON`CandidateIBPBridge`Private`coefficientBinding[indexedLoaded,indexedFamilyLoaded];
indexedExpression=CANON`CandidateIBPBridge`Private`bindExpression[
 First[indexedLoaded["candidates"]]["normalization","factor"] CANON`CandidateIBPBridge`Private`canonicalExpression[
 First[indexedLoaded["candidates"]]["exact_definition"],integralHead,indexedFamilyLoaded["topology"]],integralHead,indexedBinding];
facts["compatibility/indexed-coordinate-binding-identity"] = !FailureQ[indexedBinding] &&
 MemberQ[indexedBinding["rules"],External`u[1]->CANON`DEData`u[1]] && indexedExpression===CANON`DEData`u[1] integralHead[1];
Export[FileNameJoin[{base,"known-limitations.json"}],<|"indexed_derivative_selector"-><|
 "binding_pass"->facts["compatibility/indexed-coordinate-binding-identity"],
 "compile_failure_tag"->If[FailureQ[indexedCompiled],indexedCompiled[[1]],"none"],
 "exported_pattern"->"ChooseDerivativeOperator[prepared_Association, variable_Symbol, selection_ : enhanced-first]",
 "public_contract"->"Parameterization README permits indexed x[1]; candidate bridge prepared-affine applies to all declared variables.",
 "scope"->"Existing candidate derivative-selection capability gap, outside this coefficient-binding repair."|>|>,"RawJSON"];
Export[FileNameJoin[{base,"readback.json"}],facts,"RawJSON"];
Print[InputForm[<|"total"->Length[facts],"failed"->Keys[Select[facts,!TrueQ[#]&]]|>]];
Exit[If[AllTrue[Values[facts],TrueQ],0,1]];
'''


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--canon', type=Path, required=True)
    parser.add_argument('--baseline', type=Path)
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--components', type=Path, action='append', required=True)
    args = parser.parse_args()
    canon, work = args.canon.resolve(), args.work.resolve()
    work.mkdir(parents=True, exist_ok=False)
    for name, text in [('family.wl', FAMILY), ('masters.wl', MASTERS),
                       ('derivatives.wl', DERIVATIVES), ('rules.wl', REDUCTION),
                       ('basis.wl', BASIS), ('cut.wl', CUT)]:
        (work / name).write_text(text+'\n')
    (work/'negative-cut.wl').write_text(CUT.replace('(eps-1/2)', '(eps^2-1/2)')+'\n')
    (work/'negative-rules.wl').write_text(REDUCTION.replace('(d-3)/(2 x)', '(1/2-eps^2)/x')+'\n')
    (work/'provider.wl').write_text(PROVIDER)
    (work/'provider-family.wl').write_text('<|"Family"-><|"Propagators"->{p},"LoopMomenta"->{k},"KinematicVariables"->{Global`x},"Constant"->Constant`x|>|>\n')
    (work/'provider-prepared.wl').write_text('''<|"family_ref"->"coefficient-fixture", "chart_id"->"same-chart", "topology"->"neutral",
 "parameters"->{Global`d,Global`x,Constant`x},"variables"->{Global`x},"regulator"->Global`eps,"family_data"-><|"path"->"provider-family.wl"|>|>\n''')
    aliases='<|"Global`x"->"x","Global`eps"->"eps","Global`d"->"d"|>'
    (work/'recovery-family.wl').write_text(FAMILY[:-2]+',"operator_source_symbol_map"->'+aliases+'|>\n')
    components=[str(p.resolve()) for p in args.components]
    evidence=[]
    described=set()
    environment=os.environ.copy()
    environment['CANON_TEST_PUBLIC_CHILD']='1'
    environment['PYTHONDONTWRITEBYTECODE']='1'
    for name in ('OMP_NUM_THREADS','MKL_NUM_THREADS','OPENBLAS_NUM_THREADS','NUMEXPR_NUM_THREADS'):
        environment[name]='1'

    def run(source, step, tag, payload, expected):
        request=work/(tag+'-input.json'); output=work/tag
        request.write_text(json.dumps({'schema':'canon-neu/script-input/v1','task_id':tag,
            'step':step,'sector':{'id':1},'payload':payload},indent=2)+'\n')
        command=[sys.executable,str(source/'run_step.py'),str(request),str(output)]
        for component in components:
            command+=['--components',component]
        env=dict(environment,CANON_TEST_SOURCE=str(source))
        if (str(source),step) not in described:
            result=subprocess.run(command+['--describe'],env=env,capture_output=True,text=True)
            assert result.returncode==0,result.stdout+result.stderr
            (work/(tag+'-describe.json')).write_text(result.stdout)
            described.add((str(source),step))
        result=subprocess.run(command,env=env,capture_output=True,text=True)
        (work/(tag+'.log')).write_text(result.stdout+result.stderr)
        receipt=json.loads((output/'result.json').read_text())
        assert (receipt['status'],receipt['code'])==expected,(tag,receipt,result.stdout,result.stderr)
        assert result.returncode==(1 if expected[0]=='ERROR' else 0),(tag,result.returncode)
        evidence.append({'case':tag,'command':command,'components':components,'returncode':result.returncode,
                         'status':receipt['status'],'code':receipt['code'],'result_path':str(output/'result.json')})
        return output

    proposalPayload={'prepared_family':{'path':'provider-prepared.wl'},'family_identity':{'family_id':'coefficient-fixture'},
        'sector_identity':{'id':1},'dimension_policy':{'spacetime_dimension':4},
        'numerator_or_power_counting_policy':{'definition':{'numerator_degree':0,'max_added_dots':0,'max_dots_per_propagator':0}},
        'candidate_budget':{'maximum':1,'unit':'PROVIDER_CANDIDATE'},'candidate_unit':'NORMALIZED_LINEAR_COMBINATION',
        'normalization_policy':{'convention':'first-integral-coefficient-outside-definition','factors':{'placement':'normalization.factor'}},
        'method_options':{'package_entry':str(work/'provider.wl'),'package_revision':'neutral-frame-fixture-v1',
            'finite_flow_package_file':'unused-FiniteFlow.m','loop_order':[1],'loop_dimensions':[4]}}
    def reduce(source,tag,candidate,family='family.wl',rules='rules.wl',expected=('PASS','CANDIDATES_REDUCED')):
        output=run(source,'REDUCE_CANDIDATE_IBP',tag,{'integral_candidates':{'path':candidate},
            'prepared_family':{'path':family},'master_basis':{'path':'masters.wl'},'prepared_derivatives':{'path':'derivatives.wl'},
            'derivative_operator_selection':'prepared-affine','ibp_reduction':{'path':rules}},expected)
        assert not (output/'ibp').exists() and not (output/'ibp-input.json').exists(),'Reuse unexpectedly dispatched a reducer'
        if expected[0]=='ERROR':
            assert not (output/'reduction-targets.wl').exists(),'Invalid binding reached target publication'
        return output
    def route(source,tag,bridge,family='family.wl',cut='cut.wl'):
        return run(source,'ROUTE_CORE_CANDIDATES',tag,{'prepared_family':{'path':family},'sector_basis':{'path':'basis.wl'},
            'sector_cut_de':{'path':cut},'candidate_ibp_bridge':{'path':bridge}},('PROVISIONAL','CORE_CANDIDATES_ROUTED'))
    def check(tag,core,cut='cut.wl',expected=('PASS','CORE_PASS')):
        return run(canon,'CHECK_CORE',tag,{'sector_basis':{'path':'basis.wl'},'sector_cut_de':{'path':cut},
            'core_candidates':{'path':core}},expected)

    if args.baseline:
        baseline=args.baseline.resolve()
        run(baseline,'PROPOSE_INTEGRAL_CANDIDATES','baseline-propose',proposalPayload,('PROVISIONAL','INTEGRAL_CANDIDATES'))
        reduce(baseline,'baseline-reduce','baseline-propose/integral-candidates.wl')
        route(baseline,'baseline-route','baseline-reduce/candidate-ibp-bridge.wl')
        saved=work/'baseline-propose/integral-candidates.wl'; before=digest(saved)
        reduce(canon,'unmapped-error','baseline-propose/integral-candidates.wl',expected=('ERROR','SOURCE_BASIS_MISMATCH'))
        reduce(canon,'recovery-reduce','baseline-propose/integral-candidates.wl',family='recovery-family.wl')
        route(canon,'recovery-route','recovery-reduce/candidate-ibp-bridge.wl',family='recovery-family.wl')
        check('recovery-check','recovery-route/core-candidates.wl')
        assert digest(saved)==before,'Recovery changed immutable saved candidates'
        evidence.append({'case':'saved-candidates-immutable-recovery','sha256':before,'after_sha256':digest(saved),
                         'no_provider_replay_for_recovery':True})
    run(canon,'PROPOSE_INTEGRAL_CANDIDATES','staged-propose',proposalPayload,('PROVISIONAL','INTEGRAL_CANDIDATES'))
    reduce(canon,'staged-reduce','staged-propose/integral-candidates.wl')
    route(canon,'staged-route','staged-reduce/candidate-ibp-bridge.wl')
    check('staged-check','staged-route/core-candidates.wl')
    reduce(canon,'negative-reduce','staged-propose/integral-candidates.wl',rules='negative-rules.wl')
    route(canon,'negative-route','negative-reduce/candidate-ibp-bridge.wl',cut='negative-cut.wl')
    check('negative-check','negative-route/core-candidates.wl',cut='negative-cut.wl',expected=('FAIL','CORE_FAIL'))
    negative=json.loads((work/'negative-check/result.json').read_text())
    assert negative['summary']['attempts'][0]['rejection_signature']==['not_epsilon_factorized'],negative
    helper=work/'readback.wls';helper.write_text(READBACK)
    runtime=os.environ.get('CANON_WOLFRAMSCRIPT') or shutil.which('wolframscript')
    result=subprocess.run([runtime,'-file',str(helper),str(canon),str(work),'yes' if args.baseline else 'no'],
                          env=dict(environment,CANON_TEST_SOURCE=str(canon)),capture_output=True,text=True)
    (work/'readback.log').write_text(result.stdout+result.stderr)
    facts=json.loads((work/'readback.json').read_text())
    receipt={'scope':'generic coefficient-frame/source engineering; no native reduction or family solution',
             'components':components,'public_cases':evidence,'facts':facts,
             'facts_count':len(facts),'failed_facts':[key for key,value in facts.items() if value is not True],
             'readback_returncode':result.returncode,'known_limitations':json.loads((work/'known-limitations.json').read_text()),'thread_env':{key:environment[key] for key in
                  ('OMP_NUM_THREADS','MKL_NUM_THREADS','OPENBLAS_NUM_THREADS')}}
    (work/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps({'facts_count':len(facts),'failed_facts':receipt['failed_facts'],'public_invocations':sum('command' in item for item in evidence)},indent=2))
    assert receipt['known_limitations']['indexed_derivative_selector']['compile_failure_tag']=='DERIVATIVE_OPERATOR_INVALID',receipt['known_limitations']
    assert result.returncode==0 and not receipt['failed_facts'],result.stdout+result.stderr


if __name__=='__main__':
    main()
