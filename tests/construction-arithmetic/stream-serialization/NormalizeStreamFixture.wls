$HistoryLength=0;
args=If[ListQ[$ScriptCommandLine]&&Length[$ScriptCommandLine]>1,Rest[$ScriptCommandLine],Drop[$CommandLine,First@FirstPosition[$CommandLine,"-script"]+1]];
{repoRoot,inputPath,outputDir}=ExpandFileName/@args;
Get[repoRoot<>"/mma/lib/MethodCardCore.wl"];
task=CanonMethodCard`ReadTask[inputPath,"NORMALIZE_FLINT_BOUNDARY"];
helper=CanonMethodCard`ResolveArtifactPath[inputPath,task["payload","normalizer"]];
exe=CanonMethodCard`ResolveArtifactPath[inputPath,task["payload","native_executable"]];
If[FailureQ[helper]||FailureQ[exe]||Quiet@Check[Get[helper];True,False]=!=True||DownValues[CanonFlintNormalize`Normalize]==={},
 CanonMethodCard`WriteResult[task,outputDir,"ERROR","BACKEND_UNAVAILABLE",<||>,<|"scientific_acceptance"->False|>];Quit[1]];
source=CanonMethodCard`ResolveArtifactPath[inputPath,task["payload","matrix"]];
matrix=If[FailureQ[source],$Failed,CanonMethodCard`ReadWLData[source]];
If[!MatrixQ[matrix],CanonMethodCard`WriteResult[task,outputDir,"ERROR","INVALID_MATRIX_INPUT",<||>,<||>];Quit[1]];
started=AbsoluteTime[];
logger[label_,state_,extra_]:=Module[{stream=OpenAppend[outputDir<>"/normalization-events.jsonl"]},WriteString[stream,ExportString[Join[<|"operation"->label,"state"->state,"elapsed_seconds"->N[AbsoluteTime[]-started]|>,extra],"RawJSON","Compact"->True]<>"\n"];Close[stream]];
serializer=If[KeyExistsQ[task["payload"],"serializer"],CanonFlintNormalize`CheckedSerializer[inputPath,task["payload","serializer"]],None];
If[serializer=!=None&&!AssociationQ[serializer],CanonMethodCard`WriteResult[task,outputDir,"ERROR","SERIALIZER_UNAVAILABLE",<||>,<|"scientific_acceptance"->False|>];Quit[1]];
streamsBefore=Streams[];fault=Lookup[task["payload"],"stream_fault",None];faultCount=0;closeCount=0;
fullformPath=outputDir<>"/normalization/matrix.fullform";
NormalizeFixture::injected="Controlled stream failure for boundary regression.";
If[fault==="open_directory",CreateDirectory[fullformPath,CreateIntermediateDirectories->True]];
invoke[]:=If[serializer===None,CanonFlintNormalize`Normalize[matrix,exe,outputDir<>"/normalization",logger],CanonFlintNormalize`Normalize[matrix,exe,outputDir<>"/normalization",logger,serializer]];
If[MemberQ[{"write_failed","write_message","close_failed","abort_write"},fault],
 savedWriteValues=DownValues[WriteString];savedCloseValues=DownValues[Close];Unprotect[WriteString,Close];
 WriteString[s_OutputStream,a___]/;First[s]===fullformPath&&MemberQ[{"write_failed","write_message","abort_write"},fault]:=
  (faultCount++;If[fault==="abort_write",Abort[]];If[fault==="write_message",Message[NormalizeFixture::injected]];$Failed);
 Close[s_OutputStream]/;First[s]===fullformPath&&fault==="close_failed"&&closeCount++===0:= (faultCount++;$Failed);
 result=CheckAbort[invoke[],Failure["EXPORT_ABORTED",<|"Message"->"Controlled abort during owned output stream write."|>]];
 DownValues[WriteString]=savedWriteValues;DownValues[Close]=savedCloseValues;Protect[WriteString,Close],
 result=invoke[]];
streamsAfter=Streams[];streamFacts=<|"owned_output_streams_closed"->(Complement[streamsAfter,streamsBefore]==={}),"fault"->If[fault===None,Null,fault],"streams_before"->(ToString[#,InputForm]&/@streamsBefore),"streams_after"->(ToString[#,InputForm]&/@streamsAfter),"new_streams"->(ToString[#,InputForm]&/@Complement[streamsAfter,streamsBefore]),"owned_fullform_stream_closed"->(!AnyTrue[streamsAfter,First[#]===fullformPath&]),"injected_failures"->faultCount,"close_attempts"->closeCount|>;
Export[outputDir<>"/stream-lifetime.json",streamFacts,"RawJSON"];

Export[outputDir<>"/call.json",<|"normalize_seconds"->N[AbsoluteTime[]-started],"input_sha256"->FileHash[source,"SHA256","HexString"],
 "input_dimensions"->Dimensions[matrix],"input_leaf_count"->LeafCount[matrix],"helper_sha256"->FileHash[helper,"SHA256","HexString"],"executable_sha256"->FileHash[exe,"SHA256","HexString"],
 "clock_scope"->"Same-kernel AbsoluteTime; normalize call excludes kernel/input loading but includes all internal phases and native/readback. Host whole-call accounting is separate."|>,"RawJSON"];
If[FailureQ[result],CanonMethodCard`WriteResult[task,outputDir,"ERROR",result[[1]],<||>,<|"reason"->ToString[result,InputForm],"scientific_acceptance"->False|>];Quit[1]];
CanonMethodCard`WriteWLArtifact[result["matrix"],outputDir,"normalized.wl"];
CanonMethodCard`WriteResult[task,outputDir,"PASS","NORMALIZED",<|"normalized"-><|"type"->"mathematica-expression","path"->"normalized.wl"|>|>,<|"scientific_acceptance"->False|>];Quit[0];
