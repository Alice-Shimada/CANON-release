$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];

args = CanonMethodCard`ScriptArguments[];
{inputPath, outputDir} = ExpandFileName /@ args;
task = CanonMethodCard`ReadTask[inputPath, "CHECK_CORE"];
sectorBasis = CanonMethodCard`LoadArtifact[task, inputPath, "sector_basis"];
cut = CanonMethodCard`LoadArtifact[task, inputPath, "sector_cut_de"];
candidates = CanonMethodCard`LoadArtifact[task, inputPath, "core_candidates"];

checks = {};
accepted = Missing["not-found"];
Do[
  check = CanonMethodCard`CheckCoreCandidate[
    candidates["candidates"][[index]], cut["matrices"], cut["variables"],
    cut["regulator"], index];
  AppendTo[checks, check];
  If[TrueQ[check["pass"]], accepted = check; Break[]],
  {index, Length[candidates["candidates"]]}
];
public[entry_] := KeyDrop[entry, {"transformation", "transformed_matrices"}];
pool = candidates["candidate_group_pool"];
attemptedIDs = #["candidate_id"] & /@ checks;
remaining = pool["remaining"] + pool["eligible"] - Length[checks];

If[MissingQ[accepted],
  poolExhausted = TrueQ[pool["pool_exhausted"]] && remaining === 0;
  CanonMethodCard`WriteResult[
    task, outputDir,
    If[poolExhausted, "FAIL", "INCONCLUSIVE"],
    If[poolExhausted, "CORE_FAIL", "CANDIDATE_BUDGET_EXHAUSTED"],
    <||>,
    <|"attempted_candidate_ids" -> attemptedIDs,
        "remaining_candidate_groups" -> remaining,
        "pool_exhausted" -> poolExhausted,
        "repair_eligible" -> poolExhausted,
        "repair_invoked" -> False,
        "attempts" -> (public /@ checks),
        "preferred_next_route" -> "FIND_RATIONAL_CANONICAL_WITH_CANONICA"|>
  ];
  Quit[0]
];

coreTransform = <|
  "schema" -> "canon-neu/core-transform/v1",
  "sector" -> cut["sector"], "family_id" -> cut["family_id"],
  "basis_id" -> cut["basis_id"],
  "coefficient_domain" -> "exact-algebraic-functions",
  "basis" -> sectorBasis["basis"], "variables" -> cut["variables"],
  "regulator" -> cut["regulator"],
  "convention" -> "old_basis = transformation . new_basis",
  "method" -> candidates["method"],
  "candidate_id" -> accepted["candidate_id"],
  "candidate_index" -> accepted["index"],
  "transformation" -> accepted["transformation"],
  "transformed_matrices" -> accepted["transformed_matrices"],
  "checks" -> public[accepted]
|>;
artifactPath = CanonMethodCard`WriteWLArtifact[coreTransform, outputDir, "core-transform.wl"];
CanonMethodCard`WriteResult[
  task, outputDir, "PASS", "CORE_PASS",
  <|"core_transform" -> <|
    "type" -> "mathematica-expression", "path" -> FileNameTake[artifactPath]|>|>,
  <|"selected_candidate_id" -> accepted["candidate_id"],
    "candidate_index" -> accepted["index"],
    "attempted_candidate_ids" -> attemptedIDs,
    "remaining_candidate_groups" -> remaining,
    "pool_exhausted" -> False, "repair_eligible" -> False,
    "repair_invoked" -> False, "attempts" -> (public /@ checks)|>
];
