#!/usr/bin/env wolframscript
{outputDir}=ExpandFileName /@ Rest[$ScriptCommandLine];
repoRoot=DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot,"mma","lib","MethodCardCore.wl"}]];
Get[FileNameJoin[{repoRoot,"mma","lib","SectorDE.wl"}]];
CreateDirectory[outputDir];
barePath=FileNameJoin[{outputDir,"bare.wl"}];
explicitPath=FileNameJoin[{outputDir,"explicit.wl"}];
Export[barePath,"<|\"head\"->F[1],\"variables\"->{x},\"dimension_rule\"->(d->4-2 eps),\"operators\"-><|x->eps|>|>","Text"];
Export[explicitPath,"<|\"head\"->CANON`DEData`F[1],\"variables\"->{CANON`DEData`x},\"dimension_rule\"->(CANON`DEData`d->4-2 CANON`DEData`eps),\"operators\"-><|CANON`DEData`x->CANON`DEData`eps|>|>","Text"];
bare=CanonMethodCard`ReadWLData[barePath];
explicit=CanonMethodCard`ReadWLData[explicitPath];
value=<|"data"->CANON`DEData`u,"foreign"->Foreign`u,"other"->Other`v,
  "global"->Global`external,"held"->HoldComplete[Foreign`q[CANON`DEData`x]]|>;
roundtripPath=Block[{$Context="Global`",$ContextPath={"System`","Foreign`","Other`"}},
  CanonMethodCard`WriteWLArtifact[value,outputDir,"roundtrip.wl"]];
roundtrip=CanonMethodCard`ReadWLData[roundtripPath];
request=<|"payload"-><|"data"-><|"path"->"bare.wl"|>|>|>;
prepared=<|"family_ref"->"context-unit","basis_ref"->"context-unit/source",
  "variables"->{CANON`DEData`x},"index_order"->{"D1"}|>;
masters=<|"family_ref"->"context-unit","basis_ref"->"context-unit/source",
  "masters"->{CANON`DEData`F[1]}|>;
derivativeText="<|\"schema\"->\"canon.prepared-derivatives/v2\",\"variables\"->{SOURCE},\"denominator_count\"->1,\"operators\"-><|SOURCE->{<|\"constant\"->SOURCE,\"linear\"->{}|>}|>|>";
loadDerivative[name_,sourceName_,mapping_]:=Module[{path},
  path=FileNameJoin[{outputDir,name<>".wl"}];
  Export[path,StringReplace[derivativeText,"SOURCE"->sourceName],"Text"];
  CANON`SectorDE`LoadPreparedDerivatives[
    Join[prepared,<|"operator_source_symbol_map"->mapping|>],barePath,masters,path]];
mappedBare=loadDerivative["bare-derivative","u",<|"u"->"x"|>];
mappedForeign=loadDerivative["foreign-derivative","Foreign`u",<|"Foreign`u"->"x"|>];
unmappedForeign=loadDerivative["unmapped-derivative","Foreign`u",<||>];
mappedExplicit=loadDerivative["explicit-derivative","CANON`DEData`u",
  <|"CANON`DEData`u"->"CANON`DEData`x"|>];
expectedOperators=<|CANON`DEData`x->{<|"constant"->CANON`DEData`x,"linear"->{}|>}|>;
facts=<|
  "bare_and_explicit_data_agree"->(bare===explicit),
  "loader_isolates_caller_context"->(Block[{$Context="Caller`",$ContextPath={"System`","Foreign`","Global`"}},
    CanonMethodCard`ReadWLData[barePath]]===bare),
  "load_artifact_uses_data_reader"->(CanonMethodCard`LoadArtifact[request,FileNameJoin[{outputDir,"input.json"}],"data"]===bare),
  "writer_roundtrip_preserves_all_contexts"->(roundtrip===value),
  "same_name_foreign_symbols_stay_distinct"->(roundtrip["foreign"]===Foreign`u && roundtrip["data"]===CANON`DEData`u && roundtrip["foreign"]=!=roundtrip["data"]),
  "bare_string_map_uses_data_context"->(!FailureQ[mappedBare] && mappedBare["derivatives","operators"]===expectedOperators),
  "explicit_string_map_preserved"->(!FailureQ[mappedExplicit] && mappedExplicit["derivatives","operators"]===expectedOperators),
  "declared_foreign_map_is_applied"->(!FailureQ[mappedForeign] && mappedForeign["derivatives","operators"]===expectedOperators),
  "unmapped_foreign_operator_rejected"->(FailureQ[unmappedForeign] && unmappedForeign[[1]]==="INVALID_PREPARED_DERIVATIVES")|>;
Export[FileNameJoin[{outputDir,"facts.json"}],facts,"RawJSON"];
Print[InputForm[facts]];
Exit[If[And@@Values[facts],0,1]];
