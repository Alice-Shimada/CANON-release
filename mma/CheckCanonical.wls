#!/usr/bin/env wolframscript

$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "CHECK_CANONICAL"];
fullDE = CanonMethodCard`LoadArtifact[task, inputPath, "full_sector_de"];
sectorTransform = CanonMethodCard`LoadArtifact[task, inputPath, "sector_transform"];

fail[reason_] := (CanonMethodCard`WriteResult[task, outputDir, "ERROR",
  "INVALID_CANONICAL_INPUT", <||>, <|"reason" -> reason|>]; Quit[1]);
If[!AssociationQ[fullDE] || !AssociationQ[sectorTransform] ||
  Lookup[fullDE, "schema", None] =!= "canon-neu/full-prefix-candidates/v1" ||
  Lookup[sectorTransform, "schema", None] =!= "canon-neu/sector-transform/v1" ||
  !AllTrue[{"family_id", "current_basis_id", "accepted_prefix_id",
      "source_basis", "variables", "regulator", "convention"},
    KeyExistsQ[fullDE, #] && KeyExistsQ[sectorTransform, #] && fullDE[#] === sectorTransform[#] &] ||
  !CanonMethodCard`SameSectorQ[task["sector"], fullDE["sector"], sectorTransform["sector"]] ||
  fullDE["convention"] =!= "old_prefix_basis = full_transformation . candidate_prefix_basis",
  fail["The full DE and transformation must bind the same prefix and coordinates."]];

sameMatrices[left_, right_] := And @@ MapThread[
  CanonMethodCard`ZeroMatrixQ[Map[Together, #1 - #2, {2}]] &, {left, right}];
blocks[matrices_, rows_, columns_] := (#[[rows, columns]] &) /@ matrices;

variables = fullDE["variables"];
regulator = fullDE["regulator"];
alphabet = sectorTransform["alphabet"];
transformation = sectorTransform["transformation"];
declared = sectorTransform["transformed_matrices"];
{lowerDimension, currentDimension} =
  fullDE["block_boundaries"] /@ {"lower_dimension", "current_dimension"};
dimension = lowerDimension + currentDimension;
If[!TrueQ[IntegerQ[lowerDimension] && lowerDimension >= 0 &&
    IntegerQ[currentDimension] && currentDimension > 0 &&
    ListQ[fullDE["source_basis"]] && Length[fullDE["source_basis"]] === dimension &&
    CanonMethodCard`ValidMatrixSystemQ[fullDE["source_matrices"], variables, regulator, dimension] &&
    CanonMethodCard`ValidMatrixSystemQ[declared, variables, regulator, dimension] &&
    MatrixQ[transformation] && Dimensions[transformation] === {dimension, dimension} &&
    AllTrue[Flatten[transformation], CanonMethodCard`ExactAlgebraicExpressionQ] &&
    Together[Det[transformation]] =!= 0 && ListQ[alphabet] &&
    AllTrue[alphabet, CanonMethodCard`ExactAlgebraicExpressionQ]],
  fail["Invalid prefix dimensions, matrix coefficients, alphabet or invertible transformation."]];
computed = CanonMethodCard`GaugeTransform[
  fullDE["source_matrices"], variables, transformation];
currentRows = lowerDimension + Range[currentDimension];
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

(* A flat block-triangular dlog system has flat dlog diagonal blocks. Only
   diagnose the current block separately when the full-prefix check fails. *)
coreChecks = If[TrueQ[And @@ Values[fullChecks]], KeyDrop[fullChecks, "upper_right_zero"],
  currentComputed = blocks[computed, currentRows, currentRows];
  currentDeclared = blocks[declared, currentRows, currentRows];
  <|
    "exact_gauge" -> sameMatrices[currentComputed, currentDeclared],
    "flat_connection" -> CanonMethodCard`FlatConnectionQ[currentComputed, variables],
    "epsilon_factorized" -> CanonMethodCard`EpsilonFactorizedQ[currentComputed, regulator],
    "declared_dlog_alphabet" -> CanonMethodCard`DLogConnectionQ[
      currentComputed, variables, regulator, alphabet]|>
];

If[!TrueQ[And @@ Values[fullChecks]],
  CanonMethodCard`WriteResult[task, outputDir, "FAIL",
    If[TrueQ[And @@ Values[coreChecks]], "TAIL_FAIL", "CORE_FAIL"], <||>,
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
