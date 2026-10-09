$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];

args = CanonMethodCard`ScriptArguments[];
{inputPath, outputDir} = ExpandFileName /@ args;
task = CanonMethodCard`ReadTask[inputPath, "CHECK_CORE"];
sectorBasis = CanonMethodCard`LoadArtifact[task, inputPath, "sector_basis"];
cut = CanonMethodCard`LoadArtifact[task, inputPath, "sector_cut_de"];
candidates = CanonMethodCard`LoadArtifact[task, inputPath, "core_candidates"];

fail[code_, reason_] := (CanonMethodCard`WriteResult[task, outputDir,
  "ERROR", code, <||>, <|"reason" -> reason|>]; Quit[1]);
If[!TrueQ[CanonMethodCard`ValidSectorBasisQ[sectorBasis] &&
    CanonMethodCard`ValidCutDEQ[cut, True] && CanonMethodCard`ValidCandidatesQ[candidates]],
  fail["INVALID_INPUT", "Malformed core-check artifacts."]];
If[!CanonMethodCard`SameSectorQ[task["sector"], cut["sector"], sectorBasis["sector"], candidates["sector"]] ||
  !AllTrue[{"family_id", "basis_id", "basis"},
    SameQ[sectorBasis[#], cut[#], candidates[#]] &] ||
  !AllTrue[{"variables", "regulator"}, cut[#] === candidates[#] &],
  fail["SOURCE_BASIS_MISMATCH", "Core artifacts must bind the same sector, family, ordered basis, variables and regulator."]];
pool = Lookup[candidates, "candidate_group_pool", <||>];
If[!AssociationQ[pool] ||
  !AllTrue[candidates["candidates"], AssociationQ[#] && StringQ[Lookup[#, "candidate_id", None]] &] ||
  !DuplicateFreeQ[Lookup[candidates["candidates"], "candidate_id", {}]] ||
  Lookup[pool, "eligible", None] =!= Length[candidates["candidates"]] ||
  !IntegerQ[Lookup[pool, "remaining", None]] || pool["remaining"] < 0 ||
  !MemberQ[{True, False}, Lookup[pool, "pool_exhausted", None]],
  fail["INVALID_CANDIDATE_POOL", "The declared pool must count the available candidates and identify them uniquely."]];

checks = {};
accepted = Missing["not-found"];
Do[
  check = CanonMethodCard`CheckCoreCandidate[
    candidates["candidates"][[index]], cut["matrices"], cut["variables"],
    cut["regulator"], index, candidates["coefficient_domain"]];
  AppendTo[checks, check];
  If[TrueQ[check["pass"]], accepted = check; Break[]],
  {index, Length[candidates["candidates"]]}
];
public[entry_] := KeyDrop[entry, {"transformation", "transformed_matrices"}];
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
        "preferred_next_route" -> "SELECT_CORE_METHOD"|>
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
