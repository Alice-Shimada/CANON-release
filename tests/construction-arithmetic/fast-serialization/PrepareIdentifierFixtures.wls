$HistoryLength=0;
args=If[ListQ[$ScriptCommandLine]&&Length[$ScriptCommandLine]>1,Rest[$ScriptCommandLine],Drop[$CommandLine,First@FirstPosition[$CommandLine,"-script"]+1]];
{repoRoot,inputPath,outputDir}=ExpandFileName/@args;Get[repoRoot<>"/mma/lib/MethodCardCore.wl"];
task=CanonMethodCard`ReadTask[inputPath,"PREPARE_SERIALIZER_IDENTIFIERS"];
a=Symbol["CanonFirst`x"];b=Symbol["CanonSecond`x"];u=Symbol["CanonUnicode`"<>FromCharacterCode[945]];
CanonMethodCard`WriteWLArtifact[{{a+2b,(a^2-b^2)/(a-b)}},outputDir,"contexts.wl"];
CanonMethodCard`WriteWLArtifact[{{u+1,(u^2-1)/(u-1)}},outputDir,"unicode.wl"];
CanonMethodCard`WriteResult[task,outputDir,"PASS","IDENTIFIERS_PREPARED",<|"contexts"-><|"type"->"mathematica-expression","path"->"contexts.wl"|>,"unicode"-><|"type"->"mathematica-expression","path"->"unicode.wl"|>|>,<|"scientific_acceptance"->False|>];Quit[0];
