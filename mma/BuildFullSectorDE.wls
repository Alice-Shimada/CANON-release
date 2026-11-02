#!/usr/bin/env wolframscript

$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "BUILD_FULL_DE"];
If[Quiet @ Check[Get[FileNameJoin[{repoRoot, "mma", "lib", "ConstructionArithmetic.wl"}]]; True, False] =!= True,
  CanonMethodCard`WriteResult[task, outputDir, "ERROR", "ARITHMETIC_BACKEND_UNAVAILABLE", <||>,
    <|"reason" -> "Construction arithmetic helper did not load.", "scientific_acceptance" -> False|>]; Quit[1]];
If[DownValues[CanonFFT`InitializeArithmetic] === {} || DownValues[CanonFFT`NormalizeMatrix] === {} ||
  Quiet @ Check[CanonFFT`InitializeArithmetic[task, inputPath, outputDir];
    AssociationQ[Import[FileNameJoin[{outputDir, "arithmetic-runtime.json"}], "RawJSON"]], False] =!= True,
  CanonMethodCard`WriteResult[task, outputDir, "ERROR", "ARITHMETIC_BACKEND_UNAVAILABLE", <||>,
    <|"reason" -> "Construction arithmetic initialization did not complete.", "scientific_acceptance" -> False|>]; Quit[1]];
ordered = CanonMethodCard`LoadArtifact[task, inputPath, "ordered_master_de"];
cut = CanonMethodCard`LoadArtifact[task, inputPath, "sector_cut_de"];
coreCandidates = CanonMethodCard`LoadArtifact[task, inputPath, "core_candidates"];
coreTransform = CanonMethodCard`LoadArtifact[task, inputPath, "core_transform"];
alphabet = If[task["payload", "declared_alphabet"] === Null, {},
  CanonMethodCard`LoadArtifact[task, inputPath, "declared_alphabet"]["letters"]];
accepted = If[task["payload", "accepted_prefix"] === Null, Null,
  CanonMethodCard`LoadArtifact[task, inputPath, "accepted_prefix"]];

invalid[code_, reason_] := (CanonMethodCard`WriteResult[task, outputDir, "ERROR",
  code, <||>, <|"reason" -> reason, "preferred_next_route" -> "FIX_INPUT"|>]; Quit[1]);
fail[reason_] := (CanonMethodCard`WriteResult[task, outputDir, "ERROR",
  "INVALID_FULL_DE_INPUT", <||>, <|"reason" -> reason|>]; Quit[1]);
If[!AllTrue[{ordered, cut, coreCandidates, coreTransform}, AssociationQ] ||
  !TrueQ[CanonMethodCard`ValidCutDEQ[cut, True] && CanonMethodCard`ValidCandidatesQ[coreCandidates]] ||
  !AllTrue[{"family_id", "basis_id", "basis", "variables", "regulator"},
    SameQ[cut[#], coreCandidates[#], coreTransform[#]] &] ||
  !CanonMethodCard`SameSectorQ[task["sector"], cut["sector"], coreCandidates["sector"], coreTransform["sector"]] ||
  ordered["family_id"] =!= cut["family_id"] ||
  ordered["variables"] =!= cut["variables"] || ordered["regulator"] =!= cut["regulator"],
  fail["The original DE, cut, candidate pool and core check must bind the same inputs."]];
selected = Select[coreCandidates["candidates"], #["candidate_id"] === coreTransform["candidate_id"] &];
If[Length[selected] =!= 1 || !TrueQ[Lookup[Lookup[coreTransform, "checks", <||>], "pass", False]],
  fail["Supply the unique candidate selected by a passing core check."]];
If[accepted =!= Null && (!AssociationQ[accepted] ||
  !AllTrue[{"family_id", "variables", "regulator"}, accepted[#] === cut[#] &]),
  fail["The accepted prefix belongs to different scientific inputs."]];

currentBasis = cut["basis"];
currentDimension = Length[currentBasis];
If[accepted === Null,
  {lowerSourceBasis, lowerBasis, lowerTransformation, prefixID} = {{}, {}, {}, Null},
  {lowerSourceBasis, lowerBasis, lowerTransformation, prefixID} =
    accepted /@ {"source_basis", "basis", "transformation", "prefix_id"}
];
lowerDimension = Length[lowerBasis];
rawBasis = Join[lowerSourceBasis, currentBasis];
If[!ListQ[ordered["basis"]] || !DuplicateFreeQ[ordered["basis"]] ||
  rawBasis =!= Take[ordered["basis"], UpTo[Length[rawBasis]]] ||
  !ListQ[coreCandidates["source_basis"]] || !DuplicateFreeQ[coreCandidates["source_basis"]] ||
  !SubsetQ[ordered["basis"], coreCandidates["source_basis"]] ||
  !TrueQ[ListQ[ordered["matrices"]] && Length[ordered["matrices"]] === Length[cut["variables"]] &&
    AllTrue[ordered["matrices"], MatrixQ[#] && Dimensions[#] ===
      {Length[ordered["basis"]], Length[ordered["basis"]]} &]],
  fail["The source basis must extend the resident prefix without reordering or duplication."]];
positions = (First @ FirstPosition[ordered["basis"], #]) & /@ rawBasis;
omitted = Complement[Range[Length[ordered["basis"]]], positions];
If[omitted =!= {} && !AllTrue[ordered["matrices"],
    CanonMethodCard`ZeroMatrixQ[#[[positions, omitted]]] &],
  fail["The requested prefix still couples to omitted source masters."]];
rawMatrices = (#[[positions, positions]] &) /@ ordered["matrices"];
T0 = If[lowerDimension === 0, IdentityMatrix[currentDimension], ArrayFlatten[{
  {lowerTransformation, ConstantArray[0, {lowerDimension, currentDimension}]},
  {ConstantArray[0, {currentDimension, lowerDimension}], IdentityMatrix[currentDimension]}
}]];
rawUpperBlocks = If[accepted === Null, {},
  (#[[Range[lowerDimension], lowerDimension + Range[currentDimension]]] &) /@ rawMatrices];
zeroUpper = accepted =!= Null && Length[rawUpperBlocks] === Length[cut["variables"]] &&
  AllTrue[rawUpperBlocks, Dimensions[#] === {lowerDimension, currentDimension} &&
    AllTrue[Flatten[Normal[#]], # === 0 &] &];
(* Validate and project once before selecting the block assembly route. *)
sourceProjection = Table[Boole[source === target],
  {source, coreCandidates["source_basis"]}, {target, rawBasis}];
prepareRows[candidate_] := Module[{rows, currentRows, outside, proposedT},
  If[StringQ[candidate["construction_rejection"]], Return[None]];
  rows = candidate["full_new_basis_rows"];
  If[!TrueQ[MatrixQ[rows] && Dimensions[rows] ===
      {currentDimension, Length[coreCandidates["source_basis"]]} &&
      AllTrue[Flatten[rows], CanonMethodCard`ExactAlgebraicExpressionQ]],
    fail["Candidate rows do not have the declared exact source-basis shape."]];
  outside = Flatten @ Position[MemberQ[rawBasis, #] & /@ coreCandidates["source_basis"], False];
  If[outside =!= {} && !CanonMethodCard`ZeroMatrixQ[rows[[All, outside]]],
    fail["A candidate has nonzero coefficients on masters outside the current prefix."]];
  rows = rows.sourceProjection;
  currentRows = rows[[All, lowerDimension + Range[currentDimension]]];
  proposedT = candidate["transformation"];
  If[!TrueQ[MatrixQ[proposedT] && Dimensions[proposedT] === {currentDimension, currentDimension} &&
      AllTrue[Flatten[proposedT], CanonMethodCard`ExactAlgebraicExpressionQ] &&
      CanonMethodCard`ZeroMatrixQ[currentRows.proposedT - IdentityMatrix[currentDimension]]] ||
    (candidate["candidate_id"] === coreTransform["candidate_id"] &&
      !TrueQ[MatrixQ[coreTransform["transformation"]] &&
        Dimensions[coreTransform["transformation"]] === {currentDimension, currentDimension} &&
        CanonMethodCard`ZeroMatrixQ[proposedT - coreTransform["transformation"]]]),
    invalid["INVALID_CORE_COMPLETION", "Full integral rows disagree with the independently checked core."]];
  rows
];
(* General tail solving consumes the passing core only. The independent pool
   screen can explicitly request all completions. *)
poolSelection = Lookup[task["payload"], "complete_candidate_pool", False];
If[!MemberQ[{True, False}, poolSelection], fail["complete_candidate_pool must be a Boolean."]];
selected = If[poolSelection, coreCandidates["candidates"], selected];

preparedRows = prepareRows /@ selected;
zeroLowerRowsQ[rows_] := rows =!= None && lowerDimension > 0 &&
  Dimensions[rows] === {currentDimension, Length[rawBasis]} &&
  AllTrue[Flatten[rows[[All, Range[lowerDimension]]]], # === 0 &];
zeroLowerAssembly = zeroUpper && AllTrue[preparedRows,
  # === None || zeroLowerRowsQ[#] &];

(* Optional exact arithmetic has a deliberately narrow initial scope. *)
blockOptions=Lookup[task["payload"],"method_options",<||>];
If[!AssociationQ[blockOptions],fail["method_options must be an Association."]];
blockBackend=Lookup[blockOptions,"block_backend","wolfram"];
backendError[failure_] := (CanonMethodCard`WriteResult[task,outputDir,"ERROR",First[failure],
  <||>,<|"reason"->failure[[2,"Message"]],"scientific_acceptance"->False|>];Quit[1]);
If[!MemberQ[{"wolfram","fermat"},blockBackend],backendError[Failure[
  "UNSUPPORTED_BLOCK_BACKEND",<|"Message"->"Select wolfram or fermat explicitly."|>]]];
blockRuntime=Null;blockFrame=Null;fermatTailBlocks={};fermatCurrentBlocks={};fermatSourceBlocks={};
checked[value_] := If[FailureQ[value],backendError[value],value];
blockTracePath=FileNameJoin[{outputDir,"block-arithmetic-trace.jsonl"}];
blockStarted=AbsoluteTime[];
SetAttributes[blockPhase,HoldRest];
blockPhase[phase_String,variable_,expression_] := Module[{t,result,stream,emit},
  emit[event_,duration_:Null] := (stream=OpenAppend[blockTracePath];
    WriteString[stream,ExportString[Join[<|"event"->event,"phase"->phase,
      "variable"->ToString[variable,InputForm],"elapsed_seconds"->N[AbsoluteTime[]-blockStarted]|>,
      If[duration===Null,<||>,<|"operation_seconds"->N[duration]|>]],"RawJSON","Compact"->True],"\n"];Close[stream]);
  emit["start"];t=AbsoluteTime[];result=expression;emit["end",AbsoluteTime[]-t];result
];
If[blockBackend==="fermat",
  If[!TrueQ[zeroLowerAssembly]||Length[preparedRows]=!=1||First[preparedRows]===None,
    backendError[Failure["UNSUPPORTED_FERMAT_BLOCK_SCOPE",<|"Message"->
      "The Fermatica backend requires one strict zero-upper/zero-lower-row completion with a lower prefix."|>]]];
  Get[FileNameJoin[{repoRoot,"mma","lib","FermatBlockArithmetic.wl"}]];
  blockRuntime=checked[CanonBlockArithmetic`InitializeFermatBlock[task,inputPath,outputDir]];
  blockQ=First[preparedRows][[All,lowerDimension+Range[currentDimension]]];
  blockInverse=Map[Together,Inverse[blockQ],{2}];
  blockFrame=checked[CanonBlockArithmetic`FermatBlockFrame[{lowerTransformation,blockQ,blockInverse,
    D[blockQ,#]&/@cut["variables"]}]];
  With[{lower=Range[lowerDimension],current=lowerDimension+Range[currentDimension]},
    fermatTailBlocks=MapThread[blockPhase["tail_product",#2,
      checked[CanonBlockArithmetic`FermatBlockDot[blockFrame,
        {blockQ,#1[[current,lower]],lowerTransformation}]]]&,{rawMatrices,cut["variables"]}];
    fermatSourceBlocks=MapThread[blockPhase["source_recovery",#2,
      checked[CanonBlockArithmetic`FermatBlockDot[blockFrame,{blockInverse,#1}]]]&,
      {fermatTailBlocks,cut["variables"]}];
    fermatCurrentBlocks=MapThread[blockPhase["current_block",#2,
      checked[CanonBlockArithmetic`FermatBlockDot[blockFrame,{
        checked[CanonBlockArithmetic`FermatBlockPlus[blockFrame,{D[blockQ,#2],
          checked[CanonBlockArithmetic`FermatBlockDot[blockFrame,{blockQ,#1[[current,current]]}]]}]],
        blockInverse}]]]&,{rawMatrices,cut["variables"]}]
  ];
];

(* Source matrices remain exact. Normalize after current-row mixing only for
   the strict zero-upper/zero-lower-row route. *)
sourceMatrices = If[blockBackend === "fermat",
  MapThread[ArrayFlatten[{{#2,ConstantArray[0,{lowerDimension,currentDimension}]},
    {#3,#1[[lowerDimension+Range[currentDimension],lowerDimension+Range[currentDimension]]]}}]&,
    {rawMatrices,accepted["matrices"],fermatSourceBlocks}],
  If[accepted === Null, rawMatrices,
  With[{lower = Range[lowerDimension], current = lowerDimension + Range[currentDimension],
      inverseLower = If[zeroUpper, None, Inverse[lowerTransformation]]},
    MapThread[ArrayFlatten[{
      {#2, If[zeroUpper, ConstantArray[0, {lowerDimension, currentDimension}],
        inverseLower.#1[[lower, current]]]},
      {If[zeroLowerAssembly, #1[[current, lower]].lowerTransformation,
        CanonFFT`NormalizeMatrix["source_current_lower_reduce", #1[[current, lower]].lowerTransformation]], #1[[current, current]]}
    }] &, {rawMatrices, accepted["matrices"]}]
  ]]
];

zeroLowerTail[rawTail_, currentRows_] :=
  Map[Together, Map[Together, currentRows.rawTail, {2}].lowerTransformation, {2}];

completion[candidate_, rows_] := Module[{currentRows, fullRows, transformation, inverse, lowerRows, fast},
  If[StringQ[candidate["construction_rejection"]], Return[<|
    "candidate_id" -> candidate["candidate_id"],
    "member_candidate_ids" -> candidate["member_candidate_ids"],
    "full_transformation" -> None, "transformed_matrices" -> {}|>]];
  currentRows = rows[[All, lowerDimension + Range[currentDimension]]];
  fast = zeroUpper && zeroLowerRowsQ[rows];
  inverse = candidate["transformation"];
  lowerRows = If[lowerDimension === 0, {},
    If[fast, ConstantArray[0, {currentDimension, lowerDimension}],
      rows[[All, Range[lowerDimension]]].lowerTransformation]];
  fullRows = If[lowerDimension === 0, currentRows, ArrayFlatten[{
    {IdentityMatrix[lowerDimension], ConstantArray[0, {lowerDimension, currentDimension}]},
    {lowerRows, currentRows}
  }]];
  transformation = If[lowerDimension === 0, inverse, ArrayFlatten[{
    {IdentityMatrix[lowerDimension], ConstantArray[0, {lowerDimension, currentDimension}]},
    {CanonFFT`NormalizeMatrix["candidate_lower_transform_reduce", -inverse.lowerRows], inverse}}]];
  <|"candidate_id" -> candidate["candidate_id"],
    "member_candidate_ids" -> candidate["member_candidate_ids"],
    "new_basis_rows" -> fullRows, "full_transformation" -> transformation,
    "transformed_matrices" -> If[blockBackend === "fermat",
      MapThread[ArrayFlatten[{{#1,ConstantArray[0,{lowerDimension,currentDimension}]},{#2,#3}}]& ,
        {accepted["matrices"],fermatTailBlocks,fermatCurrentBlocks}],
      If[fast,
      With[{lower = Range[lowerDimension], current = lowerDimension + Range[currentDimension]},
        MapThread[ArrayFlatten[{
          {#2, ConstantArray[0, {lowerDimension, currentDimension}]},
          {zeroLowerTail[#1[[current, lower]], currentRows],
            Map[Together, (D[currentRows, #3] + currentRows.#1[[current, current]]).inverse, {2}]}
        }] &, {rawMatrices, accepted["matrices"], cut["variables"]}]],
      MapThread[CanonFFT`NormalizeMatrix["candidate_full_gauge_reduce", fullRows.(#1.transformation - D[transformation, #2])] &,
        {sourceMatrices, cut["variables"]}]]]|>
];


fullDE = <|"schema" -> "canon-neu/full-prefix-candidates/v1",
  "sector" -> cut["sector"], "family_id" -> cut["family_id"],
  "current_basis_id" -> cut["basis_id"], "accepted_prefix_id" -> prefixID,
  "coefficient_domain" -> "exact-algebraic-functions",
  "raw_source_basis" -> rawBasis, "source_basis" -> Join[lowerBasis, currentBasis],
  "source_positions" -> positions, "accepted_prefix_transformation" -> T0,
  "lower_basis" -> lowerBasis, "current_basis" -> currentBasis,
  "block_boundaries" -> <|"lower_dimension" -> lowerDimension,
    "current_dimension" -> currentDimension|>,
  "variables" -> cut["variables"], "regulator" -> cut["regulator"],
  "alphabet" -> alphabet,
  "convention" -> "old_prefix_basis = full_transformation . candidate_prefix_basis",
  "source_matrices" -> sourceMatrices,
  "first_core_candidate_id" -> coreTransform["candidate_id"],
  "block_arithmetic" -> If[blockRuntime===Null,<|"backend"->"wolfram"|>,
    Join[blockRuntime,<|"quadratic_bases"->blockFrame["bases"]|>]],
  "candidates" -> MapThread[completion, {selected, preparedRows}]|>;
path = CanonMethodCard`WriteWLArtifact[fullDE, outputDir, "full-sector-de.wl"];
CanonMethodCard`WriteResult[task, outputDir, "PASS", "OK",
  Join[<|"full_sector_de" -> <|"type" -> "mathematica-expression",
    "path" -> FileNameTake[path]|>|>,If[blockBackend==="fermat",
      <|"block_arithmetic_trace"-><|"type"->"jsonl","path"->FileNameTake[blockTracePath]|>|>,<||>]],
  <|"source_positions" -> positions, "lower_dimension" -> lowerDimension,
    "current_dimension" -> currentDimension,
    "candidate_ids" -> Lookup[fullDE["candidates"], "candidate_id"],
    "full_de_rebuilt" -> False, "zero_lower_block_assembly" -> zeroLowerAssembly,
    "block_backend" -> blockBackend|>];
