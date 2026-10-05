#!/usr/bin/env wolframscript

$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "BUILD_FULL_DE"];
ordered = CanonMethodCard`LoadArtifact[task, inputPath, "ordered_master_de"];
cut = CanonMethodCard`LoadArtifact[task, inputPath, "sector_cut_de"];
coreCandidates = CanonMethodCard`LoadArtifact[task, inputPath, "core_candidates"];
coreTransform = CanonMethodCard`LoadArtifact[task, inputPath, "core_transform"];
invalid[code_String, reason_String, details_:<||>] := (
  CanonMethodCard`WriteResult[task, outputDir, "ERROR", code, <||>,
    Join[<|"reason" -> reason, "preferred_next_route" -> "FIX_INPUT"|>, details]];
  Quit[1]);
If[!AssociationQ[coreTransform] || !AssociationQ[coreCandidates] ||
    !AssociationQ[cut] ||
    Lookup[coreTransform, "schema", None] =!= "canon-neu/core-transform/v1" ||
    !And @@ (Lookup[coreTransform, #, Missing["core"]] ===
      Lookup[cut, #, Missing["cut"]] & /@
      {"sector", "family_id", "basis_id", "basis", "variables", "regulator"}) ||
    !And @@ (Lookup[coreCandidates, #, Missing["candidates"]] ===
      Lookup[cut, #, Missing["cut"]] & /@
      {"sector", "family_id", "basis_id", "basis", "variables", "regulator"}) ||
    !ListQ[Lookup[coreCandidates, "candidates", None]],
  invalid["INVALID_INPUT", "The checked core and candidate pool must bind the same cut"]];
selectedID = Lookup[coreTransform, "candidate_id", None];
If[!StringQ[selectedID] || Count[Lookup[coreCandidates["candidates"], "candidate_id", None],
    selectedID] =!= 1,
  invalid["INVALID_INPUT", "The checked core must identify one candidate in the supplied pool"]];
alphabet = If[task["payload", "declared_alphabet"] === Null, {},
  CanonMethodCard`LoadArtifact[task, inputPath, "declared_alphabet"]["letters"]];
accepted = If[task["payload", "accepted_prefix"] === Null, Null,
  CanonMethodCard`LoadArtifact[task, inputPath, "accepted_prefix"]];

currentBasis = cut["basis"];
currentDimension = Length[currentBasis];
If[accepted === Null,
  {lowerSourceBasis, lowerBasis, lowerTransformation, prefixID} = {{}, {}, {}, Null},
  {lowerSourceBasis, lowerBasis, lowerTransformation, prefixID} =
    accepted /@ {"source_basis", "basis", "transformation", "prefix_id"}
];
lowerDimension = Length[lowerBasis];
rawBasis = Join[lowerSourceBasis, currentBasis];
positions = (First @ FirstPosition[ordered["basis"], #]) & /@ rawBasis;
rawMatrices = (#[[positions, positions]] &) /@ ordered["matrices"];
T0 = If[lowerDimension === 0, IdentityMatrix[currentDimension], ArrayFlatten[{
  {lowerTransformation, ConstantArray[0, {lowerDimension, currentDimension}]},
  {ConstantArray[0, {currentDimension, lowerDimension}], IdentityMatrix[currentDimension]}
}]];
sourceMatrices = If[accepted === Null, rawMatrices,
  With[{lower = Range[lowerDimension], current = lowerDimension + Range[currentDimension],
      inverseLower = Inverse[lowerTransformation]},
    MapThread[ArrayFlatten[{
      {#2, inverseLower.#1[[lower, current]]},
      {Map[Together, #1[[current, lower]].lowerTransformation, {2}], #1[[current, current]]}
    }] &, {rawMatrices, accepted["matrices"]}]
  ]
];
sourceProjection = Table[Boole[source === target],
  {source, coreCandidates["source_basis"]}, {target, rawBasis}];

rejectedCompletion[candidate_, reason_] := <|
  "candidate_id" -> candidate["candidate_id"],
  "member_candidate_ids" -> Lookup[candidate, "member_candidate_ids", {}],
  "completion_rejection" -> "INVALID_CORE_COMPLETION", "reason" -> reason,
  "full_transformation" -> None, "transformed_matrices" -> {}|>;
completion[candidate_] := Module[{rows, currentRows, fullRows, transformation, proposedRows, proposedT},
  If[StringQ[candidate["construction_rejection"]], Return[<|
    "candidate_id" -> candidate["candidate_id"],
    "member_candidate_ids" -> candidate["member_candidate_ids"],
    "full_transformation" -> None, "transformed_matrices" -> {}|>]];
  proposedRows = Lookup[candidate, "full_new_basis_rows", None];
  proposedT = Lookup[candidate, "transformation", None];
  If[!MatrixQ[proposedRows] ||
      Dimensions[proposedRows] =!= {currentDimension, Length[coreCandidates["source_basis"]]} ||
      !MatrixQ[proposedT] || Dimensions[proposedT] =!= {currentDimension, currentDimension} ||
      !And @@ (CanonMethodCard`ExactAlgebraicExpressionQ /@ Flatten[{proposedRows, proposedT}]),
    Return[rejectedCompletion[candidate, "Invalid full row or core transformation shape/domain"]]];
  rows = proposedRows.sourceProjection;
  currentRows = rows[[All, lowerDimension + Range[currentDimension]]];
  If[!CanonMethodCard`ZeroMatrixQ[currentRows.proposedT - IdentityMatrix[currentDimension]] ||
      !CanonMethodCard`ZeroMatrixQ[proposedT.currentRows - IdentityMatrix[currentDimension]],
    Return[rejectedCompletion[candidate, "Full current-sector rows must be the exact inverse of the core transformation"]]];
  If[candidate["candidate_id"] === selectedID &&
      (!MatrixQ[Lookup[coreTransform, "transformation", None]] ||
       Dimensions[coreTransform["transformation"]] =!= {currentDimension, currentDimension} ||
       !CanonMethodCard`ZeroMatrixQ[proposedT - coreTransform["transformation"]]),
    Return[rejectedCompletion[candidate, "Selected proposal differs from the independently checked core"]]];
  fullRows = If[lowerDimension === 0, currentRows, ArrayFlatten[{
    {IdentityMatrix[lowerDimension], ConstantArray[0, {lowerDimension, currentDimension}]},
    {rows[[All, Range[lowerDimension]]].lowerTransformation, currentRows}
  }]];
  transformation = Map[Together, Inverse[fullRows], {2}];
  <|"candidate_id" -> candidate["candidate_id"],
    "member_candidate_ids" -> candidate["member_candidate_ids"],
    "new_basis_rows" -> fullRows, "full_transformation" -> transformation,
    "transformed_matrices" -> CanonMethodCard`GaugeTransform[
      sourceMatrices, cut["variables"], transformation]|>
];

completions = completion /@ coreCandidates["candidates"];
selectedCompletion = SelectFirst[completions, #["candidate_id"] === selectedID &];
If[Lookup[selectedCompletion, "full_transformation", None] === None,
  invalid["INVALID_CORE_COMPLETION", "The selected checked core has inconsistent full rows",
    <|"candidate_id" -> selectedID, "completion" ->
      KeyTake[selectedCompletion, {"completion_rejection", "reason"}]|>]];
rejectedIDs = Lookup[Select[completions, KeyExistsQ[#, "completion_rejection"] &], "candidate_id", {}];
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
  "candidates" -> completions|>;
path = CanonMethodCard`WriteWLArtifact[fullDE, outputDir, "full-sector-de.wl"];
CanonMethodCard`WriteResult[task, outputDir, "PASS", "OK",
  <|"full_sector_de" -> <|"type" -> "mathematica-expression",
    "path" -> FileNameTake[path]|>|>,
  <|"source_positions" -> positions, "lower_dimension" -> lowerDimension,
    "current_dimension" -> currentDimension,
    "candidate_ids" -> Lookup[fullDE["candidates"], "candidate_id"],
    "rejected_completion_ids" -> rejectedIDs,
    "full_de_rebuilt" -> False|>];
