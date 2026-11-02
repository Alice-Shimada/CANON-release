#!/usr/bin/env wolframscript
$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot,"mma","lib","MethodCardCore.wl"}]];
Get[FileNameJoin[{repoRoot,"mma","lib","TailCompletion.wl"}]];
Get[FileNameJoin[{repoRoot,"mma","lib","PrefixComposition.wl"}]];
ClearAll[x,ep,l1,l2,j];
checks={};

assert[name_,ok_,detail_:<||>] := (AppendTo[checks,Join[<|"name"->name,"pass"->TrueQ[ok]|>,detail]];Print[name,"=",TrueQ[ok]]);
zeroQ[z_] := AllTrue[Flatten[z],TrueQ[Together[#]===0] &];
run[name_,a_,lower_,known_:None] := Module[{result,recomputed,ok,path},
 result=TimeConstrained[CanonRationalTailPoleRepair`Repair[a,x,ep,lower],60,$Aborted];
 ok=AssociationQ[result] && TrueQ[Lookup[result,"success",False]];
 assert[name<>"-solved",ok];
 If[ok,
  recomputed=CanonMethodCard`GaugeTransform[{a},{x},result["transformation"]];
  assert[name<>"-independent-gauge",zeroQ[First[recomputed]-result["matrices"]]];
  assert[name<>"-lower-preserved",zeroQ[result["matrices"][[1;;lower,1;;lower]]-a[[1;;lower,1;;lower]]]];
  assert[name<>"-core-preserved",zeroQ[result["matrices"][[lower+1;;Length[a],lower+1;;Length[a]]]-a[[lower+1;;Length[a],lower+1;;Length[a]]]]];
  assert[name<>"-all-poles-removed",TrueQ[result["after","fuchsian"]]];
  If[known=!=None,assert[name<>"-known-exact-shear",zeroQ[result["transformation"]-known]]]
 ];result
];
reject[name_,a_,lower_,code_,opts_:<||>] := Module[{result},
 result=CanonRationalTailPoleRepair`Repair[a,x,ep,lower,opts];
 assert[name,FailureQ[result] && First[result]===code,<|"actual"->ToString[result,InputForm]|>]
];
scalar={{0,0},{3/x^4,0}};known={{1,0},{-1/x^3,1}};
first=run["finite-order4",scalar,1,known];
infinity={{0,0},{6 x^2+1/(x-1),0}};known={{1,0},{2 x^3,1}};
second=run["infinity-degree2",infinity,1,known];
p={{1/x,0},{1/(x-1),-1/x}};
q={{2/x,1/(x-1)},{0,-1/x+1/(x-1)}};
canonical=ArrayFlatten[{{ep p,ConstantArray[0,{2,2}]},{ep {{1/x,2/(x-1)},{-1/(x-1),0}},ep q}}];
u={{1/(ep x^2)+x/(1-2ep),2/(x-1)},{1/((ep-1)(x+1)^2),x^3/ep}};
shear=IdentityMatrix[4];shear[[3;;4,1;;2]]=u;
inverseShear=IdentityMatrix[4];inverseShear[[3;;4,1;;2]]=-u;
old=Map[Together,shear.canonical.inverseShear+D[shear,x].inverseShear,{2}];
coupled=run["coupled-meromorphic",old,2,shear];
assert["coupled-all-rational-poles",AssociationQ[coupled] &&
 Sort[DeleteDuplicates[Lookup[coupled["before","finite_poles"],"root"]]]==={-1,0,1}];
assert["coupled-meromorphic-regulator-retained",AssociationQ[coupled] &&
 !FreeQ[coupled["transformation"],Power[ep,_Integer?Negative]]];
noop=run["already-dlog",canonical,2,IdentityMatrix[4]];
assert["already-dlog-no-steps",AssociationQ[noop] && noop["steps"]==={}];
reject["reject-quadratic-pole",{{0,0},{1/(x^2+1),0}},1,"UNSUPPORTED_POLE_FACTOR"];
reject["reject-moving-pole",{{0,0},{1/(x-ep)^2,0}},1,"UNSUPPORTED_MOVING_OR_NONRATIONAL_POLE"];
reject["reject-nonfuchsian-core",{{ep/x,0},{1/x,ep/x^2}},1,"NONFUCHSIAN_DIAGONAL"];
reject["reject-nonfuchsian-infinity",{{ep x,0},{1/x,ep/x}},1,"NONFUCHSIAN_DIAGONAL"];
reject["reject-nonepsilon-core",{{ep/x,0},{1/x,(1+ep)/x}},1,"DIAGONAL_NOT_EPSILON_FACTORIZED"];
reject["reject-undeclared-symbol",{{ep/x,0},{z/x,ep/x}},1,"UNSUPPORTED_COEFFICIENT_DOMAIN"];
reject["reject-algebraic-coefficient",{{ep/x,0},{Sqrt[2]/x,ep/x}},1,"UNSUPPORTED_COEFFICIENT_DOMAIN"];
reject["reject-upper-right",{{ep/x,1/x},{1/x,ep/x}},1,"NONZERO_UPPER_RIGHT"];
reject["reject-step-cap",old,2,"STEP_BOUND",<|"max_steps"->1|>];
reject["reject-operator-cap",old,2,"SYLVESTER_ENTRY_BOUND",<|"max_operator_entries"->1|>];
reject["reject-dimension-cap",old,2,"DIMENSION_BOUND",<|"max_dimension"->2|>];
reject["reject-unknown-option",old,2,"UNKNOWN_OPTIONS",<|"magic"->1|>];
reject["reject-empty-matrix",{},0,"INVALID_MATRIX"];
reject["reject-nonsquare-matrix",{{0,1,2},{0,1,2}},1,"INVALID_MATRIX"];
reject["reject-no-lower-tail",{{ep/x}},0,"NO_LOWER_TAIL_OUT_OF_SCOPE"];
assert["reject-variable-regulator-collision",MatchQ[CanonRationalTailPoleRepair`Repair[scalar,x,x,1],Failure["VARIABLE_REGULATOR_COLLISION",_Association]]];

(* Complete-prefix normalization after pole repair, with a regulator-singular
   gauge and two coupled lower/current masters. *)
g=DiagonalMatrix[{ep,ep,1/ep,1/ep}];
source=Map[Together,g.old.Inverse[g],{2}];
normalized=CanonTailCompletion`CompleteDLogTail[{source},{x},ep,2,{},30];
assert["post-D-full-prefix-normalization",TrueQ[normalized["solved"]]];
If[TrueQ[normalized["solved"]],
 computed=CanonMethodCard`GaugeTransform[{source},{x},normalized["transformation"]];
 assert["post-D-independent-source-gauge",zeroQ[computed-normalized["matrices"]]];
 assert["post-D-independent-epsilon-dlog",CanonMethodCard`DLogConnectionQ[computed,{x},ep,normalized["alphabet"]]];
 assert["post-D-independent-upper-right",zeroQ[computed[[All,1;;2,3;;4]]]];
 assert["post-D-pole-repair-evidence",normalized["diagnostics","pole_repair","corrections"]>0]
];
assert["loaded-normalizer-source-recorded",normalized["diagnostics","implementation","normalizer_sha256"]===
  FileHash[FileNameJoin[{repoRoot,"mma","lib","tail","DLogNormalization.wl"}],"SHA256","HexString"]];
assert["loaded-pole-helper-source-recorded",normalized["diagnostics","implementation","pole_repair_sha256"]===
  FileHash[FileNameJoin[{repoRoot,"mma","lib","tail","RationalPoleRepair.wl"}],"SHA256","HexString"]];

(* Noncommuting cumulative maps distinguish inverse order and avoid recursive
   accepted-basis expressions. A stale previous basis must not be trusted. *)
raw={J[1],J[2]}; lowerT={{2,1/x},{0,ep}};
lowerBasis=Inverse[lowerT].raw;
t={{1+ep,0,0},{x,1,0},{1/x,ep,2}};
composed=CanonPrefixComposition`ComposePrefix[raw,lowerBasis,lowerT,{J[3]},t];
base=ArrayFlatten[{{lowerT,ConstantArray[0,{2,1}]},{ConstantArray[0,{1,2}],{{1}}}}];
assert["prefix-noncommuting-map",zeroQ[composed["transformation"]-base.t]];
assert["prefix-compact-basis-equivalence",zeroQ[composed["basis"]-Inverse[t].Join[lowerBasis,{J[3]}]]];
assert["prefix-full-integral-definition",zeroQ[composed["transformation"].composed["basis"]-Join[raw,{J[3]}]]];
assert["prefix-stale-basis-rejected",FailureQ[CanonPrefixComposition`ComposePrefix[raw,2 lowerBasis,lowerT,{J[3]},t]]];
assert["prefix-duplicate-master-rejected",FailureQ[CanonPrefixComposition`ComposePrefix[raw,lowerBasis,lowerT,{J[2]},t]]];

(* Full exact kernel oracle: no dropped equations or free directions, even
   with zero rows, several letters and noncommuting residues. *)
Do[
 n=dimension; oracle=DiagonalMatrix[Table[(1+ep i)^If[EvenQ[i],1,-1],{i,n}]];
 rs=Table[Table[Mod[i+2 j+k,5]-2,{i,n},{j,n}],{k,2}];
 residues=Map[Together,oracle.(ep #).Inverse[oracle],{2}] & /@ rs;
 sampled=residues /. ep->1;
 kernel=CanonTailCompletion`Private`dlogSparseKernel[residues,sampled,ep,1];
 dense=Join @@ MapThread[KroneckerProduct[#1,IdentityMatrix[n]]-
   ep KroneckerProduct[IdentityMatrix[n],Transpose[#2]] &,{residues,sampled}];
 assert["kernel-complete-nullity-"<>ToString[n],Length[kernel["basis"]]===Length[NullSpace[dense]]];
 assert["kernel-full-exact-residual-"<>ToString[n],AllTrue[kernel["basis"],zeroQ[dense.#] &]],
 {dimension,{2,3,4}}];
qq=CanonTailCompletion`Private`dlogSparseKernel[{ep {{1,0},{0,2}}},{{{1,0},{0,2}}},ep,1];
assert["kernel-common-regulator-factor-yields-QQ-rows",qq["rational_row_count"]>0];

large=65; already={ep IdentityMatrix[large]/x};
largeFull=<|"variables"->{x},"regulator"->ep,"source_basis"->Range[large],"source_matrices"->already|>;
largeResult=CanonTailCompletion`Private`completeDLogEpsilon[largeFull,
  {{IdentityMatrix[large],already}},{x},30];
assert["already-canonical-prefix-above-old-dimension-cap",TrueQ[largeResult["solved"]] &&
  largeResult["transformation"]===IdentityMatrix[large]];
badFull=<|"variables"->{x},"regulator"->ep,"source_basis"->{1,2},
  "source_matrices"->{{{ep/x,ep/x},{0,ep/x}}}|>;
badFrame={{{ep/x,0},{0,ep/x}}};
badResult=CanonTailCompletion`Private`completeDLogEpsilon[badFull,
  {{IdentityMatrix[2],badFrame}},{x},10];
assert["complete-source-differential-identity-rejects-wrong-frame",!TrueQ[badResult["solved"]]];
wallResult=CanonTailCompletion`CompleteDLogTail[{source},{x},ep,2,{},0.001];
assert["post-D-common-wall-budget-is-retained",!TrueQ[wallResult["solved"]] &&
  wallResult["diagnostics","stage"]==="wall_budget"];

all=AllTrue[checks,TrueQ[#["pass"]] &];
summary=<|"total"->Length[checks],"succeeded"->Count[Lookup[checks,"pass"],True],"failed"->Count[Lookup[checks,"pass"],False]|>;
Print[InputForm[summary]];
If[CanonMethodCard`ScriptArguments[] =!= {},Export[Last[CanonMethodCard`ScriptArguments[]],summary,"RawJSON"]];
Quit[If[all,0,1]];
