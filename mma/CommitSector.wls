#!/usr/bin/env wolframscript

$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "COMMIT_SECTOR"];
sectorBasis = CanonMethodCard`LoadArtifact[task, inputPath, "sector_basis"];
sectorTransform = CanonMethodCard`LoadArtifact[task, inputPath, "sector_transform"];
canonical = CanonMethodCard`LoadArtifact[task, inputPath, "canonical_sector_de"];
previous = If[task["payload", "previous_accepted_prefix"] === Null, Null,
  CanonMethodCard`LoadArtifact[task, inputPath, "previous_accepted_prefix"]];

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
T0 = If[previous === Null, IdentityMatrix[currentDimension], ArrayFlatten[{
  {lowerTransformation, ConstantArray[0, {lowerDimension, currentDimension}]},
  {ConstantArray[0, {currentDimension, lowerDimension}],
    IdentityMatrix[currentDimension]}}]];
Tfull = sectorTransform["transformation"];
mixedBasis = Join[acceptedLower, currentBasis];
newBasis = Inverse[Tfull].mixedBasis;
composed = Map[Together, T0.Tfull, {2}];
acceptedBasis = newBasis;
transformation = composed;
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
    "candidate_id" -> sectorTransform["candidate_id"]|>];
