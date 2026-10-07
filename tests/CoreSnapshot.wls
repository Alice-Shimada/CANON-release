(* Run this unit corpus once per fresh kernel, with entry, fixtures and output paths. *)
$HistoryLength = 0;
args = Rest[$ScriptCommandLine];
{entryFile, fixtureDirectory, outputDirectory} = ExpandFileName /@ args;
Get[entryFile];
CreateDirectory[outputDirectory, CreateIntermediateDirectories -> True];

publicNames = Names["CanonMethodCard`*"];
definitionNames = Select[Join[publicNames, Names["CanonMethodCard`Private`*"]],
  ToExpression[#, InputForm, Function[s, DownValues[s] =!= {}, HoldAll]] &];
definitionHash[name_] := ToExpression[name, InputForm,
  Function[s, IntegerString[Hash[{DownValues[s], SubValues[s], UpValues[s],
    Attributes[s], Options[s]}, "SHA256"], 16, 64], HoldAll]];
definitionHashes = AssociationMap[definitionHash, definitionNames];
publicUsage = AssociationMap[ToExpression[# <> "::usage"] &, publicNames];

records = {};
record[name_String, actual_, expected_] := AppendTo[records, <|
  "name" -> name, "pass" -> SameQ[actual, expected],
  "actual" -> ToString[actual, InputForm], "expected" -> ToString[expected, InputForm]|>];
recordFailure[name_String, actual_, field_String] := (
  record[name, If[FailureQ[actual], Lookup[actual[[2]], "Field", None], actual], field];
  records[[-1]] = Append[records[[-1]], "full_result" -> ToString[actual, InputForm]];
);
replace[expr_, path_List, value_] := ReplacePart[expr, path -> value];
fixture[name_] := Get[FileNameJoin[{fixtureDirectory, name}]];

record["rational-domain", CanonMethodCard`ExactRationalExpressionQ /@
  {1/3, I, (x + y)/(1 - x y), Sqrt[x], Sin[x], Pi, 0.5, Indeterminate},
  {True, True, True, False, False, False, False, False}];
record["declared-symbol-domain", {
  CanonMethodCard`DeclaredCoefficientDomainQ[(x + eps)/(1 - x), {x, eps}],
  CanonMethodCard`DeclaredCoefficientDomainQ[z/x, {x, eps}]}, {True, False}];
cut = fixture["sector-cut-de.wl"];
record["cut-boundary", CanonMethodCard`ValidCutDEQ /@ {cut,
  Join[cut, <|"matrices" -> {{{1.0}}}|>], Join[cut, <|"variables" -> {}|>]},
  {True, False, False}];
record["sector-basis-boundary", CanonMethodCard`ValidSectorBasisQ /@
  {fixture["sector-basis.wl"], <||>, 1}, {True, False, False}];
record["candidate-boundary", CanonMethodCard`ValidCandidatesQ /@
  {fixture["bad-core-candidates.wl"], <||>, 1}, {True, False, False}];

family = <|"family_ref" -> "family", "basis_ref" -> "basis", "topology" -> J,
  "integral_head" -> J, "index_order" -> {a1, a2, a3}, "propagator_slots" -> {1, 2},
  "sector_convention" -> "positive propagators; ISP bits zero"|>;
sourceMasters = {J[1, 1, -1], J[0, 1, 0], J[1, 0, 0], J[2, 1, 0], J[1, 0, -2]};
formatted = CanonMethodCard`FormatMasterArtifacts[family, sourceMasters, "source-hash"];
manifest = formatted["sector_manifest"];
masters = formatted["master_basis"]["masters"];
record["sector-ISP-mask", CanonMethodCard`SectorBits[J[2, 0, 9], {1, 2}], {1, 0, 0}];
record["resident-master-order", masters,
  {J[1, 0, 0], J[1, 0, -2], J[0, 1, 0], J[1, 1, -1], J[2, 1, 0]}];
record["manifest-sector-order", Lookup[manifest["sectors"], "id"], {1, 2, 3}];
ordered = <|"family_id" -> "family", "basis_id" -> "basis", "basis" -> masters,
  "variables" -> {x, y}, "regulator" -> eps,
  "coefficient_domain" -> "exact-rational-functions",
  "matrices" -> {Table[eps (10 i + j)/x, {i, 5}, {j, 5}],
    Table[eps (100 i + j)/y, {i, 5}, {j, 5}]}|>;
slices = CanonMethodCard`SectorDEArtifacts[ordered, manifest, #] & /@ manifest["sectors"];
record["sector-resident-positions", Lookup[slices, "resident_positions"], {{1, 2}, {3}, {4, 5}}];
record["sector-proper-subsectors", Lookup[slices[[3]]["sector_cut_de"]["proper_subsectors"], "id"], {1, 2}];
record["sector-incomparable-not-lower", slices[[2]]["sector_cut_de"]["proper_subsectors"], {}];
record["sector-cut-slicing", slices[[3]]["sector_cut_de"]["matrices"],
  {ordered["matrices"][[1, {4, 5}, {4, 5}]], ordered["matrices"][[2, {4, 5}, {4, 5}]]}];
record["sector-artifacts-valid", And @@ Table[
  CanonMethodCard`ValidCutDEQ[s["sector_cut_de"]] &&
  CanonMethodCard`ValidSectorBasisQ[s["sector_basis"]], {s, slices}], True];

target = {{{eps/x, 0}, {0, eps/(x - 1)}}, {{eps/y, 0}, {0, 0}}};
transformation = {{x, 1 + y}, {0, 1}};
original = MapThread[Map[Together, (D[transformation, #2] + transformation.#1).
  Inverse[transformation], {2}] &, {target, {x, y}}];
computed = CanonMethodCard`GaugeTransform[original, {x, y}, transformation];
record["gauge-exact-two-directions", computed, target];
record["flatness-positive", CanonMethodCard`FlatConnectionQ[original, {x, y}], True];
record["flatness-negative", CanonMethodCard`FlatConnectionQ[{{{y}}, {{0}}}, {x, y}], False];
record["epsilon-form", CanonMethodCard`EpsilonFactorizedQ[target, eps], True];
record["epsilon-form-negative", CanonMethodCard`EpsilonFactorizedQ[{{{1/x + eps/x}}}, eps], False];
candidate = <|"candidate_id" -> "good", "construction_rejection" -> Null,
  "transformation" -> transformation, "transformed_matrices" -> target|>;
record["core-pass", CanonMethodCard`CheckCoreCandidate[candidate, original, {x, y}, eps, 1]["pass"], True];
record["core-gauge-failure", CanonMethodCard`CheckCoreCandidate[
  Join[candidate, <|"transformed_matrices" -> 2 target|>], original, {x, y}, eps, 1]["rejection_signature"],
  {"gauge_residual"}];
record["core-singular-failure", CanonMethodCard`CheckCoreCandidate[
  Join[candidate, <|"transformation" -> ConstantArray[0, {2, 2}]|>], original, {x, y}, eps, 1]["rejection_signature"],
  {"singular_transformation"}];
record["core-construction-failure", CanonMethodCard`CheckCoreCandidate[
  Join[candidate, <|"construction_rejection" -> "fixture-rejection"|>], original, {x, y}, eps, 1]["rejection_signature"],
  {"fixture-rejection"}];
record["dlog-shared-residues", CanonMethodCard`DLogResidues[target, {x, y}, eps, {x, x - 1, y}],
  {{{1, 0}, {0, 0}}, {{0, 0}, {0, 1}}, {{1, 0}, {0, 0}}}];
record["dlog-direction-mismatch", CanonMethodCard`DLogResidues[
  {{{eps/x}}, {{2 eps/y}}}, {x, y}, eps, {x y}], $Failed];
record["dlog-empty-zero", CanonMethodCard`DLogResidues[{{{0}}}, {x}, eps, {}], {}];
record["dlog-not-epsilon", CanonMethodCard`DLogResidues[{{{1/x}}}, {x}, eps, {x}], $Failed];
letter = (1 - Sqrt[1 - x])/(1 + Sqrt[1 - x]);
record["dlog-algebraic-letter", CanonMethodCard`DLogResidues[
  {{{eps/(x Sqrt[1 - x])}}}, {x}, eps, {letter}], {{{1}}}];
primitive = CanonMethodCard`AlgebraicPrimitive[{D[x Sqrt[1 - x^2], x]}, {x}];
record["algebraic-primitive-derivative", FullSimplify[D[primitive - x Sqrt[1 - x^2], x]], 0];
record["primitive-not-exact", CanonMethodCard`AlgebraicPrimitive[{y, 0}, {x, y}], $Failed];

prepared = fixture["prepared-basis-refine.wl"];
record["prepared-positive", CanonMethodCard`ValidatePreparedBasis[prepared], prepared];
record["prepared-refine-route", CanonMethodCard`PreparedBasisRoute[prepared]["decision"], "REFINE_SECTOR_UT_CANDIDATES"];
completed = replace[prepared, {Key["search_history"]}, <|"plateau" -> True, "pool_exhausted" -> True,
  "alternatives_remaining" -> 0, "attempted_candidate_ids" -> Lookup[prepared["candidates"], "candidate_id"]|>];
record["prepared-tail-route", CanonMethodCard`PreparedBasisRoute[completed]["decision"], "SOLVE_TAIL"];
noDefect = <|"present" -> False, "block" -> Null, "signature" -> <||>|>;
global = replace[completed, {Key["candidates"], 1, Key["suspicious"]}, False];
global = replace[global, {Key["quality"], Key["localized_defect"]}, noDefect];
global = replace[global, {Key["remaining_problem"], Key["classification"]}, "GLOBAL_RATIONAL_DEFECT"];
record["prepared-rational-route", CanonMethodCard`PreparedBasisRoute[global]["decision"], "FIND_RATIONAL_CANONICAL_WITH_CANONICA"];
canonical = replace[global, {Key["quality"], Key["off_diagonal"]}, "CANONICAL"];
canonical = replace[canonical, {Key["remaining_problem"], Key["classification"]}, "NONE"];
canonical = replace[canonical, {Key["remaining_problem"], Key["rational_transformation_expected"]}, False];
record["prepared-canonical-route", CanonMethodCard`PreparedBasisRoute[canonical]["decision"], "VERIFY_CANONICAL_DE"];
unknown = replace[global, {Key["remaining_problem"], Key["classification"]}, "UNKNOWN_OR_NONRATIONAL"];
unknown = replace[unknown, {Key["remaining_problem"], Key["rational_transformation_expected"]}, False];
record["prepared-diagnose-route", CanonMethodCard`PreparedBasisRoute[unknown]["decision"], "DIAGNOSE_OR_CHANGE_VARIABLES"];
preparedNegatives = {
  {"identity", {Key["identity"], Key["basis_id"]}, "", "identity"},
  {"current-basis-id", {Key["current_basis"], Key["basis_id"]}, 17, "current_basis"},
  {"unaccepted-prefix", {Key["frozen_lower_prefix"], Key["accepted"]}, False, "frozen_lower_prefix"},
  {"candidate-normalization", {Key["candidates"], 1, Key["normalization"]}, "", "candidates"},
  {"candidate-rank", {Key["candidates"], 2, Key["rank"]}, 1, "candidates.rank"},
  {"two-selected", {Key["candidates"], 2, Key["selected"]}, True, "candidates.selected"},
  {"quality-kind", {Key["quality"], Key["diagonal"]}, "INVALID", "quality"},
  {"empty-defect", {Key["quality"], Key["localized_defect"], Key["signature"]}, <||>, "quality.localized_defect"},
  {"evidence-link", {Key["ut_evidence_references"], 1, Key["candidate_id"]}, "unknown", "ut_evidence_references"},
  {"history-type", {Key["search_history"], Key["attempted_candidate_ids"]}, 9, "search_history"},
  {"history-empty-id", {Key["search_history"], Key["attempted_candidate_ids"]}, {""}, "search_history.attempted_candidate_ids"},
  {"history-nonstring-id", {Key["search_history"], Key["attempted_candidate_ids"]}, {17}, "search_history.attempted_candidate_ids"},
  {"history-count", {Key["search_history"], Key["alternatives_remaining"]}, 0, "search_history.alternatives_remaining"},
  {"history-exhausted", {Key["search_history"], Key["pool_exhausted"]}, True, "search_history"},
  {"remaining-shape", {Key["remaining_problem"]}, <||>, "remaining_problem"},
  {"selection-complete", {Key["remaining_problem"], Key["candidate_selection_complete"]}, True, "remaining_problem.candidate_selection_complete"},
  {"rational-expectation", {Key["remaining_problem"], Key["rational_transformation_expected"]}, False, "remaining_problem.rational_transformation_expected"}
};
Do[recordFailure["prepared-" <> item[[1]], CanonMethodCard`ValidatePreparedBasis[
  replace[prepared, item[[2]], item[[3]]]], item[[4]]], {item, preparedNegatives}];
recordFailure["prepared-non-association", CanonMethodCard`ValidatePreparedBasis[1], "$"];
recordFailure["prepared-schema", CanonMethodCard`ValidatePreparedBasis[<||>], "schema"];

repairPrepared = fixture["structured-repair-prepared-basis.wl"];
repairRoute = fixture["structured-repair-route-decision.wl"];
repairRequest = fixture["structured-repair-input.wl"];
repairCandidate = fixture["structured-repair-candidate.wl"];
record["repair-positive", CanonMethodCard`ValidateStructuredRepairInput[repairPrepared, repairRoute, repairRequest], repairRequest];
repairNegatives = {
  {"identity", {Key["family_id"]}, "wrong", "identity"},
  {"convention", {Key["convention"]}, "wrong", "convention"},
  {"variables", {Key["variables"]}, {y}, "differential_system"},
  {"regulator", {Key["regulator"]}, delta, "differential_system.identity"},
  {"parameters", {Key["parameters"]}, {z}, "differential_system"},
  {"matrix-shape", {Key["original_matrices"]}, {{{1}}}, "original_matrices"},
  {"matrix-inexact", {Key["original_matrices"], 1, 2, 3}, 0.5, "original_matrices"},
  {"matrix-undeclared", {Key["original_matrices"], 1, 2, 3}, z/x, "original_matrices"},
  {"alphabet-regulator", {Key["alphabet"]}, {x, eps}, "alphabet"},
  {"frozen-shape", {Key["frozen_prefix"]}, 1, "frozen_prefix"},
  {"frozen-matrix-inexact", {Key["frozen_prefix"], Key["accepted_matrices"]}, {{{0.5}}}, "frozen_prefix"},
  {"frozen-matrix-undeclared", {Key["frozen_prefix"], Key["accepted_matrices"]}, {{{z/x}}}, "frozen_prefix"},
  {"frozen-cross-block", {Key["original_matrices"], 1, 1, 2}, eps/x, "frozen_prefix.source_blocks"},
  {"target-map", {Key["localized_target"], Key["full_entry"]}, {3, 2}, "localized_target.full_entry"},
  {"search-mismatch", {Key["search_evidence"], Key["attempted_candidate_ids"]}, {}, "search_evidence"},
  {"search-non-association", {Key["search_evidence"]}, 1, "search_evidence"}
};
Do[recordFailure["repair-" <> item[[1]], CanonMethodCard`ValidateStructuredRepairInput[
  repairPrepared, repairRoute, replace[repairRequest, item[[2]], item[[3]]]], item[[4]]], {item, repairNegatives}];
recordFailure["repair-wrong-route", CanonMethodCard`ValidateStructuredRepairInput[repairPrepared,
  Join[repairRoute, <|"decision" -> "SOLVE_TAIL"|>], repairRequest], "route_decision.decision"];
unexhaustedHistory = Join[repairPrepared["search_history"], <|"pool_exhausted" -> False,
  "alternatives_remaining" -> 1, "attempted_candidate_ids" -> {"fixture-structured-candidate-a"}|>];
recordFailure["repair-valid-unexhausted-history", CanonMethodCard`ValidateStructuredRepairInput[
  Join[repairPrepared, <|"search_history" -> unexhaustedHistory|>], repairRoute,
  Join[repairRequest, <|"search_evidence" -> unexhaustedHistory|>]], "search_evidence.pool_exhausted"];
inconsistentHistory = Join[unexhaustedHistory, <|"pool_exhausted" -> True|>];
recordFailure["repair-invalid-exhausted-history", CanonMethodCard`ValidateStructuredRepairInput[
  Join[repairPrepared, <|"search_history" -> inconsistentHistory|>], repairRoute,
  Join[repairRequest, <|"search_evidence" -> inconsistentHistory|>]], "prepared_basis"];
noncanonicalRequest = replace[repairRequest, {Key["original_matrices"], 1, 1, 1}, 1/x];
noncanonicalRequest = replace[noncanonicalRequest, {Key["frozen_prefix"], Key["accepted_matrices"]}, {{{1/x}}}];
recordFailure["repair-prefix-not-canonical", CanonMethodCard`ValidateStructuredRepairInput[
  repairPrepared, repairRoute, noncanonicalRequest], "frozen_prefix.accepted_matrices"];
record["repair-publication-positive", CanonMethodCard`StructuredRepairPublicationGate[repairRequest, repairCandidate]["pass"], True];
publicationNegatives = {
  {"identity", {Key["basis_id"]}, "wrong", "identity_or_order_mismatch"},
  {"status", {Key["provider_status"]}, "PASS", "forged_provider_status"},
  {"shape", {Key["transformation"]}, {{1}}, "candidate_shape_invalid"},
  {"domain", {Key["transformation"], 2, 2}, 1 + z, "coefficient_domain_invalid"},
  {"singular", {Key["transformation"], 2, 2}, 0, "singular_transformation"},
  {"prefix", {Key["transformation"], 1, 1}, 2, "frozen_prefix_modified"},
  {"mixing", {Key["transformation"], 1, 2}, x, "forbidden_prefix_mixing"}
};
Do[record["publication-" <> item[[1]], MemberQ[
  CanonMethodCard`StructuredRepairPublicationGate[repairRequest,
    replace[repairCandidate, item[[2]], item[[3]]]]["reasons"], item[[4]]], True], {item, publicationNegatives}];

task = <|"schema" -> "canon-neu/script-input/v1", "task_id" -> "T-UNIT",
  "step" -> "SEARCH_CORE", "payload" -> <||>|>;
inputFile = FileNameJoin[{outputDirectory, "input.json"}];
Export[inputFile, task, "RawJSON"];
record["read-task", CanonMethodCard`ReadTask[inputFile, "SEARCH_CORE"], task];
record["read-task-step-failure", FailureQ[CanonMethodCard`ReadTask[inputFile, "OTHER"]], True];
artifactFile = CanonMethodCard`WriteWLArtifact[<|"value" -> x|>, outputDirectory, "fixture.wl"];
record["artifact-write-and-load", CanonMethodCard`LoadArtifact[
  Join[task, <|"payload" -> <|"fixture" -> <|"path" -> "fixture.wl"|>|>|>], inputFile, "fixture"], <|"value" -> x|>];
record["artifact-no-overwrite", CanonMethodCard`WriteWLArtifact[<||>, outputDirectory, "fixture.wl"], $Failed];
record["relative-path-roundtrip", CanonMethodCard`ResolveInputPath[inputFile,
  CanonMethodCard`RelativeArtifactPath[inputFile, artifactFile]], artifactFile];
record["result-invalid-status", CanonMethodCard`WriteResult[task, outputDirectory, "OTHER", "CODE", <||>], $Failed];
record["result-empty-code", CanonMethodCard`WriteResult[task, outputDirectory, "PASS", "", <||>], $Failed];
record["provider-no-pass", CanonMethodCard`WriteProviderResult[task, outputDirectory, "PASS", "CODE", <||>], $Failed];
record["provider-provisional", StringQ[CanonMethodCard`WriteProviderResult[
  task, outputDirectory, "PROVISIONAL", "CANDIDATE_TRANSFORMATION", <||>]], True];
record["result-no-overwrite", CanonMethodCard`WriteResult[task, outputDirectory, "PASS", "CODE", <||>], $Failed];

snapshot = <|"version" -> $Version, "public_names" -> publicNames,
  "public_usage" -> publicUsage, "definition_hashes" -> definitionHashes,
  "records" -> records, "passed" -> And @@ Lookup[records, "pass"]|>;
Export[FileNameJoin[{outputDirectory, "snapshot.json"}], snapshot, "RawJSON"];
Print[InputForm[<|"case_count" -> Length[records], "failed" -> Lookup[Select[records, !TrueQ[#["pass"]] &], "name"]|>]];
Quit[If[TrueQ[snapshot["passed"]], 0, 1]];
