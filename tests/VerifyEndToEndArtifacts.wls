#!/usr/bin/env wolframscript

$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
{runA, runB, receiptPath} = ExpandFileName /@ Rest[$ScriptCommandLine];
load[root_, path_] := Get[FileNameJoin[{root, path}]];
sha[path_] := FileHash[path, "SHA256", "HexString"];
zeroQ[expression_] := And @@ (Together[#] === 0 & /@ Flatten[expression]);
sameMatrices[left_, right_] := And @@ MapThread[
  zeroQ[Map[Together, #1 - #2, {2}]] &, {left, right}];

candidate = load[runA, "02-propose/integral-candidates.wl"];
master = load[runA, "03-discover/master-basis.wl"];
manifest = load[runA, "03-discover/sector-manifest.wl"];
bridge = load[runA, "04-candidate-ibp-bridge.wl"];
ordered = load[runA, "05-build-cut/ordered-master-de.wl"];
accepted = load[runA, "11-commit/accepted-prefix.wl"];
cursor = load[runA, "12-next/sector-cursor.wl"];
basis = load[runA, "13-final/canonical-basis.wl"];
de = load[runA, "13-final/canonical-de.wl"];
receiptA = load[runA, "end-to-end-receipt.wl"];
receiptB = load[runB, "end-to-end-receipt.wl"];
variable = First[ordered["variables"]];
regulator = ordered["regulator"];
dimension = CANON`DEData`d;
masterIntegral = First[master["masters"]];
packageOutput = candidate["method_evidence", "evidence"][[1, "output"]];
Get[candidate["tool_provenance", "entry"]];
fixture = FileNameJoin[{repoRoot, "tests", "fixtures",
  "kira-one-loop-triangle-sector-5"}];
familyData = Get[FileNameJoin[{fixture, "family.wl"}]];
packageCandidates = Take[
  packageOutput["CandidateCombinations"],
  UpTo[Length[candidate["candidates"]]]
] /. HoldPattern[DlogBasis`DlogIntegral[_, indices_List]] :>
    Apply[CANON`DEData`j, Prepend[indices, CANON`DEData`tri]] /.
  Thread[familyData["Family", "KinematicVariables"] -> ordered["variables"]] /.
  DlogBasis`DimensionalRegulator -> regulator;
targets = Lookup[bridge["reducer_targets"], "integral"];
expectedTargets = {Head[masterIntegral][1, -1, 1],
  Head[masterIntegral][1, -1, 2], Head[masterIntegral][0, 0, 2],
  Head[masterIntegral][1, 0, 2]};
expectedRules = {
  Head[masterIntegral][0, 0, 2] -> 0,
  Head[masterIntegral][1, -1, 1] -> -variable masterIntegral/2,
  Head[masterIntegral][1, -1, 2] -> (-1 + dimension/2) masterIntegral,
  Head[masterIntegral][1, 0, 2] -> (3 - dimension) masterIntegral/variable};
transformation = accepted["transformation"];
computed = MapThread[Map[Together, Inverse[transformation].
  (#1.transformation - D[transformation, #2]), {2}] &,
  {ordered["matrices"], ordered["variables"]}];
reconstructed = {regulator Total@MapThread[
  #1 D[#2, variable]/#2 &, {de["residue_matrices"], de["alphabet"]}]};

stablePaths = {"02-propose/integral-candidates.wl",
  "04-candidate-ibp-bridge.wl", "05-build-cut/ordered-master-de.wl",
  "11-commit/accepted-prefix.wl", "13-final/canonical-basis.wl",
  "13-final/canonical-de.wl", "end-to-end-receipt.wl"};
packageRoot = DirectoryName[candidate["tool_provenance", "entry"]];
hashesMatch[association_, root_] := And @@ KeyValueMap[
  sha[FileNameJoin[{root, #1}]] === #2 &, association];
checks = <|
  "independent_process_byte_replay" -> And @@
    (sha[FileNameJoin[{runA, #}]] === sha[FileNameJoin[{runB, #}]] & /@
      stablePaths),
  "recorded_receipts_are_identical" -> (receiptA === receiptB),
  "recorded_input_hashes" -> hashesMatch[receiptA["input_sha256"], fixture],
  "recorded_implementation_hashes" ->
    hashesMatch[receiptA["implementation_sha256"], repoRoot],
  "recorded_dlogbasis_runtime_hashes" ->
    hashesMatch[receiptA["runtime", "dlogbasis_refine"], packageRoot],
  "recorded_kira_hash" ->
    (sha[receiptA["runtime", "kira", "path"]] ===
      receiptA["runtime", "kira", "sha256"]),
  "projective_candidate_reconstruction" -> And @@ MapThread[
    Together[#1["normalization", "factor"] ReleaseHold[#1["exact_definition"]] -
      #2] === 0 &, {candidate["candidates"], packageCandidates}],
  "bounded_candidate_evidence" ->
    (StringContainsQ[packageOutput["ScientificStatus"], "ConstantLSCandidate"] &&
      packageOutput["CandidateCombinations"] =!= {} &&
      TrueQ[packageOutput["ModuleLift", "ModuleLiftVerifiedQ"]] &&
      !TrueQ[packageOutput["ConstantLeadingSingularityCertifiedQ"]] &&
      !TrueQ[packageOutput["UniformTranscendentalityCertifiedQ"]] &&
      !TrueQ[packageOutput["CanonicalBasisCertifiedQ"]]),
  "enhanced_baikov_operator" ->
    (bridge["operators", variable, "kind"] === "enhanced-baikov"),
  "ordered_master_and_complete_targets" ->
    (master["masters"] === {masterIntegral} && ContainsExactly[targets, expectedTargets]),
  "fully_back_substituted_rules" ->
    (ContainsExactly[First /@ bridge["rules"], expectedTargets] &&
      And @@ (Together[(# /. Dispatch[bridge["rules"]]) -
          (# /. Dispatch[expectedRules])] === 0 & /@ expectedTargets) &&
      FreeQ[Last /@ bridge["rules"], Alternatives @@ expectedTargets]),
  "raw_master_de" ->
    zeroQ[ordered["matrices"] - {{{-(1 + regulator)/variable}}}],
  "rational_canonical_basis" ->
    (transformation === {{2/((1 + 2 regulator) variable)}} &&
      basis["basis"] === {(1 + 2 regulator) variable masterIntegral/2}),
  "exact_global_gauge" ->
    (sameMatrices[computed, accepted["matrices"]] &&
      sameMatrices[computed, de["matrices"]]),
  "single_letter_constant_residue_dlog" ->
    (de["alphabet"] === {variable} && de["residue_matrices"] === {{{-1}}} &&
      sameMatrices[computed, reconstructed]),
  "sector_order_and_cursor" ->
    (accepted["sector_trace"] ===
      (KeyTake[#, {"id", "propagator_count"}] & /@ manifest["sectors"]) &&
      TrueQ[cursor["complete"]] && cursor["remaining_sectors"] === {}),
  "accepted_prefix_hash" -> (accepted["prefix_id"] === "sha256:" <>
    Hash[KeyDrop[accepted, "prefix_id"], "SHA256", "HexString"]),
  "final_checker_invariants" -> And @@ Values[de["checks"]],
  "claim_boundary" ->
    (receiptA["claim_boundary", "canonical_form"] === "exact" &&
      receiptA["claim_boundary", "projective_ansatz"] ===
        "no-constant-ls-or-ut-inheritance" &&
      receiptA["claim_boundary", "uniform_transcendentality"] === "not-proved")
|>;
verification = <|"schema" -> "canon-neu/end-to-end-independent-verification/v1",
  "scope" -> "fresh-live-kira-one-loop-single-sector-single-variable",
  "checks" -> checks, "all_pass" -> And @@ Values[checks],
  "canonical_basis_sha256" -> sha[FileNameJoin[{runA,
    "13-final/canonical-basis.wl"}]],
  "canonical_de_sha256" -> sha[FileNameJoin[{runA,
    "13-final/canonical-de.wl"}]]|>;
Put[verification, receiptPath];
Print[InputForm[<|"passed" -> Count[Values[checks], True],
  "total" -> Length[checks], "all_pass" -> verification["all_pass"]|>]];
Exit[If[verification["all_pass"], 0, 1]];
