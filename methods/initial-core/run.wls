$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "InitialInterface.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "InitialRuntime.wl"}]];
Get[FileNameJoin[{repoRoot, "methods", "initial-core", "SeedSystem.wl"}]];
args = CanonMethodCard`ScriptArguments[];
If[Length[args] =!= 2, Print["Usage: run.wls <input.json> <new-output-dir>"]; Quit[2]];
{inputPath, outputDir} = ExpandFileName /@ args;
task = CanonMethodCard`ReadTask[inputPath, "SEARCH_CORE"];
If[FailureQ[task], Print[InputForm[task]]; Quit[2]];
payload = task["payload"];
options = Lookup[payload, "method_options", <||>];
methodID = "initial-seeded-core";
stage = "configuration";
diagnostics = <|"degree" -> <|"status" -> "not_run"|>,
  "reconstruction" -> <|"status" -> "not_run"|>|>;
provenance = <||>;
componentEvidence = <||>;
attemptCount = 0;

(* Resolve physical existing ancestors before allowing any output writer. *)
insideQ[path_String, root_String] := path === root || StringStartsQ[path,
  If[StringEndsQ[root, $PathnameSeparator], root, root <> $PathnameSeparator]];
realPath[path_String] := Lookup[Quiet @ Check[Association[FileInformation[path]], <||>],
  "AbsoluteFileName", $Failed];
resolvedLocation[path_String] := Module[{ancestor = path, suffix = {}, parent, resolved},
  While[!FileExistsQ[ancestor], parent = DirectoryName[ancestor];
    If[parent === ancestor, Return[$Failed]];
    PrependTo[suffix, FileNameTake[ancestor]]; ancestor = parent];
  resolved = realPath[ancestor];
  If[StringQ[resolved], FileNameJoin[Prepend[suffix, resolved]], $Failed]];
componentKeys = {"package_entry", "finite_flow_package_file", "finite_flow_library"};
componentPaths = If[AssociationQ[options],
  CanonMethodCard`ResolveInputPath[inputPath, #] & /@
    Select[Lookup[options, componentKeys, None], StringQ[#] && # =!= "" &], {}];
inputPaths = CanonMethodCard`ResolveInputPath[inputPath, #] & /@
  Select[Lookup[Select[Values[payload], AssociationQ], "path", None], StringQ];
protectedRoots = DeleteDuplicates @ Join[
  Select[resolvedLocation /@ (DirectoryName /@ Join[componentPaths, inputPaths]), StringQ],
  DirectoryName /@ Select[realPath /@ Select[Join[componentPaths, inputPaths],
    FileType[#] === File &], StringQ]];
outputParent = realPath[DirectoryName[outputDir]];
outputLocation = If[StringQ[outputParent],
  FileNameJoin[{outputParent, FileNameTake[outputDir]}], $Failed];
If[FileExistsQ[outputDir] || FileType[DirectoryName[outputDir]] =!= Directory || !StringQ[outputParent] ||
    AnyTrue[protectedRoots, insideQ[outputLocation, #] &],
  Print["INITIAL core requires a new output outside component and referenced-input directories with an existing parent"];
  Quit[2]];

finish[status_String, code_String, reason_String, details_: <||>] := (
  CanonMethodCard`WriteProviderResult[task, outputDir, status, code, <||>,
    Join[<|"method_id" -> methodID, "stage" -> stage, "reason" -> reason,
      "interface" -> CanonInitialInterface`CoreContract[],
      "diagnostics" -> diagnostics, "provenance" -> provenance,
      "components" -> componentEvidence, "declared_options" -> options,
      "ut_conclusion" -> "none", "attempts" -> attemptCount|>, details]];
  Quit[If[status === "ERROR", 1, 0]]);
nonempty[value_] := StringQ[value] && StringLength[value] > 0;
nonSystemSymbolQ[value_] := MatchQ[value, _Symbol] && Context[value] =!= "System`";
hashQ[value_] := StringQ[value] && StringMatchQ[value, RegularExpression["[0-9a-fA-F]{64}"]];
bindQ[value_, cut_] := AssociationQ[value] && And @@
  (Lookup[value, #, None] === Lookup[cut, #, Missing[#]] & /@
    {"sector", "family_id", "basis_id", "basis", "variables", "regulator"});
load[name_String] := Module[{descriptor, path, hash, value},
  descriptor = Lookup[payload, name, None];
  If[!AssociationQ[descriptor] || !nonempty[Lookup[descriptor, "path", None]],
    finish["ERROR", "INVALID_INPUT", name <> " must reference a WL artifact"]];
  path = CanonMethodCard`ResolveInputPath[inputPath, descriptor["path"]];
  If[FileType[path] =!= File, finish["ERROR", "MISSING_ARTIFACT", name <> " is missing"]];
  hash = FileHash[path, "SHA256", "HexString"];
  If[KeyExistsQ[descriptor, "sha256"] &&
      (!hashQ[descriptor["sha256"]] || ToLowerCase[descriptor["sha256"]] =!= hash),
    finish["ERROR", "INPUT_HASH_MISMATCH", name <> " SHA-256 differs"]];
  provenance[name] = <|"path" -> path, "sha256" -> hash|>;
  value = Quiet @ Check[Get[path], $Failed];
  If[!AssociationQ[value], finish["ERROR", "INVALID_INPUT", name <> " must contain an Association"]];
  value];
validateEvidence[evidence_, declaringPath_String] := Module[{source, path, hash, evidenceRoots},
  (* Protect a declared evidence source before an invalid evidence outcome can
     create result.json, including aliases of its parent or source file. *)
  source = If[AssociationQ[evidence], Lookup[evidence, "source", None], None];
  If[AssociationQ[source] && nonempty[Lookup[source, "path", None]],
    path = CanonMethodCard`ResolveInputPath[declaringPath, source["path"]];
    evidenceRoots = Select[{resolvedLocation[DirectoryName[path]],
      If[FileType[path] === File, DirectoryName[realPath[path]], None]}, StringQ];
    If[AnyTrue[evidenceRoots, insideQ[outputLocation, #] &],
      Print["INITIAL core output cannot be inside normalization-evidence source directory"]; Quit[2]]];
  If[!AssociationQ[evidence] || Lookup[evidence, "status", None] =!= "established" ||
      !MemberQ[{"official-reference", "integrand-dlog-leading-singularities",
        "independent-initial-picard-fuchs", "weight-graded-boundary-lower-sector"},
        Lookup[evidence, "kind", None]] || !nonempty[Lookup[evidence, "statement", None]],
    finish["ERROR", "INVALID_SEED_EVIDENCE", "Every seed needs established, sourced normalization evidence of an applicable kind"]];
  If[!AssociationQ[source] || !nonempty[Lookup[source, "path", None]] || !hashQ[Lookup[source, "sha256", None]],
    finish["ERROR", "INVALID_SEED_EVIDENCE", "Normalization evidence needs a file path and SHA-256"]];
  path = CanonMethodCard`ResolveInputPath[declaringPath, source["path"]];
  If[FileType[path] =!= File ||
      (hash = FileHash[path, "SHA256", "HexString"]) =!= ToLowerCase[source["sha256"]],
    finish["ERROR", "INPUT_HASH_MISMATCH", "Normalization evidence source is missing or changed"]];
  Join[evidence, <|"source" -> <|"path" -> path, "sha256" -> hash|>|>]];

If[!AssociationQ[options], finish["ERROR", "TOOL_CONFIGURATION", "method_options must be an object"]];
allowedOptions = Join[componentKeys, {"initial_identity", "finiteflow_identity", "threads",
  "timeout_seconds", "max_iterations", "max_degree", "max_primes"}];
If[Complement[Keys[options], allowedOptions] =!= {},
  finish["ERROR", "INVALID_OPTIONS", "Unknown method_options", <|"unknown_options" -> Complement[Keys[options], allowedOptions]|>]];
If[!And @@ (nonempty[Lookup[options, #, None]] & /@
    Join[componentKeys, {"initial_identity", "finiteflow_identity"}]) ||
    !And @@ (IntegerQ[Lookup[options, #, None]] && options[#] > 0 & /@
      {"threads", "timeout_seconds", "max_iterations", "max_degree", "max_primes"}),
  finish["ERROR", "TOOL_CONFIGURATION", "Declare component paths, identities, positive threads and every finite budget"]];
If[!MemberQ[$CommandLine, "-noinit"] || !MemberQ[$CommandLine, "-script"],
  finish["ERROR", "TOOL_CONFIGURATION", "Use WolframKernel with -noinit -script"]];
{initialEntry, ffEntry, ffLibrary} = CanonMethodCard`ResolveInputPath[inputPath, options[#]] & /@ componentKeys;
If[!AllTrue[{initialEntry, ffEntry, ffLibrary}, FileType[#] === File &],
  finish["ERROR", "TOOL_COMPONENT_MISSING", "A declared INITIAL or FiniteFlow component is missing"]];
componentEvidence = AssociationThread[componentKeys,
  (<|"path" -> #, "sha256" -> FileHash[#, "SHA256", "HexString"]|> & /@ {initialEntry, ffEntry, ffLibrary})];
diagnostics["degree"] = <|"status" -> "bounded_by_package_options",
  "max_degree" -> options["max_degree"], "max_iterations" -> options["max_iterations"]|>;
diagnostics["reconstruction"] = <|"status" -> "not_run", "max_primes" -> options["max_primes"]|>;

stage = "seed_input";
sectorBasis = load["sector_basis"];
cut = load["sector_cut_de"];
If[!CanonMethodCard`ValidSectorBasisQ[sectorBasis] || !CanonMethodCard`ValidCutDEQ[cut] ||
    !And @@ (Lookup[sectorBasis, #, None] === Lookup[cut, #, None] & /@
      {"sector", "family_id", "basis_id", "basis"}) || cut["sector"] =!= Lookup[task, "sector", None] ||
    cut["basis"] === {} || !DuplicateFreeQ[cut["basis"]] ||
    !And @@ (nonSystemSymbolQ /@ cut["variables"]) || !nonSystemSymbolQ[cut["regulator"]] ||
    !DuplicateFreeQ[cut["variables"]] || MemberQ[cut["variables"], cut["regulator"]],
  finish["ERROR", "INVALID_DIFFERENTIAL_SYSTEM", "Cut and resident basis identity, order, or exact rational DE is invalid"]];
If[Length[cut["variables"]] =!= 1,
  finish["INCONCLUSIVE", "OUT_OF_SCOPE", "INITIAL core supports one rational differential variable"]];
x = First[cut["variables"]]; regulator = cut["regulator"]; a = First[cut["matrices"]];
n = Length[cut["basis"]];
request = load["seed_request"];
If[Lookup[request, "schema", None] =!= "canon-neu/initial-seed-request/v1" || !bindQ[request, cut],
  finish["ERROR", "INVALID_INPUT", "seed_request must bind the exact ordered cut identity"]];
ids = Lookup[request, "seed_ids", None]; counts = Lookup[request, "derivative_counts", None];
If[!ListQ[ids] || ids === {} || Length[ids] > n || !And @@ (nonempty /@ ids) || !DuplicateFreeQ[ids] ||
    !ListQ[counts] || Length[counts] =!= Length[ids] ||
    !And @@ (IntegerQ[#] && # > 0 & /@ counts) || Total[counts] =!= n,
  finish["ERROR", "INVALID_INPUT", "Declare unique seed IDs and positive derivative_counts totaling the cut dimension"]];
haveRows = KeyExistsQ[payload, "seed_rows"]; haveBridge = KeyExistsQ[payload, "candidate_ibp_bridge"];
If[haveRows === haveBridge || (haveRows && KeyExistsQ[payload, "prepared_family"]) ||
    (haveBridge && !KeyExistsQ[payload, "prepared_family"]),
  finish["ERROR", "INVALID_INPUT", "Use seed_rows or candidate_ibp_bridge with prepared_family, exclusively"]];
If[haveRows,
  seedInput = load["seed_rows"];
  If[Lookup[seedInput, "schema", None] =!= "canon-neu/initial-seed-rows/v1" || !bindQ[seedInput, cut] ||
      !ListQ[Lookup[seedInput, "seeds", None]] || !And @@ (AssociationQ /@ seedInput["seeds"]),
    finish["ERROR", "INVALID_INPUT", "seed_rows must bind the cut identity and declare seeds"]];
  availableIDs = Lookup[seedInput["seeds"], "id", None];
  If[!And @@ (nonempty /@ availableIDs) || !DuplicateFreeQ[availableIDs] || !And @@ (MemberQ[availableIDs, #] & /@ ids),
    finish["ERROR", "INVALID_INPUT", "Selected seed IDs must occur uniquely in seed_rows"]];
  selected = (seedInput["seeds"][[First @ FirstPosition[availableIDs, #]]]) & /@ ids;
  rows = Lookup[selected, "full_new_basis_row", None];
  source = Lookup[seedInput, "source_basis", None];
  evidence = validateEvidence[Lookup[#, "normalization_evidence", None], provenance["seed_rows", "path"]] & /@ selected,
  bridge = load["candidate_ibp_bridge"]; family = load["prepared_family"];
  If[Lookup[family, "schema", None] =!= "canon-neu/prepared-family/v1" ||
      Lookup[family, "family_ref", None] =!= cut["family_id"] ||
      Lookup[family, "variables", None] =!= cut["variables"] ||
      Lookup[family, "regulator", None] =!= regulator ||
      Lookup[bridge, "variables", None] =!= cut["variables"] ||
      Lookup[bridge, "family_ref", None] =!= Lookup[family, "family_ref", Missing["family_ref"]] ||
      !nonempty[Lookup[family, "basis_ref", None]] ||
      Lookup[bridge, "basis_ref", None] =!= family["basis_ref"],
    finish["ERROR", "INVALID_INPUT", "Bridge and prepared_family must bind family, variables, regulator, and family_ref"]];
  bridgeRows = CanonInitialCore`BridgeRows[bridge, family, ids];
  If[FailureQ[bridgeRows], finish["ERROR", "INVALID_INPUT", bridgeRows[[2, "reason"]], bridgeRows[[2]]]];
  source = bridgeRows["source_basis"]; rows = bridgeRows["rows"];
  evidenceByID = Lookup[request, "normalization_evidence", None];
  If[!AssociationQ[evidenceByID] || !And @@ (KeyExistsQ[evidenceByID, #] & /@ ids),
    finish["ERROR", "INVALID_SEED_EVIDENCE", "Bridge seeds need explicit normalization_evidence keyed by selected seed ID"]];
  evidence = validateEvidence[evidenceByID[#], provenance["seed_request", "path"]] & /@ ids];
If[!ListQ[source] || source === {} || !DuplicateFreeQ[source] ||
    !And @@ (MemberQ[source, #] & /@ cut["basis"]) || !MatrixQ[rows] ||
    Dimensions[rows] =!= {Length[ids], Length[source]} ||
    !And @@ (CanonMethodCard`ExactRationalExpressionQ /@ Flatten[rows]) ||
    !FreeQ[rows, Alternatives @@ source],
  finish["ERROR", "INVALID_INPUT", "Full normalized seed rows need exact coefficients and a unique source_basis containing every current master"]];
If[KeyExistsQ[payload, "declared_alphabet"] && KeyExistsQ[request, "letters"],
  finish["ERROR", "INVALID_INPUT", "Declare the alphabet artifact or seed_request.letters, exclusively"]];
If[KeyExistsQ[payload, "declared_alphabet"],
  alphabetInput = load["declared_alphabet"]; letters = Lookup[alphabetInput, "letters", None],
  letters = Lookup[request, "letters", None]];
If[!ListQ[letters] || letters === {} || !DuplicateFreeQ[letters] ||
    !And @@ (CanonMethodCard`ExactRationalExpressionQ[#] && FreeQ[#, regulator] &&
      !TrueQ[Together[#] === 0] && !TrueQ[Together[D[#, x]] === 0] & /@ letters),
  finish["ERROR", "INVALID_INPUT", "Declare distinct nonconstant regulator-free exact rational letters"]];
ansatz = Together[D[#, x]/#] & /@ letters;

stage = "seed_prepare";
startTime = AbsoluteTime[];
remaining[] := Max[0, options["timeout_seconds"] - (AbsoluteTime[] - startTime)];
SetAttributes[bounded, HoldAll];
bounded[expr_] := If[remaining[] <= 0, $Aborted,
  CheckAbort[TimeConstrained[expr, remaining[], $Aborted], $Aborted]];
prepared = bounded[CanonInitialCore`PrepareSeedSystem[a, x, rows, source, cut["basis"], counts]];
If[prepared === $Aborted, finish["INCONCLUSIVE", "METHOD_EXHAUSTED", "Seed preparation exhausted timeout budget"]];
If[FailureQ[prepared], finish["INCONCLUSIVE", "METHOD_EXHAUSTED", prepared[[2, "reason"]], prepared[[2]]]];
diagnostics = Join[diagnostics, <|"psi_rank" -> prepared["psi_rank"], "required_rank" -> n,
  "psi_rank_witness" -> ToString[prepared["psi_rank_witness"], InputForm],
  "seed_projection_rank" -> prepared["seed_projection_rank"], "derivative_counts" -> counts|>];

stage = "tool_load";
$LibraryPath = Prepend[DeleteCases[$LibraryPath, DirectoryName[ffLibrary]], DirectoryName[ffLibrary]];
If[Quiet @ Check[Get[ffEntry]; True, False] =!= True,
  finish["ERROR", "TOOL_LOAD_FAILED", "FiniteFlow failed to load"]];
If[realPath[FiniteFlow`Private`fflowlib] =!= realPath[ffLibrary],
  finish["ERROR", "TOOL_COMPONENT_MISMATCH", "FiniteFlow loaded an unexpected native library"]];
initialRuntime = Quiet @ Check[CanonInitialRuntime`LoadInitial[initialEntry], $Failed];
If[!AssociationQ[initialRuntime] ||
    !And @@ (NameQ /@ {"INITIAL`TCalc", "INITIAL`basisChange", "INITIAL`FFInvMatMul"}),
  finish["ERROR", "TOOL_LOAD_FAILED", "INITIAL failed to load its required public functions"]];
diagnostics["initial_runtime"] = initialRuntime;
If[Quiet @ Check[CreateDirectory[outputDir]; SetDirectory[outputDir]; True, False] =!= True,
  finish["ERROR", "OUTPUT_ERROR", "Cannot create the output working directory"]];
FiniteFlow`FFNThreads = options["threads"];
stage = "tcalc";
attemptCount = 1;
Print["INITIAL_CORE_STAGE=", stage];
packageMessages = {};
packageMessageNames = {};
printDiagnostic[items___] := Module[{line = StringJoin[ToString[#, InputForm] & /@ {items}]},
  If[Length[packageMessages] < 80, AppendTo[packageMessages, line]];
  Which[
    StringContainsQ[line, "Calculating psi"], stage = "tcalc_psi",
    StringContainsQ[line, "Calculating degrees"], stage = "tcalc_degree",
    StringContainsQ[line, "Calculating solution"], stage = "tcalc_solution",
    StringContainsQ[line, "Calculating full phi"], stage = "tcalc_phi",
    StringContainsQ[line, "Calculating T-matrix"], stage = "tcalc_reconstruction"];
  Null];
(* One attempt. TakeRow selects intermediate row numbers, never coefficient rows. *)
tInitial = bounded[Block[{Print = printDiagnostic, $MessageList = {}},
  tReturn = Quiet[INITIAL`TCalc[prepared["A_seed"], ansatz, x, regulator,
  "TakeRow" -> prepared["take_row"], "Silent" -> False, "NThreads" -> options["threads"],
  "MaxIterations" -> options["max_iterations"], "MaxDegree" -> options["max_degree"],
  "MaxPrimes" -> options["max_primes"]]];
  packageMessageNames = ToString[#, InputForm] & /@ $MessageList;
  tReturn]];
diagnostics["package_messages"] = packageMessages;
diagnostics["package_message_names"] = packageMessageNames;
If[AnyTrue[packageMessages, StringContainsQ[#, "Degree check failed" | "not vanishing"] &],
  diagnostics["degree"] = Join[diagnostics["degree"], <|"status" -> "package_degree_or_normalization_rejection"|>]];
If[tInitial === $Aborted, finish["INCONCLUSIVE", "METHOD_EXHAUSTED", "INITIAL exhausted timeout budget"]];
If[tInitial === $Failed || !MatrixQ[tInitial] || Dimensions[tInitial] =!= {n, n},
  diagnostics["reconstruction"] = <|"status" -> "no_full_transformation", "max_primes" -> options["max_primes"]|>;
  finish["INCONCLUSIVE", "METHOD_EXHAUSTED", "INITIAL did not reconstruct a full transformation; this is not a non-UT conclusion"]];
diagnostics["reconstruction"] = <|"status" -> "full_transformation_returned", "max_primes" -> options["max_primes"]|>;
stage = "full_row_reconstruction";
fullRows = bounded[Quiet[INITIAL`FFInvMatMul[tInitial, prepared["R_full"],
  "InvertInput" -> 1, "NThreads" -> options["threads"],
  "MaxDegree" -> options["max_degree"], "MaxPrimes" -> options["max_primes"]]]];
If[fullRows === $Aborted, finish["INCONCLUSIVE", "METHOD_EXHAUSTED", "Full-row reconstruction exhausted timeout budget"]];
If[!MatrixQ[fullRows], finish["INCONCLUSIVE", "METHOD_EXHAUSTED", "Full-row reconstruction returned no matrix"]];
stage = "compose";
composed = bounded[CanonInitialCore`ComposeCandidate[prepared, tInitial, fullRows]];
If[composed === $Aborted, finish["INCONCLUSIVE", "METHOD_EXHAUSTED", "Composition exhausted timeout budget"]];
If[FailureQ[composed], finish["INCONCLUSIVE", "METHOD_EXHAUSTED", composed[[2, "reason"]], composed[[2]]]];
diagnostics["full_row_reconstruction"] = <|"status" -> "exact_inverse_and_full_row_identities_checked"|>;
stage = "basis_change";
b = bounded[Quiet[INITIAL`basisChange[prepared["A_seed"], tInitial, x,
  "NThreads" -> options["threads"], "MaxDegree" -> options["max_degree"],
  "MaxPrimes" -> options["max_primes"]]]];
If[b === $Aborted, finish["INCONCLUSIVE", "METHOD_EXHAUSTED", "basisChange exhausted timeout budget"]];
If[b === $Failed || !MatrixQ[b] || Dimensions[b] =!= {n, n} ||
    !And @@ (CanonMethodCard`ExactRationalExpressionQ /@ Flatten[b]),
  finish["ERROR", "TOOL_COMPUTATION_FAILED", "INITIAL basisChange returned no exact full matrix"]];
stage = "provider_precheck";
prechecks = bounded[<|
  "source_gauge" -> CanonMethodCard`ZeroMatrixQ[a.composed["transformation"] -
    D[composed["transformation"], x] - composed["transformation"].b],
  "seed_gauge" -> CanonMethodCard`ZeroMatrixQ[prepared["A_seed"].tInitial - D[tInitial, x] - tInitial.b],
  "epsilon_factorized" -> CanonMethodCard`EpsilonFactorizedQ[{b}, regulator],
  "declared_dlog" -> CanonMethodCard`DLogConnectionQ[{b}, {x}, regulator, letters]|>];
If[prechecks === $Aborted, finish["INCONCLUSIVE", "METHOD_EXHAUSTED", "Exact provider precheck exhausted timeout budget"]];
If[!And @@ (TrueQ /@ Values[prechecks]),
  finish["INCONCLUSIVE", "METHOD_EXHAUSTED", "Exact source gauge, epsilon, or declared dlog precheck failed",
    <|"provider_prechecks" -> prechecks|>]];
method = <|"id" -> methodID, "tool" -> "INITIAL",
  "initial_runtime" -> initialRuntime,
  "interface" -> CanonInitialInterface`CoreContract[], "initial_identity" -> options["initial_identity"],
  "finiteflow_identity" -> options["finiteflow_identity"], "components" -> componentEvidence,
  "package_source" -> "method_options.package_entry", "options" -> options,
  "inputs" -> provenance, "seed_ids" -> ids, "normalization_evidence" -> evidence,
  "source_basis" -> source, "source_seed_rows" -> rows, "take_row" -> prepared["take_row"],
  "source_basis_sha256" -> Hash[source, "SHA256", "HexString"],
  "source_seed_rows_sha256" -> Hash[rows, "SHA256", "HexString"],
  "letters" -> letters, "diagnostics" -> diagnostics, "elapsed_seconds" -> AbsoluteTime[] - startTime,
  "wolfram_version" -> $Version, "system_id" -> $SystemID|>;
candidate = Join[<|"candidate_id" -> methodID <> ":" <> StringTake[Hash[{source, rows, ids, letters}, "SHA256", "HexString"], 16], "member_candidate_ids" -> ids,
  "construction_rejection" -> None, "transformed_matrices" -> {b},
  "provider_evidence" -> Join[prechecks, <|"normalization_evidence" -> evidence,
    "verification_status" -> "AWAITING_INDEPENDENT_CHECK_CORE"|>]|>, composed];
artifact = <|"schema" -> "canon-neu/core-candidates/v1", "sector" -> cut["sector"],
  "family_id" -> cut["family_id"], "basis_id" -> cut["basis_id"],
  "coefficient_domain" -> "exact-rational-functions", "basis" -> cut["basis"], "source_basis" -> source,
  "variables" -> {x}, "regulator" -> regulator, "convention" -> "old_basis = transformation . new_basis",
  "method" -> method, "candidate_group_pool" -> <|"declared" -> 1, "eligible" -> 1,
    "remaining" -> 0, "unconsumed_candidates" -> 0, "pool_exhausted" -> True|>, "candidates" -> {candidate}|>;
artifactPath = CanonMethodCard`WriteWLArtifact[artifact, outputDir, "core-candidates.wl"];
If[artifactPath === $Failed, finish["ERROR", "OUTPUT_ERROR", "Cannot write core candidate"]];
CanonMethodCard`WriteProviderResult[task, outputDir, "PROVISIONAL", "CANDIDATE_TRANSFORMATION",
  <|"core_candidates" -> <|"type" -> "mathematica-expression", "path" -> FileNameTake[artifactPath]|>|>,
  <|"method_id" -> methodID, "candidate_count" -> 1, "seed_ids" -> ids,
    "interface" -> CanonInitialInterface`CoreContract[],
    "provider_prechecks" -> prechecks, "diagnostics" -> diagnostics,
    "elapsed_seconds" -> AbsoluteTime[] - startTime, "attempts" -> attemptCount, "next_step" -> "CHECK_CORE"|>];
Quit[0];
