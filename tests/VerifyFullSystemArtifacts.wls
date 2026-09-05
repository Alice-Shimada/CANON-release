#!/usr/bin/env wolframscript

$HistoryLength = 0;
{preparedPath, masterPath, manifestPath, orderedPath, acceptedPath,
  outputA, outputB, receiptPath} = ExpandFileName /@ Rest[$ScriptCommandLine];
prepared = Get[preparedPath];
master = Get[masterPath];
manifest = Get[manifestPath];
ordered = Get[orderedPath];
accepted = Get[acceptedPath];
basisA = Get[FileNameJoin[{outputA, "canonical-basis.wl"}]];
deA = Get[FileNameJoin[{outputA, "canonical-de.wl"}]];
basisB = Get[FileNameJoin[{outputB, "canonical-basis.wl"}]];
deB = Get[FileNameJoin[{outputB, "canonical-de.wl"}]];

zeroQ[expression_] := MatrixQ[expression] &&
  And @@ (TrueQ[Together[#] === 0] & /@ Flatten[expression]);
sameMatrices[left_, right_] := And @@ MapThread[
  zeroQ[Map[Together, #1 - #2, {2}]] &, {left, right}];
sha[path_] := IntegerString[FileHash[path, "SHA256"], 16, 64];

variables = ordered["variables"];
regulator = ordered["regulator"];
transformation = accepted["transformation"];
computed = MapThread[
  Map[Together, Inverse[transformation].
    (#1.transformation - D[transformation, #2]), {2}] &,
  {ordered["matrices"], variables}];
pairs = Subsets[Range[Length[variables]], {2}];
flat = And @@ (Function[pair,
    zeroQ[Map[Together,
      D[computed[[pair[[2]]]], variables[[pair[[1]]]]] -
      D[computed[[pair[[1]]]], variables[[pair[[2]]]]] +
      computed[[pair[[2]]]].computed[[pair[[1]]]] -
      computed[[pair[[1]]]].computed[[pair[[2]]]], {2}]]] /@ pairs);
reconstructed = {regulator Total @ MapThread[
    #1 D[#2, First[variables]]/#2 &,
    {deA["residue_matrices"], deA["alphabet"]}]};
expectedTrace = KeyTake[#, {"id", "propagator_count"}] & /@
  manifest["sectors"];

checks = <|
  "actual_t006_prefix_bytes" ->
    (sha[acceptedPath] ===
      "fc1e2e951d10ca0951827ddd18e2425f863836be06ca68a49fe7bd40d4245ded"),
  "actual_t005_ordered_de_bytes" ->
    (sha[orderedPath] ===
      "9a75821301b6895cb8daac453ea1a951d5329b4e679795192fe3a06dd4e5ae81"),
  "artifact_identity" ->
    SameQ[prepared["family_ref"], master["family_ref"], ordered["family_id"],
      accepted["family_id"], basisA["family_id"], deA["family_id"]],
  "source_basis_resident_order" ->
    (ordered["basis"] === master["masters"] === accepted["source_basis"] ===
      basisA["source_basis"] && DuplicateFreeQ[ordered["basis"]]),
  "sector_trace_resident_order" ->
    (accepted["sector_trace"] === expectedTrace === basisA["sector_trace"]),
  "candidate_trace_coverage" ->
    (Lookup[accepted["candidate_trace"], "sector"] === expectedTrace &&
      basisA["candidate_trace"] === accepted["candidate_trace"]),
  "cursor_complete" ->
    (Drop[expectedTrace, Length[accepted["sector_trace"]]] === {}),
  "accepted_prefix_hash" -> (accepted["prefix_id"] ===
    "sha256:" <> Hash[KeyDrop[accepted, "prefix_id"], "SHA256", "HexString"]),
  "invertible_cumulative_transformation" ->
    TrueQ[Together[Det[transformation]] =!= 0],
  "canonical_basis_composition" ->
    (basisA["basis"] === accepted["basis"] &&
      basisA["transformation"] === transformation &&
      basisA["convention"] === accepted["convention"]),
  "raw_gauge_composition" ->
    (sameMatrices[computed, accepted["matrices"]] &&
      sameMatrices[computed, deA["matrices"]]),
  "flat_connection" -> flat,
  "epsilon_factorized" ->
    And @@ (FreeQ[Together[#/regulator], regulator] & /@ Flatten[computed]),
  "epsilon_free_alphabet" -> FreeQ[deA["alphabet"], regulator],
  "constant_residue_dlog" ->
    (Cases[deA["residue_matrices"], _Symbol, Infinity] === {} &&
      And @@ (!zeroQ[#] & /@ deA["residue_matrices"]) &&
      sameMatrices[computed, reconstructed]),
  "canonical_basis_byte_stable" ->
    (basisA === basisB &&
      FileHash[FileNameJoin[{outputA, "canonical-basis.wl"}], "SHA256"] ===
      FileHash[FileNameJoin[{outputB, "canonical-basis.wl"}], "SHA256"]),
  "canonical_de_byte_stable" ->
    (deA === deB &&
      FileHash[FileNameJoin[{outputA, "canonical-de.wl"}], "SHA256"] ===
      FileHash[FileNameJoin[{outputB, "canonical-de.wl"}], "SHA256"])
|>;
receipt = <|"scope" -> "actual-T005-T006-single-variable-full-system",
  "checks" -> checks, "all_pass" -> And @@ Values[checks],
  "canonical_basis_sha256" ->
    sha[FileNameJoin[{outputA, "canonical-basis.wl"}]],
  "canonical_de_sha256" -> sha[FileNameJoin[{outputA, "canonical-de.wl"}]]|>;
Put[receipt, receiptPath];
Print[InputForm[<|"passed" -> Count[Values[checks], True],
  "total" -> Length[checks], "all_pass" -> receipt["all_pass"]|>]];
Exit[If[receipt["all_pass"], 0, 1]];
