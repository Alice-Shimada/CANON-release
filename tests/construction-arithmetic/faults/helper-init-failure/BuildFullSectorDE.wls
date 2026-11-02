#!/usr/bin/env wolframscript

$HistoryLength = 0;
scriptArgs = If[ListQ[$ScriptCommandLine] && Length[$ScriptCommandLine] > 1,
  Rest[$ScriptCommandLine], Drop[$CommandLine, First @ FirstPosition[$CommandLine, "-script"] + 1]];
repoRoot = ExpandFileName[First[scriptArgs]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
{inputPath, outputDir} = ExpandFileName /@ Take[CanonMethodCard`ScriptArguments[], -2];
task = CanonMethodCard`ReadTask[inputPath, "BUILD_FULL_DE"];
If[Quiet @ Check[Get[FileNameJoin[{DirectoryName[ExpandFileName[$InputFileName]], "ConstructionArithmetic.wl"}]]; True, False] =!= True,
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
sourceMatrices = If[accepted === Null, rawMatrices,
  With[{lower = Range[lowerDimension], current = lowerDimension + Range[currentDimension],
      inverseLower = Inverse[lowerTransformation]},
    MapThread[ArrayFlatten[{
      {#2, inverseLower.#1[[lower, current]]},
      {CanonFFT`NormalizeMatrix["source_current_lower_reduce", #1[[current, lower]].lowerTransformation], #1[[current, current]]}
    }] &, {rawMatrices, accepted["matrices"]}]
  ]
];
sourceProjection = Table[Boole[source === target],
  {source, coreCandidates["source_basis"]}, {target, rawBasis}];

completion[candidate_] := Module[{rows, currentRows, fullRows, transformation, inverse, lowerRows, outside},
  If[StringQ[candidate["construction_rejection"]], Return[<|
    "candidate_id" -> candidate["candidate_id"],
    "member_candidate_ids" -> candidate["member_candidate_ids"],
    "full_transformation" -> None, "transformed_matrices" -> {}|>]];
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
  If[candidate["candidate_id"] === coreTransform["candidate_id"] &&
    !TrueQ[MatrixQ[coreTransform["transformation"]] &&
      Dimensions[coreTransform["transformation"]] === {currentDimension, currentDimension} &&
      CanonMethodCard`ZeroMatrixQ[currentRows.coreTransform["transformation"] - IdentityMatrix[currentDimension]]],
    fail["Full integral rows disagree with the independently checked cut transformation."]];
  inverse = CanonFFT`NormalizeMatrix["current_core_inverse_reduce", Inverse[currentRows]];
  lowerRows = If[lowerDimension === 0, {}, rows[[All, Range[lowerDimension]]].lowerTransformation];
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
    "transformed_matrices" -> MapThread[
      CanonFFT`NormalizeMatrix["candidate_full_gauge_reduce", fullRows.(#1.transformation - D[transformation, #2])] &,
      {sourceMatrices, cut["variables"]}]|>
];

(* General tail solving consumes the passing core only. The independent pool
   screen can explicitly request all completions. *)
poolSelection = Lookup[task["payload"], "complete_candidate_pool", False];
If[!MemberQ[{True, False}, poolSelection], fail["complete_candidate_pool must be a Boolean."]];
selected = If[poolSelection, coreCandidates["candidates"], selected];

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
  "candidates" -> (completion /@ selected)|>;
path = CanonMethodCard`WriteWLArtifact[fullDE, outputDir, "full-sector-de.wl"];
CanonMethodCard`WriteResult[task, outputDir, "PASS", "OK",
  <|"full_sector_de" -> <|"type" -> "mathematica-expression",
    "path" -> FileNameTake[path]|>|>,
  <|"source_positions" -> positions, "lower_dimension" -> lowerDimension,
    "current_dimension" -> currentDimension,
    "candidate_ids" -> Lookup[fullDE["candidates"], "candidate_id"],
    "full_de_rebuilt" -> False|>];
