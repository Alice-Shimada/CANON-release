#!/usr/bin/env wolframscript
$HistoryLength=0;
{repoRoot,inputPath,outputDir}=ExpandFileName /@ Rest[$ScriptCommandLine];
Get[repoRoot<>"/mma/lib/MethodCardCore.wl"];
task=CanonMethodCard`ReadTask[inputPath,"VERIFY_BLOCK_FIXTURES"];
base=task["payload","fixture_directory"];results=task["payload","result_directory"];
load[path_]:=CanonMethodCard`ReadWLData[path];
same[a_,b_]:=Dimensions[a]===Dimensions[b]&&AllTrue[Flatten[a-b],TrueQ[FullSimplify[Together[#]]===0]&];
names={"zero","lower-nonzero","upper-nonzero","no-prefix","inexact-upper","inexact-rows","malformed-rows"};
checks=Association@Table[name->Module[{res,exp,full,candidate,t,variables,identity,facts},
 res=Import[results<>"/"<>name<>"/result.json","RawJSON"];
 exp=load[base<>"/"<>name<>"-expected.wl"];
 If[MemberQ[{"inexact-rows","malformed-rows"},name],<|
   "rejected"->(res["status"]==="ERROR"&&res["code"]==="INVALID_FULL_DE_INPUT"),
   "no_full_artifact"->!FileExistsQ[results<>"/"<>name<>"/full-sector-de.wl"]|>,
 full=load[results<>"/"<>name<>"/full-sector-de.wl"];candidate=First[full["candidates"]];
 variables=full["variables"];t=exp["raw_transformation"];
 identity=MapThread[#1.t-D[t,#2]-t.#3&,{exp["raw"],variables,candidate["transformed_matrices"]}];
 facts=<|"public_pass"->(res["status"]==="PASS"),
   "fast_branch"->(TrueQ[res["summary","zero_lower_block_assembly"]]===exp["expected_fast"]),
   "row_map"->same[candidate["new_basis_rows"],exp["mixed_rows"]],
   "inverse_direction"->same[candidate["full_transformation"],exp["mixed_transformation"]],
   "source_matrices"->same[full["source_matrices"],exp["source_matrices"]],
   "source_composition"->same[full["accepted_prefix_transformation"].candidate["full_transformation"],t],
   "known_target"->same[candidate["transformed_matrices"],exp["target"]],
   "independent_gauge_identity"->AllTrue[identity,CanonMethodCard`ZeroMatrixQ],
   "variables_preserved"->(variables===exp["variables"]),
   "source_positions"->(full["source_positions"]===Range[Length[First[exp["raw"]]]])|>;
 If[name==="inexact-upper",facts=KeyDrop[facts,{"known_target","independent_gauge_identity"}]];
 facts
 ]
],{name,names}];
all=AllTrue[Values[checks],AllTrue[Values[#],TrueQ]&];
Export[outputDir<>"/fixture-checks.json",<|"all_pass"->all,"checks"->checks,
 "check_count"->Total[Length/@Values[checks]],"scope"->"component capability; inexact-upper tests fallback selection only"|>,"RawJSON"];
CanonMethodCard`WriteResult[task,outputDir,If[all,"PASS","FAIL"],"FIXTURE_CHECKS",
 <|"checks"-><|"type"->"json","path"->"fixture-checks.json"|>|>,<|"all_pass"->all,"scientific_acceptance"->False|>];
Quit[If[all,0,1]];
