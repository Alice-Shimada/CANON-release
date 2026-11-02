$HistoryLength=0;
scriptArgs=If[ListQ[$ScriptCommandLine]&&Length[$ScriptCommandLine]>1,Rest[$ScriptCommandLine],
 Drop[$CommandLine,First@FirstPosition[$CommandLine,"-script"]+1]];
{repoRoot,inputPath,outputDir}=ExpandFileName /@ scriptArgs;
Get[repoRoot<>"/mma/lib/MethodCardCore.wl"];
task=CanonMethodCard`ReadTask[inputPath,"NORMALIZE_FERMAT_FIXTURE"];
helper=CanonMethodCard`ResolveArtifactPath[inputPath,task["payload","arithmetic_helper"]];
If[FailureQ[helper]||Quiet@Check[Get[helper];True,False]=!=True,
 CanonMethodCard`WriteResult[task,outputDir,"ERROR","ARITHMETIC_BACKEND_UNAVAILABLE",<||>,<|"scientific_acceptance"->False|>];Quit[1]];
CanonFFT`InitializeArithmetic[task,inputPath,outputDir];
matrixPath=CanonMethodCard`ResolveArtifactPath[inputPath,task["payload","matrix"]];
matrix=If[FailureQ[matrixPath],matrixPath,Quiet@Check[CanonMethodCard`ReadWLData[matrixPath],$Failed]];
If[!MatrixQ[matrix],CanonMethodCard`WriteResult[task,outputDir,"ERROR","INVALID_FIXTURE_INPUT",<||>,<|"scientific_acceptance"->False|>];Quit[1]];
result=CanonFFT`NormalizeMatrix["candidate_lower_transform_reduce",matrix];
CanonMethodCard`WriteWLArtifact[result,outputDir,"normalized.wl"];
CanonMethodCard`WriteResult[task,outputDir,"PASS","NORMALIZED",<|"normalized"-><|"type"->"mathematica-expression","path"->"normalized.wl"|>|>,<|"scientific_acceptance"->False|>];
Quit[0];
