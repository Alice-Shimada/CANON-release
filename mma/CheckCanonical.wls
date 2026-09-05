#!/usr/bin/env wolframscript

$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "CHECK_CANONICAL"];
fullDE = CanonMethodCard`LoadArtifact[task, inputPath, "full_sector_de"];
sectorTransform = CanonMethodCard`LoadArtifact[task, inputPath, "sector_transform"];

sameMatrices[left_, right_] := And @@ MapThread[
  CanonMethodCard`ZeroMatrixQ[Map[Together, #1 - #2, {2}]] &, {left, right}];
blocks[matrices_, rows_, columns_] := (#[[rows, columns]] &) /@ matrices;

variables = fullDE["variables"];
regulator = fullDE["regulator"];
alphabet = sectorTransform["alphabet"];
transformation = sectorTransform["transformation"];
declared = sectorTransform["transformed_matrices"];
computed = CanonMethodCard`GaugeTransform[
  fullDE["source_matrices"], variables, transformation];
{lowerDimension, currentDimension} =
  fullDE["block_boundaries"] /@ {"lower_dimension", "current_dimension"};
currentRows = lowerDimension + Range[currentDimension];
currentComputed = blocks[computed, currentRows, currentRows];
currentDeclared = blocks[declared, currentRows, currentRows];

coreChecks = <|
  "exact_gauge" -> sameMatrices[currentComputed, currentDeclared],
  "flat_connection" -> CanonMethodCard`FlatConnectionQ[currentComputed, variables],
  "epsilon_factorized" -> CanonMethodCard`EpsilonFactorizedQ[currentComputed, regulator],
  "declared_dlog_alphabet" -> CanonMethodCard`DLogConnectionQ[
    currentComputed, variables, regulator, alphabet]|>;
lowerRows = Range[lowerDimension];
upperRightZero = lowerDimension === 0 || And @@ (
  CanonMethodCard`ZeroMatrixQ /@ blocks[computed, lowerRows, currentRows]);
fullChecks = <|
  "exact_gauge" -> sameMatrices[computed, declared],
  "flat_connection" -> CanonMethodCard`FlatConnectionQ[computed, variables],
  "epsilon_factorized" -> CanonMethodCard`EpsilonFactorizedQ[computed, regulator],
  "declared_dlog_alphabet" -> CanonMethodCard`DLogConnectionQ[
    computed, variables, regulator, alphabet],
  "upper_right_zero" -> upperRightZero|>;

If[!And @@ Values[fullChecks],
  CanonMethodCard`WriteResult[task, outputDir, "FAIL",
    If[And @@ Values[coreChecks], "TAIL_FAIL", "CORE_FAIL"], <||>,
    <|"candidate_id" -> sectorTransform["candidate_id"],
      "core_checks" -> coreChecks, "full_checks" -> fullChecks|>];
  Quit[0]
];
canonical = <|
  "schema" -> "canon-neu/canonical-sector-de/v1",
  "sector" -> fullDE["sector"], "family_id" -> fullDE["family_id"],
  "current_basis_id" -> fullDE["current_basis_id"],
  "accepted_prefix_id" -> fullDE["accepted_prefix_id"],
  "coefficient_domain" -> "exact-algebraic-functions",
  "source_basis" -> fullDE["source_basis"],
  "variables" -> variables, "regulator" -> regulator, "alphabet" -> alphabet,
  "convention" -> fullDE["convention"],
  "candidate_id" -> sectorTransform["candidate_id"],
  "member_candidate_ids" -> sectorTransform["member_candidate_ids"],
  "transformation" -> transformation, "matrices" -> computed,
  "block_boundaries" -> fullDE["block_boundaries"],
  "core_checks" -> coreChecks, "full_checks" -> fullChecks|>;
path = CanonMethodCard`WriteWLArtifact[
  canonical, outputDir, "canonical-sector-de.wl"];
CanonMethodCard`WriteResult[task, outputDir, "PASS", "CANONICAL_PASS",
  <|"canonical_sector_de" -> <|
    "type" -> "mathematica-expression", "path" -> FileNameTake[path]|>|>,
  <|"candidate_id" -> canonical["candidate_id"],
    "core_checks" -> coreChecks, "full_checks" -> fullChecks|>];
