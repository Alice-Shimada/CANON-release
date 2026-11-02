#!/usr/bin/env wolframscript

$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "FINAL_CHECK"];
(* Opt-in diagnostic events preserve all FINAL_CHECK acceptance expressions. *)
progressEnabled = TrueQ[Lookup[Lookup[task["payload"], "method_options", <||>], "progress", False]];
progressPath = FileNameJoin[{outputDir, "final-progress.jsonl"}];
If[progressEnabled && !DirectoryQ[outputDir], CreateDirectory[outputDir, CreateIntermediateDirectories -> True]];
progressEvent[name_, state_, extra_ : <||>] := If[progressEnabled, Module[{stream},
  stream = OpenAppend[progressPath];
  WriteString[stream, ExportString[Join[<|"phase" -> name, "state" -> state,
    "absolute_time" -> AbsoluteTime[]|>, extra], "RawJSON", "Compact" -> True] <> "\n"];
  Close[stream]]];
SetAttributes[measured, HoldRest];
measured[name_, expression_] := If[!progressEnabled, expression,
  Module[{started = AbsoluteTime[], value},
    progressEvent[name, "start"]; value = expression;
    progressEvent[name, "end", <|"seconds" -> AbsoluteTime[] - started|>]; value]];
basisZeroQ[expression_] := If[!progressEnabled, CanonMethodCard`ZeroMatrixQ[expression],
  MatrixQ[expression] && And @@ Flatten[MapIndexed[
    Function[{entry, index}, measured[
      "basis_zero/" <> ToString[index[[1]]] <> "/" <> ToString[index[[2]]],
      TrueQ[FullSimplify[Together[entry]] === 0]]], expression, {2}]]];

prepared = measured["load/prepared_family", CanonMethodCard`LoadArtifact[task, inputPath, "prepared_family"]];
masterBasis = measured["load/master_basis", CanonMethodCard`LoadArtifact[task, inputPath, "master_basis"]];
manifest = measured["load/sector_manifest", CanonMethodCard`LoadArtifact[task, inputPath, "sector_manifest"]];
ordered = measured["load/ordered_master_de", CanonMethodCard`LoadArtifact[task, inputPath, "ordered_master_de"]];
accepted = measured["load/accepted_prefix", CanonMethodCard`LoadArtifact[task, inputPath, "accepted_prefix"]];

fail[reason_] := (CanonMethodCard`WriteResult[task, outputDir, "ERROR",
  "INVALID_FINAL_INPUT", <||>, <|"reason" -> reason|>]; Quit[1]);
measured["validate/input_schema", If[!AllTrue[{prepared, masterBasis, manifest, ordered, accepted}, AssociationQ] ||
  Lookup[ordered, "schema", None] =!= "canon-neu/ordered-master-de/v1" ||
  Lookup[accepted, "schema", None] =!= "canon-neu/accepted-prefix/v1" ||
  !ListQ[Lookup[ordered, "basis", None]] || ordered["basis"] === {},
  fail["Final checking requires the complete original DE and accepted prefix."]]];

sameMatrices[left_, right_] := And @@ MapThread[
  CanonMethodCard`ZeroMatrixQ[Map[Together, #1 - #2, {2}]] &, {left, right}];
variables = ordered["variables"];
regulator = ordered["regulator"];
declaredAlphabet = accepted["alphabet"];
dimension = Length[ordered["basis"]];
transformation = accepted["transformation"];
measured["validate/matrix_domain_trace", If[!TrueQ[CanonMethodCard`ValidMatrixSystemQ[ordered["matrices"], variables, regulator, dimension] &&
    CanonMethodCard`ValidMatrixSystemQ[accepted["matrices"], variables, regulator, dimension] &&
    MatrixQ[transformation] && Dimensions[transformation] === {dimension, dimension} &&
    AllTrue[Flatten[transformation], CanonMethodCard`ExactAlgebraicExpressionQ] &&
    ListQ[accepted["basis"]] && Length[accepted["basis"]] === dimension &&
    ListQ[declaredAlphabet] && AllTrue[declaredAlphabet, CanonMethodCard`ExactAlgebraicExpressionQ] &&
    ListQ[manifest["sectors"]] && AllTrue[manifest["sectors"], AssociationQ] &&
    ListQ[accepted["sector_trace"]] && ListQ[accepted["candidate_trace"]]],
  fail["Invalid matrix dimensions, exact coefficient domain, alphabet or trace."]]];
invertible = measured["invertibility", Together[Det[transformation]] =!= 0];
If[!TrueQ[invertible],
  CanonMethodCard`WriteResult[task, outputDir, "FAIL", "FULL_SYSTEM_FAIL", <||>,
    <|"checks" -> <|"invertible_cumulative_transformation" -> False|>|>]; Quit[0]];
measured["prepare/sector_trace", expectedTrace = KeyTake[#, {"id", "propagator_count"}] & /@
  manifest["sectors"];
trace = accepted["sector_trace"];
remaining = Drop[expectedTrace, Length[trace]]];
backend = Lookup[Lookup[task["payload"], "method_options", <||>], "gauge_backend", "wolfram"];
If[!MemberQ[{"wolfram", "fermat", "flint"}, backend], fail["Unknown gauge_backend; select wolfram, fermat or flint."]];
gaugeBackend = <|"name" -> backend|>;
If[backend === "flint",
  gaugeOptions = Lookup[task["payload"], "method_options", <||>];
  gaugeError[code_, reason_] := (CanonMethodCard`WriteResult[task, outputDir,
    "ERROR", code, <||>, <|"reason" -> reason, "gauge_backend" -> "flint"|>]; Quit[1]);
  gaugeEntry[key_, default_] := Module[{descriptor, resolved},
    descriptor = Lookup[gaugeOptions, key, <|"path" -> default|>];
    If[StringQ[descriptor], descriptor = <|"path" -> descriptor|>];
    resolved = CanonMethodCard`ResolveArtifactPath[inputPath, descriptor];
    If[FailureQ[resolved], gaugeError["GAUGE_BACKEND_UNAVAILABLE", ToString[resolved, InputForm]]]; resolved];
  gaugeHelper = gaugeEntry["flint_gauge_helper", FileNameJoin[{repoRoot, "mma", "lib", "FlintGaugeArithmetic.wl"}]];
  normalizationHelper = gaugeEntry["flint_normalization_helper", FileNameJoin[{repoRoot, "mma", "lib", "FlintNormalization.wl"}]];
  If[Quiet@Check[Get[normalizationHelper]; Get[gaugeHelper]; True, False] =!= True ||
      DownValues[CanonFlintNormalize`Normalize] === {} || DownValues[CanonFlintGauge`FlintGaugeIdentity] === {},
    gaugeError["GAUGE_BACKEND_UNAVAILABLE", "Selected FLINT helpers did not initialize."]];
  gaugeExecutable = Lookup[gaugeOptions, "flint_executable", None];
  If[!StringQ[gaugeExecutable], gaugeError["GAUGE_BACKEND_UNAVAILABLE", "flint_executable must identify the installed exact arithmetic utility."]];
  gaugeExecutable = CanonMethodCard`ResolveInputPath[inputPath, gaugeExecutable];
  If[!FileExistsQ[gaugeExecutable] || (KeyExistsQ[gaugeOptions, "flint_executable_sha256"] &&
      FileHash[gaugeExecutable, "SHA256", "HexString"] =!= gaugeOptions["flint_executable_sha256"]) ||
      Lookup[gaugeOptions, "flint_threads", 1] =!= 1,
    gaugeError["GAUGE_BACKEND_UNAVAILABLE", "FLINT executable is unavailable, its pin mismatches, or threads is not one."]];
  gaugeSource = gaugeEntry["flint_source", FileNameJoin[{repoRoot, "components", "basis-diagnostic", "flint_pair.cpp"}]];
  gaugeSerializer = If[KeyExistsQ[gaugeOptions,"flint_serializer"],CanonFlintNormalize`CheckedSerializer[inputPath,gaugeOptions["flint_serializer"]],None];
  If[gaugeSerializer=!=None&&!AssociationQ[gaugeSerializer],gaugeError["GAUGE_BACKEND_UNAVAILABLE","Declared structural serializer did not initialize."]];
  computed = accepted["matrices"];
  gaugeResult = If[gaugeSerializer===None,CanonFlintGauge`FlintGaugeIdentity[ordered["matrices"], variables,
    transformation, computed, gaugeExecutable, FileNameJoin[{outputDir, "gauge-flint"}], progressEvent],
    CanonFlintGauge`FlintGaugeIdentity[ordered["matrices"],variables,transformation,computed,gaugeExecutable,FileNameJoin[{outputDir,"gauge-flint"}],progressEvent,gaugeSerializer]];
  If[FailureQ[gaugeResult],
    gaugeError[If[gaugeResult[[1]] === "UNSUPPORTED_FLINT_DOMAIN", "UNSUPPORTED_GAUGE_ARITHMETIC", "GAUGE_ARITHMETIC_FAILED"], ToString[gaugeResult, InputForm]]];
  exactGlobalGauge = TrueQ[gaugeResult["zero"]];
  If[gaugeSerializer=!=None,gaugeBackend=Join[gaugeBackend,<|"serializer"->gaugeSerializer|>]];
  gaugeBackend = Join[gaugeBackend, gaugeResult["runtime"], <|
    "gauge_helper" -> gaugeHelper, "gauge_helper_sha256" -> FileHash[gaugeHelper, "SHA256", "HexString"],
    "normalization_helper" -> normalizationHelper, "normalization_helper_sha256" -> FileHash[normalizationHelper, "SHA256", "HexString"],
    "native_source" -> gaugeSource, "native_source_sha256" -> FileHash[gaugeSource, "SHA256", "HexString"]|>],
If[backend === "fermat",
  package = CanonMethodCard`ResolveMethodPackage[task, inputPath, "Fermatica`"];
  Get[package["entry"]];
  Fermatica`$FermatCMD = Environment["FERMATPATH"];
  computed = accepted["matrices"];
  exactGlobalGauge = CanonMethodCard`FermatGaugeIdentityQ[
    ordered["matrices"], variables, accepted["transformation"], computed];
  gaugeBackend = Join[gaugeBackend, <|"entry" -> package["entry"],
    "entry_sha256" -> FileHash[package["entry"], "SHA256", "HexString"],
    "version" -> Fermatica`$FermaticaVersion,
    "fermat_executable" -> Fermatica`$FermatCMD,
    "fermat_sha256" -> FileHash[Fermatica`$FermatCMD, "SHA256", "HexString"],
    "fermat_version" -> Fermatica`$FermatVersionString|>],
  computed = CanonMethodCard`GaugeTransform[
    ordered["matrices"], variables, accepted["transformation"]];
  exactGlobalGauge = sameMatrices[computed, accepted["matrices"]]
];
];
residueMatrices = measured["dlog_residues", CanonMethodCard`DLogResidues[
  computed, variables, regulator, declaredAlphabet]];

(* Check the published integral definitions without forming a common denominator
   over different integrals, or a second inverse of the cumulative matrix. *)
basisRows = measured["basis_coefficients", CanonMethodCard`IntegralCoefficientRows[accepted["basis"],
  ordered["basis"], Head[First[ordered["basis"]]]]];
basisBackend = Lookup[Lookup[task["payload"], "method_options", <||>], "basis_backend", "wolfram"];
If[!MemberQ[{"wolfram", "flint"}, basisBackend], fail["Unknown basis_backend; select wolfram or flint."]];
basisArithmetic = <|"backend" -> basisBackend|>;
basisDefinition = False;
If[!MemberQ[basisRows, $Failed],
  basisResidual = measured["basis_product",
    Normal[SparseArray[transformation].SparseArray[basisRows] - IdentityMatrix[dimension, SparseArray]]];
  If[basisBackend === "flint",
    flintExecutable = Lookup[Lookup[task["payload"], "method_options", <||>], "flint_executable", None];
    If[!StringQ[flintExecutable], fail["flint_executable must identify the installed exact arithmetic utility."]];
    flintExecutable = CanonMethodCard`ResolveInputPath[inputPath, flintExecutable];
    Get[FileNameJoin[{repoRoot, "mma", "lib", "FlintBasisArithmetic.wl"}]];
    flintResult = measured["basis_zero_flint",
      CanonFlintBasis`FlintBasisZero[basisResidual, Append[variables, regulator],
        flintExecutable, FileNameJoin[{outputDir, "basis-flint"}], progressEvent]];
    If[FailureQ[flintResult],
      CanonMethodCard`WriteResult[task, outputDir, "ERROR", "UNSUPPORTED_BASIS_ARITHMETIC",
        <||>, <|"reason" -> ToString[flintResult, InputForm]|>]; Quit[1]];
    basisDefinition = TrueQ[flintResult["zero"]];
    basisArithmetic = Join[basisArithmetic, flintResult["runtime"]],
    basisDefinition = basisZeroQ[basisResidual]
  ]
];

checks = <|
  "artifact_identity" -> (
    SameQ[prepared["family_ref"], masterBasis["family_ref"],
      ordered["family_id"], accepted["family_id"]] &&
    SameQ[prepared["basis_ref"], masterBasis["basis_ref"],
      ordered["basis_id"]] &&
    SameQ[prepared["variables"], variables, accepted["variables"]] &&
    SameQ[prepared["regulator"], regulator, accepted["regulator"]]),
  "source_basis_resident_order" -> (
    ordered["basis"] === masterBasis["masters"] &&
    accepted["source_basis"] === ordered["basis"] &&
    DuplicateFreeQ[ordered["basis"]]),
  "sector_trace_resident_order" -> (
    CanonMethodCard`SameSectorTraceQ[trace, expectedTrace] && DuplicateFreeQ[Lookup[expectedTrace, "id"]]),
  "candidate_trace_coverage" ->
    CanonMethodCard`SameSectorTraceQ[Lookup[accepted["candidate_trace"], "sector"], expectedTrace],
  "cursor_complete" -> (remaining === {}),
  "accepted_prefix_hash" -> (accepted["prefix_id"] ===
    "sha256:" <> Hash[KeyDrop[accepted, "prefix_id"], "SHA256", "HexString"]),
  "invertible_cumulative_transformation" -> TrueQ[invertible],
  "basis_definition" -> TrueQ[basisDefinition],
  "transformation_convention" -> (accepted["convention"] ===
    "old_source_basis = transformation . accepted_basis"),
  "exact_global_gauge" -> exactGlobalGauge,
  "flat_connection" -> measured["flat_connection", CanonMethodCard`FlatConnectionQ[computed, variables]],
  "epsilon_factorized" ->
    CanonMethodCard`EpsilonFactorizedQ[computed, regulator],
  "epsilon_free_alphabet" -> FreeQ[declaredAlphabet, regulator],
  "constant_residue_dlog" -> residueMatrices =!= $Failed
|>;

If[!TrueQ[And @@ Values[checks]],
  CanonMethodCard`WriteResult[task, outputDir, "FAIL", "FULL_SYSTEM_FAIL",
    <||>, <|"checks" -> checks|>];
  Quit[0]
];

active = Pick[Range[Length[declaredAlphabet]],
  CanonMethodCard`ZeroMatrixQ /@ residueMatrices, False];
canonicalBasis = <|
  "schema" -> "canon-neu/canonical-basis/v1",
  "family_id" -> accepted["family_id"],
  "basis_id" -> accepted["prefix_id"],
  "coefficient_domain" -> "exact-algebraic-functions",
  "source_basis" -> accepted["source_basis"],
  "basis" -> accepted["basis"],
  "convention" -> accepted["convention"],
  "transformation" -> accepted["transformation"],
  "sector_trace" -> trace,
  "candidate_trace" -> accepted["candidate_trace"]
|>;
canonicalDE = <|
  "schema" -> "canon-neu/canonical-de/v1",
  "family_id" -> accepted["family_id"],
  "basis_id" -> accepted["prefix_id"],
  "coefficient_domain" -> "exact-algebraic-functions",
  "variables" -> variables,
  "regulator" -> regulator,
  "alphabet" -> declaredAlphabet[[active]],
  "residue_matrices" -> residueMatrices[[active]],
  "matrices" -> computed,
  "convention" -> "D[basis, variables[[i]]] = matrices[[i]] . basis",
  "check_scope" ->
    "exact-global-gauge-symbolic-flatness-multivariable-shared-residue-declared-dlog-span",
  "gauge_backend" -> gaugeBackend,
  "basis_arithmetic" -> basisArithmetic,
  "checks" -> checks
|>;
basisPath = CanonMethodCard`WriteWLArtifact[
  canonicalBasis, outputDir, "canonical-basis.wl"];
dePath = CanonMethodCard`WriteWLArtifact[
  canonicalDE, outputDir, "canonical-de.wl"];
CanonMethodCard`WriteResult[task, outputDir, "PASS", "ALL_PASS",
  <|
    "canonical_basis" -> <|"type" -> "mathematica-expression",
      "path" -> FileNameTake[basisPath]|>,
    "canonical_de" -> <|"type" -> "mathematica-expression",
      "path" -> FileNameTake[dePath]|>
  |>,
  <|"master_count" -> Length[canonicalBasis["basis"]],
    "sector_count" -> Length[trace],
    "alphabet_size" -> Length[canonicalDE["alphabet"]], "checks" -> checks|>];
