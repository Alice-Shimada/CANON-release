#!/usr/bin/env wolframscript

$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
temporary = CreateDirectory[];
ClearAll[l0, j0, k0, eps, x];

put[name_, expression_] := Module[{path = FileNameJoin[{temporary, name <> ".wl"}]},
  Put[expression, path]; path];
descriptor[path_] := <|"type" -> "mathematica-expression", "path" -> path|>;
runStep[name_, script_, step_, sector_, payload_] := Module[{input, output, process},
  input = FileNameJoin[{temporary, name <> ".json"}];
  output = FileNameJoin[{temporary, name}];
  Export[input, <|"schema" -> "canon-neu/script-input/v1",
    "task_id" -> name, "step" -> step, "sector" -> sector,
    "payload" -> payload|>, "RawJSON"];
  process = RunProcess[{Replace[Environment["CANON_WOLFRAMSCRIPT"], Except[_String] -> "wolframscript"], "-file",
    FileNameJoin[{repoRoot, "mma", script}], input, output}];
  <|"process" -> process, "output" -> output,
    "result" -> Import[FileNameJoin[{output, "result.json"}], "RawJSON"]|>
];
artifact[run_, key_] := Get[FileNameJoin[{run["output"],
  run["result", "artifacts", key, "path"]}]];
artifactPath[run_, key_] := FileNameJoin[{run["output"],
  run["result", "artifacts", key, "path"]}];
sameMatrices[left_, right_] := And @@ MapThread[
  And @@ (TrueQ[Together[#] === 0] & /@ Flatten[#1 - #2]) &, {left, right}];

family = "fixture-canonical-commit";
sector0 = <|"id" -> 1, "propagator_count" -> 1|>;
sector1 = <|"id" -> 3, "propagator_count" -> 2|>;
sector2 = <|"id" -> 7, "propagator_count" -> 3|>;
basis0 = <|"schema" -> "canon-neu/sector-basis/v1", "sector" -> sector0,
  "family_id" -> family, "basis_id" -> "fixture/sector-1", "basis" -> {l0}|>;
full0 = <|"schema" -> "canon-neu/full-prefix-candidates/v1",
  "sector" -> sector0, "family_id" -> family,
  "current_basis_id" -> basis0["basis_id"], "accepted_prefix_id" -> Null,
  "coefficient_domain" -> "exact-rational-functions",
  "source_basis" -> {l0}, "variables" -> {x}, "regulator" -> eps,
  "alphabet" -> {x},
  "convention" -> "old_prefix_basis = full_transformation . candidate_prefix_basis",
  "source_matrices" -> {{{eps/x}}},
  "block_boundaries" -> <|"lower_dimension" -> 0, "current_dimension" -> 1|>|>;
transform0 = <|"schema" -> "canon-neu/sector-transform/v1",
  "sector" -> sector0, "family_id" -> family,
  "current_basis_id" -> basis0["basis_id"], "accepted_prefix_id" -> Null,
  "coefficient_domain" -> "exact-rational-functions", "source_basis" -> {l0},
  "variables" -> {x}, "regulator" -> eps, "alphabet" -> {x},
  "convention" -> full0["convention"], "candidate_id" -> "first",
  "member_candidate_ids" -> {"first-member"}, "transformation" -> {{2}},
  "transformed_matrices" -> {{{eps/x}}}, "method" -> "first-sector-no-tail"|>;

basis0Path = put["basis-0", basis0];
full0Path = put["full-0", full0];
transform0Path = put["transform-0", transform0];
check0 = runStep["check-0", "CheckCanonical.wls", "CHECK_CANONICAL", sector0,
  <|"full_sector_de" -> descriptor[full0Path],
    "sector_transform" -> descriptor[transform0Path], "accepted_prefix" -> Null|>];
canonical0Path = artifactPath[check0, "canonical_sector_de"];
commit0 = runStep["commit-0", "CommitSector.wls", "COMMIT_SECTOR", sector0,
  <|"previous_accepted_prefix" -> Null, "sector_basis" -> descriptor[basis0Path],
    "sector_transform" -> descriptor[transform0Path],
    "canonical_sector_de" -> descriptor[canonical0Path]|>];
commit0Replay = runStep["commit-0-replay", "CommitSector.wls", "COMMIT_SECTOR", sector0,
  <|"previous_accepted_prefix" -> Null, "sector_basis" -> descriptor[basis0Path],
    "sector_transform" -> descriptor[transform0Path],
    "canonical_sector_de" -> descriptor[canonical0Path]|>];
accepted0Path = artifactPath[commit0, "accepted_prefix"];
accepted0 = artifact[commit0, "accepted_prefix"];

tail = 1 + eps (1/x - x/(1 - x) + 1);
source1 = {{{eps/x, 0}, {tail, eps/(1 - x)}}};
canonicalMatrix1 = {{{eps/x, 0}, {eps/x, eps/(1 - x)}}};
basis1 = <|"schema" -> "canon-neu/sector-basis/v1", "sector" -> sector1,
  "family_id" -> family, "basis_id" -> "fixture/sector-3", "basis" -> {j0}|>;
full1 = <|"schema" -> "canon-neu/full-prefix-candidates/v1",
  "sector" -> sector1, "family_id" -> family,
  "current_basis_id" -> basis1["basis_id"],
  "accepted_prefix_id" -> accepted0["prefix_id"],
  "coefficient_domain" -> "exact-rational-functions",
  "source_basis" -> Join[accepted0["basis"], {j0}],
  "variables" -> {x}, "regulator" -> eps, "alphabet" -> {x, 1 - x},
  "convention" -> "old_prefix_basis = full_transformation . candidate_prefix_basis",
  "source_matrices" -> source1,
  "block_boundaries" -> <|"lower_dimension" -> 1, "current_dimension" -> 1|>|>;
transform1 = <|"schema" -> "canon-neu/sector-transform/v1",
  "sector" -> sector1, "family_id" -> family,
  "current_basis_id" -> basis1["basis_id"],
  "accepted_prefix_id" -> accepted0["prefix_id"],
  "coefficient_domain" -> "exact-rational-functions",
  "source_basis" -> full1["source_basis"], "variables" -> {x},
  "regulator" -> eps, "alphabet" -> full1["alphabet"],
  "convention" -> full1["convention"], "candidate_id" -> "completed",
  "member_candidate_ids" -> {"completed-member"},
  "transformation" -> {{1, 0}, {x, 1}},
  "transformed_matrices" -> canonicalMatrix1,
  "method" -> "full-prefix-tail-screen"|>;
basis1Path = put["basis-1", basis1];
full1Path = put["full-1", full1];
transform1Path = put["transform-1", transform1];
check1 = runStep["check-1", "CheckCanonical.wls", "CHECK_CANONICAL", sector1,
  <|"full_sector_de" -> descriptor[full1Path],
    "sector_transform" -> descriptor[transform1Path],
    "accepted_prefix" -> descriptor[accepted0Path]|>];
canonical1Path = artifactPath[check1, "canonical_sector_de"];
canonical1 = artifact[check1, "canonical_sector_de"];
commit1 = runStep["commit-1", "CommitSector.wls", "COMMIT_SECTOR", sector1,
  <|"previous_accepted_prefix" -> descriptor[accepted0Path],
    "sector_basis" -> descriptor[basis1Path],
    "sector_transform" -> descriptor[transform1Path],
    "canonical_sector_de" -> descriptor[canonical1Path]|>];
accepted1Path = artifactPath[commit1, "accepted_prefix"];
accepted1 = artifact[commit1, "accepted_prefix"];

coreBad = ReplacePart[transform1, "transformed_matrices" ->
  ReplacePart[canonicalMatrix1, {1, 2, 2} -> 0]];
coreBadPath = put["core-bad", coreBad];
coreFail = runStep["core-fail", "CheckCanonical.wls", "CHECK_CANONICAL", sector1,
  <|"full_sector_de" -> descriptor[full1Path],
    "sector_transform" -> descriptor[coreBadPath],
    "accepted_prefix" -> descriptor[accepted0Path]|>];
tailBad = ReplacePart[transform1, "transformation" -> {{2, 0}, {x, 1}}];
tailBadPath = put["tail-bad", tailBad];
tailFail = runStep["tail-fail", "CheckCanonical.wls", "CHECK_CANONICAL", sector1,
  <|"full_sector_de" -> descriptor[full1Path],
    "sector_transform" -> descriptor[tailBadPath],
    "accepted_prefix" -> descriptor[accepted0Path]|>];

manifest = <|"schema" -> "canon-neu/sector-manifest/v1",
  "ordering" -> "ascending (propagator_count, id) source order",
  "sectors" -> {sector0, sector1, sector2}|>;
manifestPath = put["manifest", manifest];
cursorNull = runStep["cursor-null", "NextSector.wls", "NEXT_SECTOR", Null,
  <|"sector_manifest" -> descriptor[manifestPath], "accepted_prefix" -> Null|>];
cursor0 = runStep["cursor-0", "NextSector.wls", "NEXT_SECTOR", Null,
  <|"sector_manifest" -> descriptor[manifestPath],
    "accepted_prefix" -> descriptor[accepted0Path]|>];
cursor1 = runStep["cursor-1", "NextSector.wls", "NEXT_SECTOR", Null,
  <|"sector_manifest" -> descriptor[manifestPath],
    "accepted_prefix" -> descriptor[accepted1Path]|>];
cursor1Replay = runStep["cursor-1-replay", "NextSector.wls", "NEXT_SECTOR", Null,
  <|"sector_manifest" -> descriptor[manifestPath],
    "accepted_prefix" -> descriptor[accepted1Path]|>];

basis2 = <|"schema" -> "canon-neu/sector-basis/v1", "sector" -> sector2,
  "family_id" -> family, "basis_id" -> "fixture/sector-7", "basis" -> {k0}|>;
cut2 = <|"schema" -> "canon-neu/sector-cut-de/v1", "sector" -> sector2,
  "family_id" -> family, "basis_id" -> basis2["basis_id"],
  "coefficient_domain" -> "exact-rational-functions", "basis" -> {k0},
  "variables" -> {x}, "regulator" -> eps,
  "matrices" -> {{{eps/(1 + x)}}}, "sector_boundaries" -> {sector0, sector1}|>;
T0 = ArrayFlatten[{{accepted1["transformation"], ConstantArray[0, {2, 1}]},
  {ConstantArray[0, {1, 2}], IdentityMatrix[1]}}];
source2 = ArrayFlatten[{{First[accepted1["matrices"]], ConstantArray[0, {2, 1}]},
  {ConstantArray[0, {1, 2}], {{eps/(1 + x)}}}}];
raw2 = Map[Together, (T0.source2 + D[T0, x]).Inverse[T0], {2}];
ordered2 = <|"schema" -> "canon-neu/ordered-master-de/v1",
  "family_id" -> family, "basis_id" -> "fixture/raw-order",
  "coefficient_domain" -> "exact-rational-functions", "basis" -> {l0, j0, k0},
  "variables" -> {x}, "regulator" -> eps, "matrices" -> {raw2}|>;
coreCandidates2 = Join[KeyDrop[cut2, {"schema", "matrices", "sector_boundaries"}],
  <|"schema" -> "canon-neu/core-candidates/v1", "source_basis" -> {l0, j0, k0},
  "convention" -> "old_basis = transformation . new_basis", "method" -> <|"id" -> "fixture"|>,
  "candidate_group_pool" -> <|"declared" -> 1, "eligible" -> 1, "remaining" -> 0,
    "unconsumed_candidates" -> 0, "pool_exhausted" -> True|>,
  "candidates" -> {<|"candidate_id" -> "third",
    "member_candidate_ids" -> {"third-member"},
    "construction_rejection" -> None,
    "full_new_basis_rows" -> {{0, 0, 1}}, "transformation" -> {{1}},
    "transformed_matrices" -> cut2["matrices"]|>}|>];
alphabet2 = <|"schema" -> "canon-neu/declared-alphabet/v1",
  "letters" -> {x, 1 - x, 1 + x}|>;
basis2Path = put["basis-2", basis2];
cut2Path = put["cut-2", cut2];
ordered2Path = put["ordered-2", ordered2];
coreCandidates2Path = put["core-candidates-2", coreCandidates2];
coreCheck2 = runStep["core-check-2", "CheckSectorCore.wls", "CHECK_CORE", sector2,
  <|"sector_basis" -> descriptor[basis2Path], "sector_cut_de" -> descriptor[cut2Path],
    "core_candidates" -> descriptor[coreCandidates2Path]|>];
coreTransform2Path = FileNameJoin[{coreCheck2["output"],
  coreCheck2["result", "artifacts", "core_transform", "path"]}];
alphabet2Path = put["alphabet-2", alphabet2];
build2 = runStep["build-2", "BuildFullSectorDE.wls", "BUILD_FULL_DE", sector2,
  <|"ordered_master_de" -> descriptor[ordered2Path],
    "sector_cut_de" -> descriptor[cut2Path],
    "core_candidates" -> descriptor[coreCandidates2Path],
    "core_transform" -> descriptor[coreTransform2Path],
    "declared_alphabet" -> descriptor[alphabet2Path],
    "accepted_prefix" -> descriptor[accepted1Path]|>];
full2 = artifact[build2, "full_sector_de"];

(* Preserve the legacy nonzero upper-right route as well as the zero shortcut. *)
orderedUpper = ReplacePart[ordered2, {"matrices", 1, 1, 3} -> 1/x];
orderedUpperPath = put["ordered-upper", orderedUpper];
buildUpper = runStep["build-upper", "BuildFullSectorDE.wls", "BUILD_FULL_DE", sector2,
  <|"ordered_master_de" -> descriptor[orderedUpperPath],
    "sector_cut_de" -> descriptor[cut2Path], "core_candidates" -> descriptor[coreCandidates2Path],
    "core_transform" -> descriptor[coreTransform2Path],
    "declared_alphabet" -> descriptor[alphabet2Path],
    "accepted_prefix" -> descriptor[accepted1Path]|>];
expectedUpper = Map[Together, Inverse[T0].(First[orderedUpper["matrices"]].T0-D[T0,x]), {2}];

tests = {
  VerificationTest[
    Lookup[commit0["result", "summary"],
      {"accepted_sector_count", "accepted_master_count", "previous_master_count", "new_master_count"}] ===
      {1, 1, 0, 1} &&
    Lookup[commit1["result", "summary"],
      {"accepted_sector_count", "accepted_master_count", "previous_master_count", "new_master_count"}] ===
      {2, 2, 1, 1},
    True, TestID -> "reports-initial-and-cumulative-master-counts"],
  VerificationTest[
    Lookup[{check0["result"], commit0["result"]}, {"status", "code"}] ===
      {{"PASS", "CANONICAL_PASS"}, {"PASS", "OK"}} &&
    accepted0["parent_prefix_id"] === Null && accepted0["sector_trace"] === {sector0},
    True, TestID -> "null-prefix-checks-and-commits-first-sector"],
  VerificationTest[
    accepted0["basis"] === {l0/2} && accepted0["transformation"] === {{2}} &&
    Map[Together, accepted0["transformation"].accepted0["basis"] -
      accepted0["source_basis"]] === {0} &&
    accepted0["prefix_id"] === artifact[commit0Replay, "accepted_prefix"]["prefix_id"] &&
    FileHash[accepted0Path, "SHA256"] ===
      FileHash[artifactPath[commit0Replay, "accepted_prefix"], "SHA256"],
    True, TestID -> "first-sector-prefix-hash-is-byte-stable"],
  VerificationTest[
    Lookup[{check1["result"], commit1["result"]}, {"status", "code"}] ===
      {{"PASS", "CANONICAL_PASS"}, {"PASS", "OK"}} &&
    accepted1["basis"] === {l0/2, j0 - x l0/2} &&
    accepted1["transformation"] === {{2, 0}, {x, 1}} &&
    Map[Together, accepted1["transformation"].accepted1["basis"] -
      accepted1["source_basis"]] === {0, 0} &&
    sameMatrices[canonical1["matrices"], canonicalMatrix1],
    True, TestID -> "second-sector-composes-raw-transform-and-accepted-basis"],
  VerificationTest[
    Take[accepted1["source_basis"], 1] === accepted0["source_basis"] &&
    Take[accepted1["basis"], 1] === accepted0["basis"] &&
    accepted1["transformation"][[1 ;; 1, 1 ;; 1]] === accepted0["transformation"] &&
    (#[[1 ;; 1, 1 ;; 1]] & /@ accepted1["matrices"]) === accepted0["matrices"] &&
    Take[accepted1["alphabet"], Length[accepted0["alphabet"]]] ===
      accepted0["alphabet"] &&
    Take[accepted1["sector_trace"], 1] === accepted0["sector_trace"] &&
    Take[accepted1["candidate_trace"], 1] === accepted0["candidate_trace"],
    True, TestID -> "commit-preserves-every-previous-prefix-block"],
  VerificationTest[
    Lookup[coreFail["result"], {"status", "code"}] === {"FAIL", "CORE_FAIL"} &&
    !TrueQ[coreFail["result", "summary", "core_checks", "exact_gauge"]],
    True, TestID -> "current-current-failure-is-core-fail"],
  VerificationTest[
    Lookup[tailFail["result"], {"status", "code"}] === {"FAIL", "TAIL_FAIL"} &&
    And @@ Values[tailFail["result", "summary", "core_checks"]] &&
    !TrueQ[tailFail["result", "summary", "full_checks",
      "exact_gauge"]],
    True, TestID -> "incorrect-declared-full-gauge-is-tail-fail"],
  VerificationTest[
    artifact[cursorNull, "sector_cursor"]["next_sector"] === sector0 &&
    artifact[cursor0, "sector_cursor"]["next_sector"] === sector1 &&
    artifact[cursor1, "sector_cursor"]["remaining_sectors"] === {sector2} &&
    FileHash[artifactPath[cursor1, "sector_cursor"], "SHA256"] ===
      FileHash[artifactPath[cursor1Replay, "sector_cursor"], "SHA256"],
    True, TestID -> "artifact-only-cursor-resumes-in-resident-order"],
  VerificationTest[
    Lookup[build2["result"], {"status", "code"}] === {"PASS", "OK"} &&
    full2["lower_basis"] === accepted1["basis"] &&
    full2["accepted_prefix_transformation"] === T0 &&
    sameMatrices[full2["source_matrices"], {source2}] &&
    full2["source_positions"] === {1, 2, 3},
    True, TestID -> "committed-prefix-feeds-the-next-full-sector-build"],
  VerificationTest[
    buildUpper["result", "status"] === "PASS" &&
    sameMatrices[artifact[buildUpper, "full_sector_de"]["source_matrices"], {expectedUpper}],
    True, TestID -> "nonzero-upper-right-retains-original-exact-gauge"]
};

report = TestReport[tests];
Print[InputForm[<|"total" -> report["TestsSucceededCount"] +
    report["TestsFailedCount"], "succeeded" -> report["TestsSucceededCount"],
  "failed" -> report["TestsFailedCount"]|>]];
If[report["TestsFailedCount"] =!= 0, Print[InputForm[report["TestsFailed"]]]];
DeleteDirectory[temporary, DeleteContents -> True];
Exit[If[report["TestsFailedCount"] === 0, 0, 1]];
