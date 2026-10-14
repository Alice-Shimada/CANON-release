#!/usr/bin/env wolframscript

$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "PrefixComposition.wl"}]];
{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "COMMIT_SECTOR"];
sectorBasis = CanonMethodCard`LoadArtifact[task, inputPath, "sector_basis"];
sectorTransform = CanonMethodCard`LoadArtifact[task, inputPath, "sector_transform"];
canonical = CanonMethodCard`LoadArtifact[task, inputPath, "canonical_sector_de"];
previous = If[task["payload", "previous_accepted_prefix"] === Null, Null,
  CanonMethodCard`LoadArtifact[task, inputPath, "previous_accepted_prefix"]];

fail[reason_] := (CanonMethodCard`WriteResult[task, outputDir, "ERROR",
  "INVALID_COMMIT_INPUT", <||>, <|"reason" -> reason|>]; Quit[1]);
If[!TrueQ[CanonMethodCard`ValidSectorBasisQ[sectorBasis]] ||
  !AssociationQ[canonical] || !AssociationQ[sectorTransform] ||
  Lookup[canonical, "schema", None] =!= "canon-neu/canonical-sector-de/v1" ||
  !AllTrue[{"family_id", "current_basis_id", "accepted_prefix_id", "source_basis",
      "variables", "regulator", "convention", "candidate_id", "member_candidate_ids", "transformation"},
    KeyExistsQ[canonical, #] && KeyExistsQ[sectorTransform, #] && canonical[#] === sectorTransform[#] &] ||
  !AllTrue[{"exact_gauge", "flat_connection", "epsilon_factorized", "declared_dlog_alphabet", "upper_right_zero"},
    TrueQ[Lookup[Lookup[canonical, "full_checks", <||>], #, False]] &] ||
  !CanonMethodCard`SameSectorQ[task["sector"], sectorBasis["sector"], canonical["sector"], sectorTransform["sector"]] ||
  sectorBasis["family_id"] =!= canonical["family_id"] ||
  sectorBasis["basis_id"] =!= canonical["current_basis_id"],
  fail["Commit requires the matching transformation and a complete passing canonical check."]];
If[previous =!= Null && (!AssociationQ[previous] ||
    !AllTrue[{"family_id", "variables", "regulator"}, previous[#] === canonical[#] &]),
  fail["The previous prefix belongs to different scientific inputs."]];

currentBasis = sectorBasis["basis"];
currentDimension = Length[currentBasis];
If[previous === Null,
  {rawLower, acceptedLower, lowerTransformation, parentID,
    sectorTrace, candidateTrace} = {{}, {}, {}, Null, {}, {}},
  {rawLower, acceptedLower, lowerTransformation, parentID,
    sectorTrace, candidateTrace} = previous /@
      {"source_basis", "basis", "transformation", "prefix_id",
        "sector_trace", "candidate_trace"}
];
lowerDimension = Length[acceptedLower];
If[!TrueQ[MatrixQ[sectorTransform["transformation"]] &&
    Dimensions[sectorTransform["transformation"]] ===
      {lowerDimension + currentDimension, lowerDimension + currentDimension} &&
    CanonMethodCard`ValidMatrixSystemQ[canonical["matrices"], canonical["variables"],
      canonical["regulator"], lowerDimension + currentDimension]],
  fail["The checked transformation and matrices have inconsistent dimensions."]];
If[canonical["accepted_prefix_id"] =!= parentID ||
  canonical["source_basis"] =!= Join[acceptedLower, currentBasis] ||
  KeySort[canonical["block_boundaries"]] =!= KeySort[<|"lower_dimension" -> lowerDimension,
    "current_dimension" -> currentDimension|>] ||
  AnyTrue[sectorTrace, CanonMethodCard`SameSectorQ[#, canonical["sector"]] &],
  fail["The checked mixed basis does not extend this previous prefix exactly once."]];
Tfull = sectorTransform["transformation"];
composition = CanonPrefixComposition`ComposePrefix[rawLower, acceptedLower,
  lowerTransformation, currentBasis, Tfull];
If[FailureQ[composition], fail[ToString[composition, InputForm]]];
acceptedBasis = composition["basis"];
transformation = composition["transformation"];
matrices = canonical["matrices"];
alphabet = canonical["alphabet"];
sectorTrace = Append[sectorTrace, canonical["sector"]];
candidateTrace = Append[candidateTrace, <|
  "sector" -> canonical["sector"],
  "current_basis_id" -> canonical["current_basis_id"],
  "candidate_id" -> sectorTransform["candidate_id"],
  "member_candidate_ids" -> sectorTransform["member_candidate_ids"],
  "method" -> sectorTransform["method"]|>];

prefix = <|
  "schema" -> "canon-neu/accepted-prefix/v1",
  "parent_prefix_id" -> parentID,
  "family_id" -> canonical["family_id"],
  "coefficient_domain" -> "exact-algebraic-functions",
  "source_basis" -> Join[rawLower, currentBasis],
  "basis" -> acceptedBasis,
  "convention" -> "old_source_basis = transformation . accepted_basis",
  "transformation" -> transformation,
  "variables" -> canonical["variables"],
  "regulator" -> canonical["regulator"],
  "alphabet" -> alphabet,
  "matrices" -> matrices,
  "sector_trace" -> sectorTrace,
  "candidate_trace" -> candidateTrace|>;
prefix = Join[<|"prefix_id" ->
    "sha256:" <> Hash[prefix, "SHA256", "HexString"]|>, prefix];
path = CanonMethodCard`WriteWLArtifact[prefix, outputDir, "accepted-prefix.wl"];
CanonMethodCard`WriteResult[task, outputDir, "PASS", "OK",
  <|"accepted_prefix" -> <|
    "type" -> "mathematica-expression", "path" -> FileNameTake[path]|>|>,
  <|"prefix_id" -> prefix["prefix_id"],
    "accepted_sector_count" -> Length[sectorTrace],
    "accepted_master_count" -> Length[acceptedBasis],
    "previous_master_count" -> lowerDimension,
    "new_master_count" -> currentDimension,
    "candidate_id" -> sectorTransform["candidate_id"]|>];
