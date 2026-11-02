#!/usr/bin/env wolframscript
$HistoryLength=0;
scriptArgs = If[ListQ[$ScriptCommandLine] && Length[$ScriptCommandLine] > 1,
  Rest[$ScriptCommandLine], Drop[$CommandLine, First @ FirstPosition[$CommandLine, "-script"] + 1]];
{repoRoot,inputPath,outputDir}=ExpandFileName /@ scriptArgs;
Get[repoRoot<>"/mma/lib/MethodCardCore.wl"];
task=CanonMethodCard`ReadTask[inputPath,"PREPARE_BLOCK_FIXTURES"];
If[!DirectoryQ[outputDir],CreateDirectory[outputDir,CreateIntermediateDirectories->True]];
{x,y,eps}=Symbol /@ {"CANON`DEData`x","CANON`DEData`y","CANON`DEData`eps"};
f=Symbol["CANON`DEData`f"];
variables={x,y};lowerBasis={f[1],f[2]};currentBasis={f[3],f[4],f[5]};
lowerT={{x,0},{y,1+x}};
q={{eps^3*x,eps^3*y,0},{0,eps^4*(1+x),eps^4},{0,0,eps^3*Sqrt[1+x+y]}};
sector=<|"id"->7,"propagator_count"->3|>;
family="zero-lower-block-capability";basisID="fixture/current";
normalize[m_]:=Map[Together,m,{2}];
put[name_,value_]:=(CanonMethodCard`WriteWLArtifact[value,outputDir,name<>".wl"];<|"path"->name<>".wl"|>);
fixtures={};
make[name_,p_,upper_:False,noLower_:False,inexact_:False,badRows_:False,badShape_:False]:=Module[
 {n,t0,u,w,invq,target,raw,accepted,basis,cut,pool,core,rows,refs,request,expected},
 n=If[noLower,3,5];invq=normalize[Inverse[q]];
 t0=If[noLower,IdentityMatrix[3],ArrayFlatten[{{lowerT,ConstantArray[0,{2,3}]},{ConstantArray[0,{3,2}],IdentityMatrix[3]}}]];
 u=If[noLower,q,ArrayFlatten[{{IdentityMatrix[2],ConstantArray[0,{2,3}]},{p,q}}]];
 w=normalize[t0.Inverse[u]];
 target={eps*DiagonalMatrix[Range[n]]/x,eps*DiagonalMatrix[Range[n]+1]/y};
 If[upper,target[[1,1,3]]=1/x];
 raw=MapThread[normalize[(D[w,#2]+w.#1).Inverse[w]]&,{target,variables}];
 If[inexact,raw[[1,1,3]]=0.];
 accepted=If[noLower,Null,<|"schema"->"canon-neu/accepted-prefix/v1","prefix_id"->"fixture/lower",
   "family_id"->family,"source_basis"->lowerBasis,"basis"->Inverse[lowerT].lowerBasis,
   "transformation"->lowerT,"variables"->variables,"regulator"->eps,"matrices"->(#[[1;;2,1;;2]]&/@target)|>];
 basis=If[noLower,currentBasis,Join[lowerBasis,currentBasis]];
 cut=<|"schema"->"canon-neu/sector-cut-de/v1","sector"->sector,"family_id"->family,
   "basis_id"->basisID,"coefficient_domain"->"exact-algebraic-functions","basis"->currentBasis,
   "variables"->variables,"regulator"->eps,"matrices"->(#[[-3;;-1,-3;;-1]]&/@raw)|>;
 rows=If[noLower,q,ArrayFlatten[{{normalize[p.Inverse[lowerT]],q}}]];
 If[badRows,rows[[1,1]]=0.];If[badShape,rows=Take[rows,2]];
 pool=<|"schema"->"canon-neu/core-candidates/v1","sector"->sector,"family_id"->family,
   "basis_id"->basisID,"coefficient_domain"->"exact-algebraic-functions","basis"->currentBasis,
   "variables"->variables,"regulator"->eps,"convention"->"old_basis = transformation . new_basis",
   "source_basis"->basis,"candidates"->{<|"candidate_id"->"fixture/candidate","member_candidate_ids"->{"fixture/member"},
     "construction_rejection"->None,"transformation"->invq,"full_new_basis_rows"->rows,
     "transformed_matrices"->(#[[-3;;-1,-3;;-1]]&/@target)|>}|>;
 core=<|"schema"->"canon-neu/core-transform/v1","sector"->sector,"family_id"->family,
   "basis_id"->basisID,"basis"->currentBasis,"variables"->variables,"regulator"->eps,
   "candidate_id"->"fixture/candidate","transformation"->invq,"checks"-><|"pass"->True|>|>;
 refs=<|"ordered_master_de"->put[name<>"-ordered",<|"schema"->"canon-neu/ordered-master-de/v1",
     "family_id"->family,"basis"->basis,"variables"->variables,"regulator"->eps,"matrices"->raw|>],
   "sector_cut_de"->put[name<>"-cut",cut],"core_candidates"->put[name<>"-pool",pool],
   "core_transform"->put[name<>"-core",core],"declared_alphabet"->Null,
   "accepted_prefix"->If[noLower,Null,put[name<>"-accepted",accepted]]|>;
 request=<|"schema"->"canon-neu/script-input/v1","task_id"->"T045-fixture-"<>name,
   "step"->"BUILD_FULL_DE","sector"->sector,"payload"->Join[refs,<|"method_options"-><|"diagnostic_max_seconds"->90|>|>]|>;
 Export[outputDir<>"/"<>name<>".json",request,"RawJSON"];
 expected=<|"variables"->variables,"target"->target,"raw"->raw,"raw_transformation"->w,
   "mixed_rows"->u,"mixed_transformation"->normalize[Inverse[u]],"source_transform"->t0,
   "source_matrices"->MapThread[normalize[Inverse[t0].(#1.t0-D[t0,#2])]&,{raw,variables}],
   "expected_fast"->(!noLower&&!upper&&!inexact&&!badRows&&!badShape&&p===ConstantArray[0,{3,2}])|>;
 put[name<>"-expected",expected];AppendTo[fixtures,name];
];
make["zero",ConstantArray[0,{3,2}]];
make["lower-nonzero",{{y,0},{0,x},{x+y,1}}];
make["upper-nonzero",ConstantArray[0,{3,2}],True];
make["no-prefix",{},False,True];
make["inexact-upper",ConstantArray[0,{3,2}],False,False,True];
make["inexact-rows",ConstantArray[0,{3,2}],False,False,False,True];
make["malformed-rows",ConstantArray[0,{3,2}],False,False,False,False,True];
Export[outputDir<>"/fixtures.json",<|"names"->fixtures,"scope"->"known-answer capability fixtures only"|>,"RawJSON"];
CanonMethodCard`WriteResult[task,outputDir,"PASS","FIXTURES_PREPARED",
 <|"fixtures"-><|"type"->"json","path"->"fixtures.json"|>|>,<|"scientific_acceptance"->False,"count"->Length[fixtures]|>];
