$HistoryLength=0;
scriptArgs = If[ListQ[$ScriptCommandLine] && Length[$ScriptCommandLine] > 1,
  Rest[$ScriptCommandLine], Drop[$CommandLine, First @ FirstPosition[$CommandLine, "-script"] + 1]];
{repoRoot,inputPath,outputDir}=ExpandFileName /@ scriptArgs;
Get[FileNameJoin[{repoRoot,"mma","lib","MethodCardCore.wl"}]];
task=CanonMethodCard`ReadTask[inputPath,"VERIFY_FFT_FIXTURES"];
base=task["payload","fixture_directory"];results=task["payload","result_directory"];
same[a_,b_] := Dimensions[a]===Dimensions[b]&&AllTrue[Flatten[a-b],TrueQ[FullSimplify[Together[#]]===0]&];
checks=Association@Table[name->Module[{receipt,expected,full,candidate,identity,runtime,events,backend},
 receipt=Import[results<>"/"<>name<>"/result.json","RawJSON"];
 If[MemberQ[{"unsupported-cubic","native-unavailable","failed-reconstruction"},name],
   <|"scoped_error"->(receipt["status"]==="ERROR"&&receipt["code"]===
     Switch[name,"unsupported-cubic","UNSUPPORTED_ARITHMETIC_DOMAIN",
       "failed-reconstruction","ARITHMETIC_RECONSTRUCTION_FAILED",_,"ARITHMETIC_BACKEND_UNAVAILABLE"]),
     "no_full_artifact"->!FileExistsQ[results<>"/"<>name<>"/full-sector-de.wl"],
     "requested_backend_preserved"->(receipt["summary","normalization_backend"]==="finiteflow")|>,
 expected=CanonMethodCard`ReadWLData[base<>"/"<>If[name==="default-unavailable","default",name]<>"-expected.wl"];
 full=CanonMethodCard`ReadWLData[results<>"/"<>name<>"/full-sector-de.wl"];
 candidate=First[full["candidates"]];
 identity=MapThread[#1.expected["raw_transformation"]-D[expected["raw_transformation"],#2]-
   expected["raw_transformation"].#3&,{expected["raw"],full["variables"],candidate["transformed_matrices"]}];
 runtime=Import[results<>"/"<>name<>"/arithmetic-runtime.json","RawJSON"];
 events=Import[results<>"/"<>name<>"/normalization-events.jsonl","Lines"];
 events=ImportString[#,"RawJSON"]&/@events;
 backend=If[MemberQ[{"default","default-unavailable"},name],"together","finiteflow"];
 <|"public_pass"->(receipt["status"]==="PASS"),"row_map"->same[candidate["new_basis_rows"],expected["mixed_rows"]],
   "inverse_direction"->same[candidate["full_transformation"],expected["mixed_transformation"]],
   "source_matrices"->same[full["source_matrices"],expected["source_matrices"]],
   "source_composition"->same[full["accepted_prefix_transformation"].candidate["full_transformation"],expected["raw_transformation"]],
   "independent_expected_target"->same[candidate["transformed_matrices"],expected["target"]],
   "independent_raw_gauge_identity"->AllTrue[identity,CanonMethodCard`ZeroMatrixQ],
   "backend_recorded"->(runtime["backend"]===backend),
   "native_and_threads"->If[backend==="finiteflow",TrueQ[runtime["native_loaded"]]&&
     runtime["finiteflow_threads"]===1&&runtime["reconstruction_NThreads"]===1&&runtime["FFNThreads"]===1,True],
   "all_requested_operations_closed"->(Count[Lookup[events,"event"],"start"]===Count[Lookup[events,"event"],"end"]&&
     Count[Lookup[events,"event"],"start"]>0),
   "only_selected_backend"->AllTrue[events,Lookup[#,"backend",backend]===backend&]|>
 ]],{name,{"rational-nonzero","root-nonzero","no-prefix","default","unsupported-cubic","native-unavailable","default-unavailable","failed-reconstruction"}}];
all=AllTrue[Values[checks],AllTrue[Values[#],TrueQ]&];
Export[outputDir<>"/checks.json",<|"all_pass"->all,"checks"->checks,"scientific_acceptance"->False,
  "method"->"Exact manufactured target matrices plus independent raw gauge and full transformation identities, using System Together/FullSimplify only in this tiny verifier."|>,"RawJSON"];
CanonMethodCard`WriteResult[task,outputDir,If[all,"PASS","FAIL"],"FIXTURE_CHECKS",
  <|"checks"-><|"type"->"json","path"->"checks.json"|>|>,<|"all_pass"->all,"scientific_acceptance"->False|>];
Quit[If[all,0,1]];
