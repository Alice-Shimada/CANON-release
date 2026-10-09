#!/usr/bin/env wolframscript

$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
fixtureRoot = FileNameJoin[{repoRoot, "tests", "fixtures", "final-check"}];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
Begin["CANON`DEData`"];
temporary = If[StringQ[Environment["CANON_TEST_WORK"]],
  CreateDirectory[Environment["CANON_TEST_WORK"]], CreateDirectory[]];
ClearAll[l0, l1, j0, eps, x, y];

put[name_, expression_] := Module[{path = FileNameJoin[{temporary, name <> ".wl"}]},
  Put[expression, path]; path];
descriptor[path_] := <|"type" -> "mathematica-expression", "path" -> path|>;
payload[prepared_, master_, manifest_, ordered_, accepted_] := <|
  "prepared_family" -> descriptor[prepared],
  "master_basis" -> descriptor[master],
  "sector_manifest" -> descriptor[manifest],
  "ordered_master_de" -> descriptor[ordered],
  "accepted_prefix" -> descriptor[accepted]|>;
runFinal[name_, body_] := Module[{input, output, process},
  input = FileNameJoin[{temporary, name <> ".json"}];
  output = FileNameJoin[{temporary, name}];
  Export[input, <|"schema" -> "canon-neu/script-input/v1", "task_id" -> name,
    "step" -> "FINAL_CHECK", "sector" -> Null, "payload" -> body|>, "RawJSON"];
  process = RunProcess[{"wolframscript", "-file",
    FileNameJoin[{repoRoot, "mma", "CheckFullSystem.wls"}], input, output}];
  <|"process" -> process, "output" -> output,
    "result" -> Import[FileNameJoin[{output, "result.json"}], "RawJSON"]|>
];
artifact[run_, key_] := Get[FileNameJoin[{run["output"],
  run["result", "artifacts", key, "path"]}]];
seal[prefix_] := With[{body = KeyDrop[prefix, "prefix_id"]},
  Join[<|"prefix_id" ->
    "sha256:" <> Hash[body, "SHA256", "HexString"]|>, body]];
sameMatrices[left_, right_] := And @@ MapThread[
  And @@ (TrueQ[Together[#] === 0] & /@ Flatten[#1 - #2]) &, {left, right}];

historicalAcceptedPath = FileNameJoin[{fixtureRoot, "accepted-prefix.wl"}];
orderedPath = FileNameJoin[{fixtureRoot, "ordered-master-de.wl"}];
historicalAccepted = Get[historicalAcceptedPath];
(* Keep the historical bytes, including their unresolved l1 abbreviation,
   intact. A publishable basis contains explicit original-master definitions. *)
accepted = seal @ Join[historicalAccepted, <|"basis" ->
  Inverse[historicalAccepted["transformation"]].historicalAccepted["source_basis"]|>];
acceptedPath = put["explicit-accepted", accepted];
ordered = Get[orderedPath];
prepared = <|"schema" -> "canon-neu/prepared-family/v1",
  "family_ref" -> ordered["family_id"], "basis_ref" -> ordered["basis_id"],
  "variables" -> ordered["variables"], "regulator" -> ordered["regulator"]|>;
master = <|"schema" -> "canon-neu/master-basis/v1",
  "family_ref" -> ordered["family_id"], "basis_ref" -> ordered["basis_id"],
  "masters" -> ordered["basis"]|>;
manifest = <|"schema" -> "canon-neu/sector-manifest/v1",
  "sectors" -> accepted["sector_trace"]|>;
preparedPath = put["prepared", prepared];
masterPath = put["master", master];
manifestPath = put["manifest", manifest];
positivePayload = payload[
  preparedPath, masterPath, manifestPath, orderedPath, acceptedPath];
positiveA = runFinal["positive-a", positivePayload];
positiveB = runFinal["positive-b", positivePayload];
unresolvedBasis = runFinal["unresolved-historical-basis", payload[
  preparedPath, masterPath, manifestPath, orderedPath, historicalAcceptedPath]];
canonicalBasis = artifact[positiveA, "canonical_basis"];
canonicalDE = artifact[positiveA, "canonical_de"];

receiptPath = FileNameJoin[{temporary, "independent-receipt.wl"}];
verification = RunProcess[{"wolframscript", "-file",
  FileNameJoin[{repoRoot, "tests", "VerifyFullSystemArtifacts.wls"}],
  preparedPath, masterPath, manifestPath, orderedPath, acceptedPath,
  positiveA["output"], positiveB["output"], receiptPath}];
receipt = Get[receiptPath];

incomplete = seal @ Join[accepted, <|
  "sector_trace" -> Take[accepted["sector_trace"], 1],
  "candidate_trace" -> Take[accepted["candidate_trace"], 1]|>];
incompleteRun = runFinal["incomplete-trace", payload[
  preparedPath, masterPath, manifestPath, orderedPath, put["incomplete", incomplete]]];

noncanonical = seal @ Join[accepted,
  <|"transformation" -> {{2, 0}, {x^2, 1}}|>];
noncanonicalRun = runFinal["noncanonical-transform", payload[
  preparedPath, masterPath, manifestPath, orderedPath,
  put["noncanonical", noncanonical]]];

epsLetter = seal @ Join[accepted, <|"alphabet" -> {eps x, 1 - x}|>];
epsLetterRun = runFinal["epsilon-letter", payload[
  preparedPath, masterPath, manifestPath, orderedPath,
  put["epsilon-letter", epsLetter]]];

firstSector = First[accepted["sector_trace"]];
sharedMatrices = {
  {{eps (1/x + 3/(x + y))}},
  {{eps (2/y + 3/(x + y))}}
};
sharedPrepared = Join[prepared, <|"variables" -> {x, y}|>];
sharedMaster = Join[master, <|"masters" -> {l0}|>];
sharedManifest = Join[manifest, <|"sectors" -> {firstSector}|>];
sharedOrdered = Join[ordered, <|"basis" -> {l0}, "variables" -> {x, y},
  "matrices" -> sharedMatrices|>];
sharedAccepted = seal @ <|
  "schema" -> "canon-neu/accepted-prefix/v1", "parent_prefix_id" -> Null,
  "family_id" -> ordered["family_id"],
  "coefficient_domain" -> "exact-rational-functions",
  "source_basis" -> {l0}, "basis" -> {l0},
  "convention" -> "old_source_basis = transformation . accepted_basis",
  "transformation" -> {{1}}, "variables" -> {x, y}, "regulator" -> eps,
  "alphabet" -> {x, y, x + y}, "matrices" -> sharedMatrices,
  "sector_trace" -> {firstSector},
  "candidate_trace" -> {First[accepted["candidate_trace"]]}|>;
sharedPreparedPath = put["shared-prepared", sharedPrepared];
sharedMasterPath = put["shared-master", sharedMaster];
sharedManifestPath = put["shared-manifest", sharedManifest];
sharedRun = runFinal["shared-residues", payload[
  sharedPreparedPath, sharedMasterPath, sharedManifestPath,
  put["shared-ordered", sharedOrdered], put["shared-accepted", sharedAccepted]]];
sharedCanonicalDE = artifact[sharedRun, "canonical_de"];

incompatibleMatrices = {{{eps/(x + y)}}, {{2 eps/(x + y)}}};
incompatibleOrdered = Join[sharedOrdered, <|"matrices" -> incompatibleMatrices|>];
incompatibleAccepted = seal @ Join[sharedAccepted,
  <|"alphabet" -> {x + y}, "matrices" -> incompatibleMatrices|>];
incompatibleRun = runFinal["incompatible-residues", payload[
  sharedPreparedPath, sharedMasterPath, sharedManifestPath,
  put["incompatible-ordered", incompatibleOrdered],
  put["incompatible-accepted", incompatibleAccepted]]];

nonflatPrepared = Join[prepared, <|"variables" -> {x, y}|>];
nonflatMaster = Join[master, <|"masters" -> {l0}|>];
nonflatManifest = Join[manifest, <|"sectors" -> {firstSector}|>];
nonflatOrdered = Join[ordered, <|"basis" -> {l0}, "variables" -> {x, y},
  "matrices" -> {{{0}}, {{eps x}}}|>];
nonflatAccepted = seal @ <|
  "schema" -> "canon-neu/accepted-prefix/v1", "parent_prefix_id" -> Null,
  "family_id" -> ordered["family_id"],
  "coefficient_domain" -> "exact-rational-functions",
  "source_basis" -> {l0}, "basis" -> {l0},
  "convention" -> "old_source_basis = transformation . accepted_basis",
  "transformation" -> {{1}}, "variables" -> {x, y}, "regulator" -> eps,
  "alphabet" -> {x}, "matrices" -> nonflatOrdered["matrices"],
  "sector_trace" -> {firstSector},
  "candidate_trace" -> {First[accepted["candidate_trace"]]}|>;
nonflatRun = runFinal["nonflat", payload[
  put["nonflat-prepared", nonflatPrepared], put["nonflat-master", nonflatMaster],
  put["nonflat-manifest", nonflatManifest], put["nonflat-ordered", nonflatOrdered],
  put["nonflat-accepted", nonflatAccepted]]];

rootMatrices = {{{eps/Sqrt[1+x^2]}}, {{eps/y}}};
rootAccepted = seal @ Join[sharedAccepted, <|"matrices" -> rootMatrices,
  "alphabet" -> {x+Sqrt[1+x^2], y}|>];
rootRun = runFinal["algebraic-letters", payload[
  sharedPreparedPath, sharedMasterPath, sharedManifestPath,
  put["algebraic-ordered", Join[sharedOrdered, <|"matrices" -> rootMatrices|>]],
  put["algebraic-accepted", rootAccepted]]];
rootCanonical = artifact[rootRun, "canonical_de"];

(* Both directions have constant dlog residues, but their commutator only
   vanishes at the former fixed sample y=3/5. This is not an integrable DE. *)
stationaryLetter = 1 + (y - 3/5)^2;
stationaryMatrices = {
  eps {{0, 1}, {0, 0}}/x,
  eps {{0, 0}, {1, 0}} D[stationaryLetter, y]/stationaryLetter
};
stationaryOrdered = Join[ordered,
  <|"variables" -> {x, y}, "matrices" -> stationaryMatrices|>];
stationaryAccepted = seal @ Join[accepted, <|
  "variables" -> {x, y}, "matrices" -> stationaryMatrices,
  "alphabet" -> {x, stationaryLetter}, "transformation" -> IdentityMatrix[2],
  "basis" -> ordered["basis"]|>];
stationaryRun = runFinal["nonflat-away-from-sample", payload[
  sharedPreparedPath, masterPath, manifestPath,
  put["stationary-ordered", stationaryOrdered],
  put["stationary-accepted", stationaryAccepted]]];

Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];

tests = {
  VerificationTest[
    unresolvedBasis["result", "code"] === "FULL_SYSTEM_FAIL" &&
    !TrueQ[unresolvedBasis["result", "summary", "checks", "basis_definition"]] &&
    TrueQ[unresolvedBasis["result", "summary", "checks", "exact_global_gauge"]],
    True, TestID -> "matrix-certificate-does-not-certify-unresolved-basis-abbreviations"],
  VerificationTest[
    CanonMethodCard`FlatConnectionQ[stationaryMatrices, {x, y}],
    False, TestID -> "flatness-is-a-symbolic-identity-not-a-fixed-point-test"],
  VerificationTest[
    stationaryRun["result", "code"] === "FULL_SYSTEM_FAIL" &&
      !stationaryRun["result", "summary", "checks", "flat_connection"] &&
      stationaryRun["result", "summary", "checks", "exact_global_gauge"] &&
      stationaryRun["result", "summary", "checks", "constant_residue_dlog"],
    True, TestID -> "noncommuting-dlog-residues-cannot-pass-at-a-stationary-sample"],
  VerificationTest[
    CanonMethodCard`DLogResidues[
      {{{eps (1/x + 2 (x - 2))}}, {{0}}}, {x, y}, eps, {x}],
    $Failed, TestID -> "sample-fit-must-satisfy-the-global-identity"],
  VerificationTest[
    CanonMethodCard`DLogResidues[
      Table[{{3 eps D[Sqrt[x] + Sqrt[y], v]/(Sqrt[x] + Sqrt[y])}},
        {v, {x, y}}], {x, y}, eps, {Sqrt[x] + Sqrt[y]}],
    {{{3}}}, TestID -> "shared-residues-in-two-radical-generators"],
  VerificationTest[rootRun["result", "code"] === "ALL_PASS" &&
    rootCanonical["residue_matrices"] === {{{1}}, {{1}}}, True,
    TestID -> "algebraic-letters-have-shared-constant-residues-without-rationalization"],
  VerificationTest[
    FileHash[historicalAcceptedPath, "SHA256"] ===
      FromDigits["fc1e2e951d10ca0951827ddd18e2425f863836be06ca68a49fe7bd40d4245ded", 16] &&
    FileHash[orderedPath, "SHA256"] ===
      FromDigits["9a75821301b6895cb8daac453ea1a951d5329b4e679795192fe3a06dd4e5ae81", 16] &&
    Lookup[positiveA["result"], {"status", "code"}] === {"PASS", "ALL_PASS"} &&
    Sort[Keys[positiveA["result", "artifacts"]]] ===
      {"canonical_basis", "canonical_de"},
    True, TestID -> "actual-t005-t006-full-system-passes"],
  VerificationTest[
    canonicalBasis["source_basis"] === accepted["source_basis"] &&
    canonicalBasis["basis"] === accepted["basis"] &&
    canonicalBasis["transformation"] === accepted["transformation"] &&
    canonicalBasis["sector_trace"] === manifest["sectors"] &&
    canonicalBasis["candidate_trace"] === accepted["candidate_trace"],
    True, TestID -> "canonical-basis-retains-raw-map-and-resident-traces"],
  VerificationTest[
    sameMatrices[canonicalDE["matrices"], accepted["matrices"]] &&
    canonicalDE["alphabet"] === {x, 1 - x} &&
    canonicalDE["residue_matrices"] ===
      {{{1, 0}, {1, 0}}, {{0, 0}, {0, -1}}} &&
    And @@ Values[canonicalDE["checks"]],
    True, TestID -> "global-gauge-has-certified-constant-residue-dlog-form"],
  VerificationTest[
    Lookup[sharedRun["result"], {"status", "code"}] ===
      {"PASS", "ALL_PASS"} &&
    sameMatrices[sharedCanonicalDE["matrices"], sharedMatrices] &&
    sharedCanonicalDE["alphabet"] === {x, y, x + y} &&
    sharedCanonicalDE["residue_matrices"] === {{{1}}, {{2}}, {{3}}} &&
    sharedCanonicalDE["check_scope"] ===
      "exact-global-gauge-symbolic-flatness-multivariable-shared-residue-declared-dlog-span" &&
    And @@ Values[sharedCanonicalDE["checks"]],
    True, TestID -> "two-variable-system-uses-one-shared-residue-vector"],
  VerificationTest[
    Together[incompatibleMatrices[[1, 1, 1]]/eps - D[x + y, x]/(x + y)] === 0 &&
    Together[incompatibleMatrices[[2, 1, 1]]/eps - 2 D[x + y, y]/(x + y)] === 0 &&
    Lookup[incompatibleRun["result"], {"status", "code"}] ===
      {"FAIL", "FULL_SYSTEM_FAIL"} &&
    incompatibleRun["result", "summary", "checks", "exact_global_gauge"] &&
    incompatibleRun["result", "summary", "checks", "epsilon_factorized"] &&
    !incompatibleRun["result", "summary", "checks", "constant_residue_dlog"],
    True, TestID -> "direction-wise-dlogs-without-shared-residues-fail"],
  VerificationTest[
    FileHash[FileNameJoin[{positiveA["output"], "canonical-basis.wl"}], "SHA256"] ===
      FileHash[FileNameJoin[{positiveB["output"], "canonical-basis.wl"}], "SHA256"] &&
    FileHash[FileNameJoin[{positiveA["output"], "canonical-de.wl"}], "SHA256"] ===
      FileHash[FileNameJoin[{positiveB["output"], "canonical-de.wl"}], "SHA256"],
    True, TestID -> "fresh-final-artifacts-are-byte-stable"],
  VerificationTest[
    verification["ExitCode"] === 0 && receipt["all_pass"] &&
    And @@ Values[receipt["checks"]],
    True, TestID -> "independent-fresh-kernel-recomputes-all-invariants"],
  VerificationTest[
    Lookup[incompleteRun["result"], {"status", "code"}] ===
      {"FAIL", "FULL_SYSTEM_FAIL"} &&
    !incompleteRun["result", "summary", "checks", "sector_trace_resident_order"] &&
    !incompleteRun["result", "summary", "checks", "cursor_complete"],
    True, TestID -> "incomplete-resident-trace-fails"],
  VerificationTest[
    Lookup[noncanonicalRun["result"], {"status", "code"}] ===
      {"FAIL", "FULL_SYSTEM_FAIL"} &&
    !noncanonicalRun["result", "summary", "checks", "exact_global_gauge"] &&
    !noncanonicalRun["result", "summary", "checks", "epsilon_factorized"],
    True, TestID -> "noncanonical-cumulative-transform-fails"],
  VerificationTest[
    Lookup[nonflatRun["result"], {"status", "code"}] ===
      {"FAIL", "FULL_SYSTEM_FAIL"} &&
    !nonflatRun["result", "summary", "checks", "flat_connection"],
    True, TestID -> "nonflat-full-system-fails"],
  VerificationTest[
    Lookup[epsLetterRun["result"], {"status", "code"}] ===
      {"FAIL", "FULL_SYSTEM_FAIL"} &&
    epsLetterRun["result", "summary", "checks", "exact_global_gauge"] &&
    !epsLetterRun["result", "summary", "checks", "epsilon_free_alphabet"] &&
    !epsLetterRun["result", "summary", "checks", "constant_residue_dlog"],
    True, TestID -> "epsilon-dependent-letter-fails-before-residue-certificate"]
};

report = TestReport[tests];
Print[InputForm[<|"total" -> report["TestsSucceededCount"] +
    report["TestsFailedCount"], "succeeded" -> report["TestsSucceededCount"],
  "failed" -> report["TestsFailedCount"]|>]];
If[report["TestsFailedCount"] =!= 0, Print[InputForm[report["TestsFailed"]]]];
If[!StringQ[Environment["CANON_TEST_WORK"]], DeleteDirectory[temporary, DeleteContents -> True]];
Exit[If[report["TestsFailedCount"] === 0, 0, 1]];
