#!/usr/bin/env wolframscript
$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[repoRoot <> "/mma/lib/MethodCardCore.wl"];
packageEntry = ExpandFileName[Last[CanonMethodCard`ScriptArguments[]]];
temporary = CreateDirectory[];
ClearAll[l1,l2,j,x,y,eps];
family="general-tail";
sector=<|"id"->7,"propagator_count"->3|>;
lowerSector=<|"id"->3,"propagator_count"->2|>;
put[name_,value_]:=(Put[value,temporary<>"/"<>name<>".wl"];
 <|"type"->"mathematica-expression","path"->temporary<>"/"<>name<>".wl"|>);
invoke[name_,script_,step_,sectorValue_,payload_]:=Module[{input,output,p},
 input=temporary<>"/"<>name<>".json";output=temporary<>"/"<>name;
 Export[input,<|"schema"->"canon-neu/script-input/v1","task_id"->name,
   "step"->step,"sector"->sectorValue,"payload"->payload|>,"RawJSON"];
 p=RunProcess[{"wolframscript","-file",repoRoot<>"/"<>script,input,output}];
 <|"output"->output,"result"->Import[output<>"/result.json","RawJSON"],"process"->p|>];
ref[run_,key_]:=<|"type"->"mathematica-expression",
 "path"->run["output"]<>"/"<>run["result","artifacts",key,"path"]|>;
read[run_,key_]:=Get[ref[run,key]["path"]];
seal[value_]:=Join[<|"prefix_id"->"sha256:"<>Hash[value,"SHA256","HexString"]|>,value];

runCase[name_,raw_,lowerMatrices_,expected_]:=Module[
 {cut,basis,ordered,accepted,basisRef,cutRef,orderedRef,acceptedRef,provider,core,full,tail,check,commit,final,
  canonical,preparedRef,masterRef,manifestRef},
 basis=<|"schema"->"canon-neu/sector-basis/v1","sector"->sector,
  "family_id"->family,"basis_id"->"raw/7","basis"->{j}|>;
 cut=Join[KeyDrop[basis,"schema"],<|"schema"->"canon-neu/sector-cut-de/v1",
  "coefficient_domain"->"exact-rational-functions","variables"->{x,y},"regulator"->eps,
  "matrices"->(#[[3;;3,3;;3]]&/@raw),"sector_boundaries"->{{1,1}}|>];
 ordered=<|"schema"->"canon-neu/ordered-master-de/v1","family_id"->family,
  "basis_id"->"raw","basis"->{l1,l2,j},"variables"->{x,y},"regulator"->eps,"matrices"->raw|>;
 accepted=seal[<|"schema"->"canon-neu/accepted-prefix/v1","family_id"->family,
  "source_basis"->{l1,l2},"basis"->{l1,l2},"transformation"->IdentityMatrix[2],
  "variables"->{x,y},"regulator"->eps,"alphabet"->{x,y},"matrices"->lowerMatrices,
  "sector_trace"->{lowerSector},"candidate_trace"->{<|"sector"->lowerSector|>}|>];
 basisRef=put[name<>"-basis",basis];cutRef=put[name<>"-cut",cut];
 orderedRef=put[name<>"-ordered",ordered];acceptedRef=put[name<>"-accepted",accepted];
 provider=invoke[name<>"-provider","methods/canonica/run.wls","SEARCH_CORE",sector,
  <|"sector_basis"->basisRef,"sector_cut_de"->cutRef,"method_options"-><|"package_entry"->packageEntry|>|>];
 core=invoke[name<>"-core","mma/CheckSectorCore.wls","CHECK_CORE",sector,
  <|"sector_basis"->basisRef,"sector_cut_de"->cutRef,"core_candidates"->ref[provider,"core_candidates"]|>];
 full=invoke[name<>"-full","mma/BuildFullSectorDE.wls","BUILD_FULL_DE",sector,
  <|"ordered_master_de"->orderedRef,"sector_cut_de"->cutRef,"core_candidates"->ref[provider,"core_candidates"],
   "core_transform"->ref[core,"core_transform"],"declared_alphabet"->Null,"accepted_prefix"->acceptedRef|>];
 tail=invoke[name<>"-tail","mma/SolveTail.wls","SOLVE_TAIL",sector,
  <|"full_sector_de"->ref[full,"full_sector_de"],"core_transform"->ref[core,"core_transform"],
   "method_options"-><|"package_entry"->packageEntry|>|>];
 check=invoke[name<>"-check","mma/CheckCanonical.wls","CHECK_CANONICAL",sector,
  <|"full_sector_de"->ref[full,"full_sector_de"],"sector_transform"->ref[tail,"sector_transform"]|>];
 commit=invoke[name<>"-commit","mma/CommitSector.wls","COMMIT_SECTOR",sector,
  <|"previous_accepted_prefix"->acceptedRef,"sector_basis"->basisRef,
   "sector_transform"->ref[tail,"sector_transform"],"canonical_sector_de"->ref[check,"canonical_sector_de"]|>];
 preparedRef=put[name<>"-prepared",<|"family_ref"->family,"basis_ref"->"raw","variables"->{x,y},"regulator"->eps|>];
 masterRef=put[name<>"-masters",<|"family_ref"->family,"basis_ref"->"raw","masters"->{l1,l2,j}|>];
 manifestRef=put[name<>"-manifest",<|"sectors"->{lowerSector,sector}|>];
 final=invoke[name<>"-final","mma/CheckFullSystem.wls","FINAL_CHECK",Null,
  <|"prepared_family"->preparedRef,"master_basis"->masterRef,"sector_manifest"->manifestRef,
   "ordered_master_de"->orderedRef,"accepted_prefix"->ref[commit,"accepted_prefix"]|>];
 canonical=read[final,"canonical_de"];
 <|"runs"->{provider,core,full,tail,check,commit,final},"prefix"->read[commit,"accepted_prefix"],
  "canonical"->canonical,"tail"->read[tail,"sector_transform"],"full"->read[full,"full_sector_de"]|>
];

n1=SparseArray[{{3,1}->1},{3,3}]//Normal;
n2=SparseArray[{{3,2}->1},{3,3}]//Normal;
canonical0={eps (IdentityMatrix[3]+n1)/x,eps (2 IdentityMatrix[3]+n2)/y};
knownT={{1,0,0},{0,1,0},{x,y,1}};
raw0=MapThread[Map[Together,(D[knownT,#2]+knownT.#1).Inverse[knownT],{2}]&,{canonical0,{x,y}}];
polynomial=runCase["polynomial",raw0,eps # IdentityMatrix[2]&/@{1/x,2/y},canonical0];
normalization=runCase["normalization",{eps n1/x,eps^2 n2/y},ConstantArray[ConstantArray[0,{2,2}],2],None];
rootT={{1,0,0},{0,1,0},{x/Sqrt[1+x+y],Sqrt[x y]/(1-x),1}};
rootRaw=MapThread[Map[Together,(D[rootT,#2]+rootT.#1).Inverse[rootT],{2}]&,{canonical0,{x,y}}];
algebraic=runCase["algebraic-affine",rootRaw,eps # IdentityMatrix[2]&/@{1/x,2/y},canonical0];
incoming=Normal[SparseArray[{{2,1}->1},{3,3}]];
incomingCase=runCase["incoming-normalization",{(eps incoming+eps^2 n1)/x,0 n1},
 {eps incoming[[1;;2,1;;2]]/x,ConstantArray[0,{2,2}]},None];


runDerivativeCase[name_, diagonal_:False] := Module[
 {q, mix, known, canonical, raw, selected, full, core, tail, check},
 q={{1,0,0},{0,1,1},{0,0,1}};
 mix={{1,0,0},{-eps^2 x^2/(y-1),1,0},{0,0,1}};
 known=q.mix;
 canonical={eps/x If[diagonal,{{0,0,0},{1,1,0},{0,0,2}},
    {{0,0,0},{1,0,1},{0,1,0}}],eps/y IdentityMatrix[3]};
 raw=MapThread[Map[Together,(D[known,#2]+known.#1).Inverse[known],{2}]&,
   {canonical,{x,y}}];
 selected=<|"candidate_id"->name,"member_candidate_ids"->{name},
   "new_basis_rows"->Inverse[q],"full_transformation"->q,
   "transformed_matrices"->CanonMethodCard`GaugeTransform[raw,{x,y},q]|>;
 full=<|"family_id"->family,"sector"->sector,"current_basis_id"->name,
   "accepted_prefix_id"->"unit-lower","source_basis"->{l1,j1,j2},
   "source_matrices"->raw,"variables"->{x,y},"regulator"->eps,
   "alphabet"->{x,y,y-1},"convention"->"old=T.new",
   "block_boundaries"-><|"lower_dimension"->1,"current_dimension"->2|>,
   "candidates"->{selected}|>;
 core=<|"candidate_id"->name|>;
 tail=invoke[name<>"-tail","mma/SolveTail.wls","SOLVE_TAIL",sector,
   <|"full_sector_de"->put[name<>"-full",full],
     "core_transform"->put[name<>"-core",core],
     "method_options"-><|"package_entry"->packageEntry|>|>];
 check=If[tail["result","code"]==="TAIL_READY",
   invoke[name<>"-check","mma/CheckCanonical.wls","CHECK_CANONICAL",sector,
     <|"full_sector_de"->put[name<>"-check-full",full],
       "sector_transform"->ref[tail,"sector_transform"]|>],None];
 <|"tail"->tail,"check"->check,"known"->known,
   "transformation"->If[tail["result","code"]==="TAIL_READY",
     read[tail,"sector_transform"]["transformation"],None]|>
];
coupledDerivative=runDerivativeCase["coupled-derivative"];
insufficientDerivative=runDerivativeCase["insufficient-derivative",True];

tests={
 VerificationTest[coupledDerivative["tail","result","summary","method"],
  "scalar-first-derivative-completion",TestID->"coupled-current-block-uses-one-simple-seed"],
 VerificationTest[coupledDerivative["check","result","code"],"CANONICAL_PASS",
  TestID->"derived-completion-passes-original-source-gauge-and-dlog-check"],
 VerificationTest[CanonMethodCard`ZeroMatrixQ[Map[Together,
   coupledDerivative["transformation"]-coupledDerivative["known"],{2}]],True,
  TestID->"derived-completion-recovers-independent-known-three-master-map"],
 VerificationTest[insufficientDerivative["tail","result","summary","method"],
  "canonica-off-diagonal",TestID->"rank-deficient-first-derivatives-do-not-adopt-a-completion"],
 VerificationTest[Last[algebraic["runs"]]["result","code"],"ALL_PASS",
  TestID->"algebraic-affine-tail-with-distinct-roots-is-repaired-in-all-directions"],
 VerificationTest[Quiet[Together[CanonMethodCard`AlgebraicPrimitive[{1,y},{x,y}]-x-y^2/2],Solve::svars],0,
  TestID->"nonhomogeneous-primitive-includes-all-polynomial-degrees"],
 VerificationTest[CanonMethodCard`AlgebraicPrimitive[{y,0},{x,y}],$Failed,
  TestID->"incompatible-partial-primitives-do-not-define-a-tail-repair"],
 VerificationTest[Last[incomingCase["runs"]]["result","code"],"ALL_PASS",
  TestID->"epsilon-normalization-preserves-incoming-couplings-outside-active-closure"],
 VerificationTest[Last[polynomial["runs"]]["result","code"],"ALL_PASS",
  TestID->"two-variable-nonzero-tail-from-real-DE-provider-through-final-check"],
 VerificationTest[polynomial["full","lower_basis"],{l1,l2},
  TestID->"core-only-provider-rows-embed-into-a-larger-raw-prefix"],
 VerificationTest[polynomial["tail","method"],"affine-epsilon-primitive",
  TestID->"off-diagonal-correction-is-solved-without-completion-candidates"],
 VerificationTest[CanonMethodCard`DLogConnectionQ[polynomial["canonical","matrices"],{x,y},eps,{x,y}],True,
  TestID->"shared-residues-hold-in-both-kinematic-directions"],
 VerificationTest[Last[normalization["runs"]]["result","code"],"ALL_PASS",
  TestID->"epsilon-normalization-is-composed-in-the-full-accepted-map"],
 VerificationTest[normalization["prefix","transformation"][[1;;2,1;;2]]=!=IdentityMatrix[2],True,
  TestID->"different-tail-epsilon-powers-can-renormalize-the-lower-prefix"],
 VerificationTest[CanonMethodCard`ZeroMatrixQ[{
   normalization["prefix","transformation"].normalization["prefix","basis"]-{l1,l2,j}}],True,
  TestID->"final-integral-basis-reproduces-the-raw-master-vector"]
};
report=TestReport[tests];
Print[InputForm[<|"total"->Length[tests],"succeeded"->report["TestsSucceededCount"],"failed"->report["TestsFailedCount"],"workspace"->temporary|>]];
If[report["TestsFailedCount"]>0,Print[InputForm[report["TestsFailed"]]],DeleteDirectory[temporary,DeleteContents->True]];
Exit[If[report["TestsFailedCount"]===0,0,1]];
