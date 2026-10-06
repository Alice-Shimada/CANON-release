#!/usr/bin/env wolframscript

$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
{packageEntry, finiteFlowEntry, kira, runRoot} =
  ExpandFileName /@ Rest[$ScriptCommandLine];
fixture = FileNameJoin[{repoRoot, "tests", "fixtures",
  "kira-one-loop-triangle-sector-5"}];
CreateDirectory[runRoot, CreateIntermediateDirectories -> True];
ClearAll[CANON`DEData`d, CANON`DEData`eps, CANON`DEData`s];
{dimension, regulator, variable} = {
  CANON`DEData`d, CANON`DEData`eps, CANON`DEData`s};
sector = <|"id" -> 5, "propagator_count" -> 2|>;

invoke[name_, step_, sectorValue_, payload_] := Module[
  {input, output, process, result},
  input = FileNameJoin[{runRoot, name <> ".json"}];
  output = FileNameJoin[{runRoot, name}];
  Export[input, <|"schema" -> "canon-neu/script-input/v1",
    "task_id" -> name, "step" -> step, "sector" -> sectorValue,
    "payload" -> payload|>, "RawJSON"];
  process = RunProcess[{"python3", FileNameJoin[{repoRoot, "run_step.py"}], input, output}, All,
    ProcessDirectory -> repoRoot];
  result = Import[FileNameJoin[{output, "result.json"}], "RawJSON"];
  <|"process" -> process, "result" -> result, "output" -> output|>
];
artifact[run_, name_] := <|"type" -> "mathematica-expression",
  "path" -> FileNameJoin[{run["output"],
    run["result", "artifacts", name, "path"]}]|>;
sha[path_] := FileHash[path, "SHA256", "HexString"];

spec = <|"schema" -> "canon-neu/family-spec/v1",
  "family_ref" -> "massless-one-loop-triangle-sector-5",
  "basis_ref" -> "kira3-triangle-sector-5-master-1", "topology" -> "tri",
  "parameters" -> {dimension, variable}, "variables" -> {variable},
  "regulator" -> regulator,
  "dimension_rule" -> dimension -> 2 - 2 regulator,
  "index_order" -> {"D1", "D2", "D3"},
  "sector_convention" ->
    "Sector = Sum[Boole[a_i > 0] 2^(i-1), {i,1,3}]",
  "kira" -> <|"project" -> fixture,
    "integral_families" -> "config/integralfamilies.yaml",
    "kinematics" -> "config/kinematics.yaml",
    "jobs" -> {"jobs.yaml", "export-math.yaml"}, "targets" -> "targets"|>,
  "family_data" -> FileNameJoin[{fixture, "family.wl"}],
  "prepared_derivatives" ->
    FileNameJoin[{fixture, "prepared-derivatives-v2.wl"}],
  "ordered_masters" -> FileNameJoin[{fixture, "preferred-masters"}],
  "propagator_slots" -> Range[3]|>;
specPath = FileNameJoin[{runRoot, "family-spec.wl"}];
Put[spec, specPath];

prepare = invoke["01-prepare", "PREPARE", Null,
  <|"family_spec" -> <|"type" -> "mathematica-expression",
    "path" -> specPath|>|>];
prepared = artifact[prepare, "prepared_family"];
propose = invoke["02-propose", "PROPOSE_INTEGRAL_CANDIDATES", sector,
  <|"family_identity" -> <|"family_id" -> spec["family_ref"],
      "family_spec_id" -> "triangle-sector-5-v1"|>,
    "sector_identity" -> <|"sector_id" -> "triangle-sector-5",
      "id" -> 5, "propagator_count" -> 2|>,
    "prepared_family" -> prepared,
    "dimension_policy" -> <|"spacetime_dimension" -> 2,
      "per_loop_policy" -> "physical-loop-keyed shared-epsilon target-2"|>,
    "numerator_or_power_counting_policy" -> <|
      "policy_id" -> "triangle-degree-1-one-dot",
      "definition" -> <|"numerator_degree" -> 1, "max_added_dots" -> 1,
        "max_dots_per_propagator" -> 1|>|>,
    "candidate_budget" -> <|"maximum" -> 2,
      "unit" -> "PROVIDER_CANDIDATE"|>,
    "candidate_unit" -> "NORMALIZED_LINEAR_COMBINATION",
    "normalization_policy" -> <|
      "convention" -> "first-integral-coefficient-outside-definition",
      "factors" -> <|"placement" -> "normalization.factor"|>|>,
    "method_options" -> <|
      "package_entry" -> packageEntry,
      "finite_flow_package_file" -> finiteFlowEntry,
      "loop_order" -> {1},
      "loop_dimensions" -> {2}
    |>|>];
candidates = artifact[propose, "integral_candidates"];
discover = invoke["03-discover", "DISCOVER", Null,
  <|"prepared_family" -> prepared|>];
manifest = artifact[discover, "sector_manifest"];
masters = artifact[discover, "master_basis"];

reductionRequest = <|"executable" -> kira, "project" -> fixture,
  "jobs" -> {"jobs.yaml", "export-math.yaml"}, "topology" -> "tri",
  "targets" -> "targets", "output" -> FileNameJoin[{runRoot, "04-kira"}],
  "options" -> {"--parallel=1"}|>;
reduction = invoke["04-reduce-candidates", "REDUCE_CANDIDATE_IBP", sector,
  <|"integral_candidates" -> candidates, "prepared_family" -> prepared,
    "master_basis" -> masters, "prepared_derivatives" -> <|
      "type" -> "mathematica-expression", "path" -> spec["prepared_derivatives"]|>,
    "reduction" -> reductionRequest|>];
reductionProcess = reduction["process"];
bridge = artifact[reduction, "candidate_ibp_bridge"];
bridgePath = bridge["path"];

cut = invoke["05-build-cut", "BUILD_CUT_DE",
  sector, <|"prepared_family" -> prepared, "master_basis" -> masters,
    "sector_manifest" -> manifest, "ibp_reduction" -> bridge|>];
sectorBasis = artifact[cut, "sector_basis"];
sectorCutDE = artifact[cut, "sector_cut_de"];
orderedDE = artifact[cut, "ordered_master_de"];
route = invoke["06-route", "ROUTE_CORE_CANDIDATES", sector,
  <|"prepared_family" -> prepared, "sector_basis" -> sectorBasis,
    "sector_cut_de" -> sectorCutDE, "candidate_ibp_bridge" -> bridge|>];
coreCandidates = artifact[route, "core_candidates"];
core = invoke["07-check-core", "CHECK_CORE", sector,
  <|"sector_basis" -> sectorBasis, "sector_cut_de" -> sectorCutDE,
    "core_candidates" -> coreCandidates|>];
coreTransform = artifact[core, "core_transform"];

alphabetPath = FileNameJoin[{runRoot, "declared-alphabet.wl"}];
Put[<|"schema" -> "canon-neu/declared-alphabet/v1",
  "letters" -> {variable}|>, alphabetPath];
alphabet = <|"type" -> "mathematica-expression", "path" -> alphabetPath|>;
full = invoke["08-build-full", "BUILD_FULL_DE",
  sector, <|"ordered_master_de" -> orderedDE,
    "sector_cut_de" -> sectorCutDE, "core_candidates" -> coreCandidates,
    "core_transform" -> coreTransform, "declared_alphabet" -> alphabet,
    "accepted_prefix" -> Null|>];
fullDE = artifact[full, "full_sector_de"];
tail = invoke["09-solve-tail", "SOLVE_TAIL", sector,
  <|"sector_basis" -> sectorBasis, "sector_cut_de" -> sectorCutDE,
    "core_candidates" -> coreCandidates, "full_sector_de" -> fullDE,
    "core_transform" -> coreTransform, "accepted_prefix" -> Null,
    "tail_options" -> <|"candidate_budget" -> 2|>|>];
sectorTransform = artifact[tail, "sector_transform"];
canonical = invoke["10-check-canonical", "CHECK_CANONICAL", sector, <|"full_sector_de" -> fullDE,
    "sector_transform" -> sectorTransform, "accepted_prefix" -> Null|>];
canonicalSector = artifact[canonical, "canonical_sector_de"];
commit = invoke["11-commit", "COMMIT_SECTOR", sector,
  <|"previous_accepted_prefix" -> Null, "sector_basis" -> sectorBasis,
    "sector_transform" -> sectorTransform,
    "canonical_sector_de" -> canonicalSector|>];
accepted = artifact[commit, "accepted_prefix"];
next = invoke["12-next", "NEXT_SECTOR", Null,
  <|"sector_manifest" -> manifest, "accepted_prefix" -> accepted|>];
cursor = artifact[next, "sector_cursor"];
final = invoke["13-final", "FINAL_CHECK", Null,
  <|"prepared_family" -> prepared, "master_basis" -> masters,
    "sector_manifest" -> manifest, "ordered_master_de" -> orderedDE,
    "accepted_prefix" -> accepted|>];
canonicalBasis = artifact[final, "canonical_basis"];
canonicalDE = artifact[final, "canonical_de"];

stageRuns = {prepare, propose, discover, reduction, cut, route, core, full, tail,
  canonical, commit, next, final};
stageNames = {"PREPARE", "PROPOSE_INTEGRAL_CANDIDATES", "DISCOVER",
  "REDUCE_CANDIDATE_IBP", "BUILD_CUT_DE", "ROUTE_CORE_CANDIDATES", "CHECK_CORE", "BUILD_FULL_DE",
  "SOLVE_TAIL", "CHECK_CANONICAL", "COMMIT_SECTOR", "NEXT_SECTOR",
  "FINAL_CHECK"};
stageOutcomes = AssociationThread[stageNames,
  Lookup[#1["result"], {"status", "code"}] & /@ stageRuns];
Get[packageEntry];
candidateValue = Get[candidates["path"]];
familyData = Get[spec["family_data"]];
packageCandidates = Take[
  candidateValue["method_evidence", "evidence"][[
    1, "output", "CandidateCombinations"]],
  UpTo[Length[candidateValue["candidates"]]]
] /. HoldPattern[DlogBasis`DlogIntegral[_, indices_List]] :>
    Apply[CANON`DEData`j, Prepend[indices, CANON`DEData`tri]] /.
  Thread[familyData["Family", "KinematicVariables"] -> spec["variables"]] /.
  DlogBasis`DimensionalRegulator -> regulator;
bridgeValue = Get[bridgePath];
acceptedValue = Get[accepted["path"]];
cursorValue = Get[cursor["path"]];
canonicalDEValue = Get[canonicalDE["path"]];
head = Head[First[bridgeValue["masters"]]];
rhsIntegrals = DeleteDuplicates@Cases[Last /@ bridgeValue["rules"],
  item_ /; Head[Unevaluated[item]] === head :> item, {0, Infinity}];
checks = <|
  "stage_outcomes" -> (stageOutcomes === AssociationThread[stageNames, {
    {"PASS", "OK"}, {"PROVISIONAL", "INTEGRAL_CANDIDATES"},
    {"PASS", "SECTORS_READY"}, {"PASS", "CANDIDATES_REDUCED"}, {"PASS", "OK"},
    {"PROVISIONAL", "CORE_CANDIDATES_ROUTED"}, {"PASS", "CORE_PASS"},
    {"PASS", "OK"}, {"PASS", "TAIL_READY"},
    {"PASS", "CANONICAL_PASS"}, {"PASS", "OK"}, {"PASS", "OK"},
    {"PASS", "ALL_PASS"}}]),
  "candidate_reduction_process" -> (reductionProcess["ExitCode"] === 0),
  "projective_candidate_reconstruction" -> And @@ MapThread[
    Together[#1["normalization", "factor"] ReleaseHold[#1["exact_definition"]] -
      #2] === 0 &, {candidateValue["candidates"], packageCandidates}],
  "enhanced_baikov_candidate_derivative" ->
    (bridgeValue["operators", variable, "kind"] === "enhanced-baikov"),
  "ordered_master" -> (bridgeValue["masters"] === {head[1, 0, 1]}),
  "complete_rule_coverage" ->
    ContainsExactly[First /@ bridgeValue["rules"],
      Lookup[bridgeValue["reducer_targets"], "integral"]],
  "master_only_rule_rhs" -> SubsetQ[bridgeValue["masters"], rhsIntegrals],
  "sector_cursor_complete" -> TrueQ[cursorValue["complete"]],
  "prefix_hash" -> (acceptedValue["prefix_id"] === "sha256:" <>
    Hash[KeyDrop[acceptedValue, "prefix_id"], "SHA256", "HexString"]),
  "rational_cumulative_transformation" ->
    (acceptedValue["transformation"] ===
      {{2/((1 + 2 regulator) variable)}}),
  "exact_canonical_matrix" ->
    (canonicalDEValue["matrices"] === {{{-regulator/variable}}}),
  "final_checks" -> And @@ Values[canonicalDEValue["checks"]]
|>;

fixtureFiles = {"config/integralfamilies.yaml", "config/kinematics.yaml",
  "jobs.yaml", "export-math.yaml", "preferred-masters", "targets",
  "family.wl", "prepared-derivatives-v2.wl", "sector-manifest.wl"};
implementationFiles = {"run_step.py", "components/default.json", "mma/ReduceIBP.wls",
  "mma/PrepareFamily.wls", "methods/dlogbasis/run.wls",
  "mma/ReduceCandidateIBP.wls", "mma/BuildSectorCutDE.wls",
  "mma/RouteCoreCandidates.wls", "mma/CheckSectorCore.wls",
  "mma/BuildFullSectorDE.wls", "mma/SolveTail.wls",
  "mma/CheckCanonical.wls", "mma/CommitSector.wls", "mma/NextSector.wls",
  "mma/CheckFullSystem.wls", "mma/lib/BaikovDerivative.wl",
  "mma/lib/CandidateIBPBridge.wl", "mma/lib/DEBuilder.wl",
  "mma/lib/MethodCardCore.wl"};
packageRoot = DirectoryName[packageEntry];
packageFiles = {"DlogBasis.wl", "Kernel/DlogBasis.wl",
  "Kernel/FamilyAndCandidates.wl", "Kernel/LBLBaikov.wl",
  "Kernel/ResidueSignature.wl", "Kernel/SingularModule.wl",
  "Kernel/ImplicitAlgebraicResidue.wl", "Kernel/Interface.wl"};
receipt = <|
  "schema" -> "canon-neu/end-to-end-receipt/v1",
  "scope" -> "fresh-live-kira-one-loop-single-sector-single-variable",
  "claim_boundary" -> <|"canonical_form" -> "exact",
    "dlog_candidate" -> "bounded-maximal-cut",
    "projective_ansatz" -> "no-constant-ls-or-ut-inheritance",
    "uniform_transcendentality" -> "not-proved"|>,
  "runtime" -> <|"wolfram" -> $Version <> "; " <> $SystemID,
    "kira" -> <|"path" -> kira, "sha256" -> sha[kira],
      "version" -> StringTrim[RunProcess[{kira, "--version"}, "StandardOutput"]]|>,
    "dlogbasis_refine" -> AssociationThread[packageFiles,
      sha[FileNameJoin[{packageRoot, #}]] & /@ packageFiles]|>,
  "input_sha256" -> AssociationThread[fixtureFiles,
    sha[FileNameJoin[{fixture, #}]] & /@ fixtureFiles],
  "implementation_sha256" -> AssociationThread[implementationFiles,
    sha[FileNameJoin[{repoRoot, #}]] & /@ implementationFiles],
  "stage_outcomes" -> stageOutcomes,
  "sector_receipts" -> {<|"sector" -> sector,
    "candidate_id" -> acceptedValue["candidate_trace"][[1, "candidate_id"]],
    "operator_kind" -> bridgeValue["operators", variable, "kind"],
    "prefix_id" -> acceptedValue["prefix_id"]|>},
  "reduction" -> <|"master_count" -> Length[bridgeValue["masters"]],
    "target_count" -> Length[bridgeValue["reducer_targets"]],
    "rule_count" -> Length[bridgeValue["rules"]]|>,
  "checks" -> checks, "all_pass" -> And @@ Values[checks],
  "output_sha256" -> <|"candidate_ibp_bridge" -> sha[bridgePath],
    "accepted_prefix" -> sha[accepted["path"]],
    "canonical_basis" -> sha[canonicalBasis["path"]],
    "canonical_de" -> sha[canonicalDE["path"]]|>
|>;
receiptPath = FileNameJoin[{runRoot, "end-to-end-receipt.wl"}];
Put[receipt, receiptPath];
Print[InputForm[<|"passed" -> Count[Values[checks], True],
  "total" -> Length[checks], "all_pass" -> receipt["all_pass"],
  "receipt" -> receiptPath|>]];
Exit[If[receipt["all_pass"], 0, 1]];
