$HistoryLength=0;
scriptArgs=If[ListQ[$ScriptCommandLine]&&Length[$ScriptCommandLine]>1,Rest[$ScriptCommandLine],Drop[$CommandLine,First@FirstPosition[$CommandLine,"-script"]+1]];
{repoRoot,inputPath,outputDir}=ExpandFileName /@ scriptArgs;
Get[repoRoot<>"/mma/lib/MethodCardCore.wl"];
task=CanonMethodCard`ReadTask[inputPath,"EARLY_ARITHMETIC_RUNTIME_FIXTURE"];
helper=CanonMethodCard`ResolveArtifactPath[inputPath,task["payload","arithmetic_helper"]];
If[FailureQ[helper]||Quiet@Check[Get[helper];True,False]=!=True,CanonMethodCard`WriteResult[task,outputDir,"ERROR","FIXTURE_SETUP_ERROR",<||>,<|"scientific_acceptance"->False|>];Quit[1]];
(* The public launcher has a healthy host configuration. Only the explicitly
   supplied method boundary is changed; no matrix or native call is needed. *)
inner=Join[task,<|"payload"->Join[task["payload"],<|"method_options"->task["payload","inner_method_options"]|>]|>];
CanonFFT`InitializeArithmetic[inner,inputPath,outputDir];
CanonMethodCard`WriteResult[task,outputDir,"FAIL","UNEXPECTED_INITIALIZATION",<||>,<|"scientific_acceptance"->False|>];Quit[1];
