#!/usr/bin/env wolframscript

$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "FINAL_CHECK"];
prepared = CanonMethodCard`LoadArtifact[task, inputPath, "prepared_family"];
masterBasis = CanonMethodCard`LoadArtifact[task, inputPath, "master_basis"];
manifest = CanonMethodCard`LoadArtifact[task, inputPath, "sector_manifest"];
ordered = CanonMethodCard`LoadArtifact[task, inputPath, "ordered_master_de"];
accepted = CanonMethodCard`LoadArtifact[task, inputPath, "accepted_prefix"];

sameMatrices[left_, right_] := And @@ MapThread[
  CanonMethodCard`ZeroMatrixQ[Map[Together, #1 - #2, {2}]] &, {left, right}];
variables = ordered["variables"];
regulator = ordered["regulator"];
declaredAlphabet = accepted["alphabet"];
expectedTrace = KeyTake[#, {"id", "propagator_count"}] & /@
  manifest["sectors"];
trace = accepted["sector_trace"];
remaining = Drop[expectedTrace, Length[trace]];
backend = Lookup[Lookup[task["payload"], "method_options", <||>], "gauge_backend", "wolfram"];
gaugeBackend = <|"name" -> backend|>;
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
residueMatrices = CanonMethodCard`DLogResidues[
  computed, variables, regulator, declaredAlphabet];

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
    trace === expectedTrace && DuplicateFreeQ[Lookup[expectedTrace, "id"]]),
  "candidate_trace_coverage" ->
    (Lookup[accepted["candidate_trace"], "sector"] === expectedTrace),
  "cursor_complete" -> (remaining === {}),
  "accepted_prefix_hash" -> (accepted["prefix_id"] ===
    "sha256:" <> Hash[KeyDrop[accepted, "prefix_id"], "SHA256", "HexString"]),
  "invertible_cumulative_transformation" ->
    TrueQ[Together[Det[accepted["transformation"]]] =!= 0],
  "exact_global_gauge" -> exactGlobalGauge,
  "flat_connection" -> CanonMethodCard`FlatConnectionQ[computed, variables],
  "epsilon_factorized" ->
    CanonMethodCard`EpsilonFactorizedQ[computed, regulator],
  "epsilon_free_alphabet" -> FreeQ[declaredAlphabet, regulator],
  "constant_residue_dlog" -> residueMatrices =!= $Failed
|>;

If[!And @@ Values[checks],
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
