BeginPackage["CanonDLogReconstruction`"];
RunStep::usage = "RunStep[inputJSON, outputDirectory] runs one explicitly selected sampled-dlog operation.";
Begin["`Private`"];

$identityKeys = {"family_id", "basis_id", "chart_id", "frame_id", "scope", "variables", "regulator", "convention"};
$convention = "D[basis, variables[[i]]] = matrices[[i]] . basis";
$boundary = "finite supplied samples; no global gauge identity, alphabet completeness, or UT claim";
stop[status_, code_, details_: <||>] := Throw[<|"status" -> status, "code" -> code, "artifacts" -> <||>, "summary" -> details|>, "dlog-result"];
require[test_, code_, details_: <||>] := If[!TrueQ[test], stop["ERROR", code, details]];
identity[a_] := KeyTake[a, $identityKeys];
validIdentity[a_] := AssociationQ[a] && And @@ (KeyExistsQ[a, #] & /@ $identityKeys) &&
  AllTrue[Lookup[a, Take[$identityKeys, 4]], StringQ[#] && # =!= "" &] && AssociationQ[a["scope"]] &&
  ListQ[a["variables"]] && a["variables"] =!= {} && AllTrue[a["variables"], MatchQ[#, _Symbol | _Symbol[__Integer]] &] &&
  DuplicateFreeQ[a["variables"]] && Head[a["regulator"]] === Symbol &&
  FreeQ[a["variables"], a["regulator"]] && a["convention"] === $convention;
sha[path_] := FileHash[path, "SHA256", "HexString"];
digest[expr_] := Hash[expr, "SHA256", "HexString"];
sourceRef[declaring_, path_] := <|"path" -> CanonMethodCard`RelativeArtifactPath[declaring, path], "sha256" -> sha[path]|>;
read[path_] := Module[{a = Quiet @ Check[CanonMethodCard`ReadWLData[path], $Failed]}, require[AssociationQ[a], "INVALID_ARTIFACT", <|"path" -> path|>]; a];
load[task_, input_, key_] := Module[{d, path},
  d = Lookup[task["payload"], key, <||>];
  require[AssociationQ[d] && StringQ[Lookup[d, "path", None]], "MISSING_ARTIFACT", <|"artifact" -> key|>];
  path = CanonMethodCard`ResolveInputPath[input, d["path"]];
  require[FileType[path] === File, "MISSING_ARTIFACT", <|"artifact" -> key|>];
  If[KeyExistsQ[d, "sha256"], require[sha[path] === d["sha256"], "SOURCE_HASH_MISMATCH", <|"artifact" -> key|>]];
  {read[path], path}
];
sameIdentity[a_, b_] := require[identity[a] === identity[b], "IDENTITY_OR_FRAME_MISMATCH"];
exactZero[q_] := TrueQ[FullSimplify[Together[q]] === 0];
exactDataQ[data_] := FreeQ[data, _Real | (z_Complex /; Precision[z] =!= Infinity) | Indeterminate | _DirectedInfinity | Undefined];
rationalQ[q_] := IntegerQ[q] || Head[q] === Rational;
finiteNumberQ[q_] := NumberQ[N[q]] && FreeQ[q, Indeterminate | _DirectedInfinity];
value[q_] := If[StringQ[q], ToExpression[q, InputForm], q];

arithmetic[task_] := Module[{a, mode},
  a = Lookup[task["payload"], "arithmetic", <|"mode" -> "exact"|>];
  require[AssociationQ[a], "INVALID_ARITHMETIC"];
  mode = Lookup[a, "mode", None];
  require[MemberQ[{"exact", "high_precision"}, mode], "INVALID_ARITHMETIC"];
  If[mode === "exact", Return[<|"mode" -> "exact"|>]];
  require[And @@ (KeyExistsQ[a, #] & /@ {"precision", "residual_tolerance", "rank_tolerance", "recognition_tolerance", "max_denominator", "max_numerator"}), "INVALID_ARITHMETIC"];
  a = Join[a, AssociationMap[value[a[#]] &, {"residual_tolerance", "rank_tolerance", "recognition_tolerance"}]];
  require[IntegerQ[a["precision"]] && a["precision"] >= 30 &&
    AllTrue[Lookup[a, {"residual_tolerance", "rank_tolerance", "recognition_tolerance"}], NumberQ[#] && 0 < # < 1 &] &&
    AllTrue[Lookup[a, {"max_denominator", "max_numerator"}], IntegerQ[#] && # > 0 &], "INVALID_ARITHMETIC"];
  a
];
numbers[data_, a_] := If[a["mode"] === "exact", data, N[data, a["precision"]]];
inputPrecision[data_, a_] := If[a["mode"] === "exact",
  require[exactDataQ[data], "INEXACT_DATA_IN_EXACT_MODE"],
  require[AllTrue[Cases[data, _Real | _Complex, Infinity], Precision[#] >= a["precision"] &], "INSUFFICIENT_INPUT_PRECISION"]
];
residualOK[delta_, target_, a_] := If[Flatten[delta] === {}, True, If[a["mode"] === "exact",
  AllTrue[Flatten[delta], exactZero],
  TrueQ[Max[Abs[Flatten[N[delta, a["precision"]]]]/(1 + Abs[Flatten[N[target, a["precision"]]]])] <= a["residual_tolerance"]]
]];
entries[m_] := Most[ArrayRules[m]];
storedValues[matrices_] := Flatten[(Last /@ entries[#]) & /@ matrices];
sparseZeroQ[m_] := AllTrue[Last /@ ArrayRules[SparseArray[m]], exactZero];
sparseResidualOK[delta_, target_, a_] := And @@ MapThread[Function[{d, t}, Module[{rules = entries[d], positions},
  positions = First /@ rules;
  If[positions === {}, True, residualOK[Last /@ rules, Extract[t, positions], a]]
]], {delta, target}];
pivots[m_, a_] := Module[{rr, p},
  rr = If[a["mode"] === "exact", RowReduce[m], RowReduce[m, Tolerance -> a["rank_tolerance"]]];
  DeleteCases[Table[
    p = FirstPosition[row, q_ /; If[a["mode"] === "exact", !exactZero[q], TrueQ[Abs[q] > a["rank_tolerance"]]], Missing[], {1}, Heads -> False];
    If[MissingQ[p], Nothing, First[p]], {row, rr}], Nothing]
];
scaled[m_, a_] := Module[{scales},
  scales = If[a["mode"] === "exact", ConstantArray[1, Length[First[m]]], If[TrueQ[# == 0], 1, #] & /@ (Max[Abs[#]] & /@ Transpose[m])];
  {Transpose[Transpose[m]/scales], scales}
];

sampleSet[task_, input_] := Module[{set, path, entries, paths, ids},
  {set, path} = load[task, input, "sample_set"];
  require[Lookup[set, "schema", None] === "canon-neu/de-sample-set/v1" && validIdentity[set], "INVALID_SAMPLE_SET"];
  require[ListQ[Lookup[set, "training", None]] && set["training"] =!= {} &&
    ListQ[Lookup[set, "validation", None]] && ListQ[Lookup[set, "blind", {}]], "INVALID_SAMPLE_ROLES"];
  entries = Join[set["training"], set["validation"], Lookup[set, "blind", {}]];
  require[AllTrue[entries, AssociationQ[#] && StringQ[Lookup[#, "id", None]] && StringQ[Lookup[#, "path", None]] &], "INVALID_SAMPLE_ROLES"];
  ids = Lookup[entries, "id"]; paths = CanonMethodCard`ResolveInputPath[path, #["path"]] & /@ entries;
  require[DuplicateFreeQ[ids] && DuplicateFreeQ[paths], "SAMPLE_ROLE_OVERLAP"];
  {set, path}
];
readSamples[set_, setPath_, roles_, a_] := Module[{records, n = None, sample, path, matrices, reduced, point, output = {}, points = {}},
  records = Flatten[Table[Append[#, "role" -> role] & /@ Lookup[set, role, {}], {role, roles}], 1];
  Do[
    path = CanonMethodCard`ResolveInputPath[setPath, r["path"]];
    require[FileType[path] === File, "MISSING_SAMPLE", <|"id" -> r["id"]|>];
    If[KeyExistsQ[r, "sha256"], require[sha[path] === r["sha256"], "SOURCE_HASH_MISMATCH", <|"id" -> r["id"]|>]];
    sample = read[path];
    require[Lookup[sample, "schema", None] === "canon-neu/de-sample/v1" && validIdentity[sample], "INVALID_SAMPLE", <|"id" -> r["id"]|>];
    sameIdentity[sample, set];
    point = Lookup[sample, "point", None];
    require[MatchQ[point, {__Rule}] && First /@ point === set["variables"] &&
      exactDataQ[Last /@ point] && AllTrue[Last /@ point, finiteNumberQ], "INVALID_EXACT_POINT", <|"id" -> r["id"]|>];
    AppendTo[points, RootReduce[Last /@ point]];
    matrices = Lookup[sample, "matrices", {}];
    require[ListQ[matrices] && Length[matrices] === Length[set["variables"]] && AllTrue[matrices, MatrixQ], "INCOMPLETE_MATRICES", <|"id" -> r["id"]|>];
    If[n === None, n = Length[First[matrices]]];
    require[n > 0 && AllTrue[matrices, Dimensions[#] === {n, n} &], "INCOMPLETE_MATRICES", <|"id" -> r["id"]|>];
    matrices = SparseArray /@ matrices;
    require[AllTrue[matrices, TrueQ[Last[Last[ArrayRules[#]]] == 0] &], "NONZERO_SPARSE_DEFAULT", <|"id" -> r["id"]|>];
    reduced = Map[Together[#/set["regulator"]] &, matrices, {3}];
    If[!FreeQ[storedValues[reduced], set["regulator"]], stop["INCONCLUSIVE", "EPSILON_NOT_FACTORIZED", <|"id" -> r["id"], "scope" -> "symbolic regulator dependence at this point"|>]];
    require[AllTrue[storedValues[reduced], finiteNumberQ], "UNRESOLVED_POINT_COEFFICIENT", <|"id" -> r["id"]|>];
    inputPrecision[storedValues[reduced], a];
    AppendTo[output, Join[r, <|"absolute_path" -> path, "point" -> point, "reduced" -> reduced|>]], {r, records}];
  require[DuplicateFreeQ[points], "SAMPLE_ROLE_OVERLAP", <|"reason" -> "duplicate exact points, including differently named files"|>];
  output
];
rawLetters[task_, input_, set_] := Module[{letters, path},
  {letters, path} = load[task, input, "raw_letters"];
  require[Lookup[letters, "schema", None] === "canon-neu/raw-letters/v1" && validIdentity[letters], "INVALID_RAW_LETTERS"];
  sameIdentity[letters, set];
  require[ListQ[Lookup[letters, "letters", None]] && letters["letters"] =!= {} &&
    ListQ[Lookup[letters, "labels", None]] && Length[letters["labels"]] === Length[letters["letters"]] &&
    AllTrue[letters["labels"], StringQ] && DuplicateFreeQ[letters["labels"]] &&
    FreeQ[letters["letters"], _Log] && exactDataQ[letters["letters"]] && FreeQ[letters["letters"], set["regulator"]], "INVALID_RAW_LETTERS"];
  {letters, path}
];
design[gradient_, samples_, a_] := Module[{m},
  m = Join @@ ((gradient /. #["point"]) & /@ samples);
  require[AllTrue[Flatten[m], finiteNumberQ], "SINGULAR_LETTER_POINT"];
  numbers[m, a]
];
activePositions[samples_] := Union @@ (First /@ entries[#] & /@ Join @@ (#["reduced"] & /@ samples));
rhs[samples_, positions_, a_] := Module[{matrices = Join @@ (#["reduced"] & /@ samples)},
  If[positions === {}, ConstantArray[{}, Length[matrices]], numbers[Extract[#, positions] & /@ matrices, a]]
];
writeArtifact[data_, out_, filename_, key_] := Module[{path},
  path = CanonMethodCard`WriteWLArtifact[data, out, filename];
  require[StringQ[path], "OUTPUT_EXISTS_OR_UNWRITABLE"];
  <|key -> <|"type" -> "mathematica-expression", "path" -> filename, "sha256" -> sha[path]|>|>
];

fit[task_, input_, out_] := Module[
  {set, setPath, letters, letterPath, a, samples, gradient, m, y, z, scales, cols, rows, c, full, residues,
   reconstruction, path, n, fitRank, sources, matrices, atilde, positions},
  a = arithmetic[task]; {set, setPath} = sampleSet[task, input]; {letters, letterPath} = rawLetters[task, input, set];
  (* Fitting does not read validation or blind files, even for rank selection. *)
  samples = readSamples[set, setPath, {"training"}, a];
  gradient = Table[Together[D[w, x]/w], {x, set["variables"]}, {w, letters["letters"]}];
  positions = activePositions[samples];
  m = design[gradient, samples, a]; y = rhs[samples, positions, a]; {z, scales} = scaled[m, a];
  cols = pivots[z, a]; fitRank = Length[cols];
  If[fitRank === 0 || Length[z] <= fitRank, stop["INCONCLUSIVE", "INSUFFICIENT_TRAINING_RANK", <|"training_rows" -> Length[z], "rank" -> fitRank, "letters" -> Length[letters["letters"]]|>]];
  rows = pivots[Transpose[z[[All, cols]]], a];
  c = If[positions === {}, ConstantArray[{}, fitRank], Quiet @ Check[LinearSolve[z[[rows, cols]], y[[rows]]], $Failed]];
  require[ListQ[c] && Length[c] === fitRank && AllTrue[c, ListQ[#] && Length[#] === Length[positions] &], "LINEAR_SOLVE_FAILED"];
  c = MapThread[#1/#2 &, {c, scales[[cols]]}];
  If[positions =!= {} && !residualOK[m[[All, cols]] . c - y, y, a], stop["INCONCLUSIVE", "MISSING_LETTERS_OR_INCONSISTENT_TRAINING", <|"rank" -> fitRank, "training_rows" -> Length[z]|>]];
  c = If[a["mode"] === "exact", Map[RootReduce, c, {2}], Map[Rationalize[#, a["recognition_tolerance"]] &, c, {2}]];
  If[!AllTrue[Flatten[c], rationalQ] || (a["mode"] === "high_precision" &&
    !AllTrue[Flatten[c], Denominator[#] <= a["max_denominator"] && Abs[Numerator[#]] <= a["max_numerator"] &]),
    stop["INCONCLUSIVE", "RATIONAL_RECOGNITION_FAILED"]];
  If[positions =!= {} && !residualOK[m[[All, cols]] . c - y, y, a], stop["INCONCLUSIVE", "MISSING_LETTERS_OR_INCONSISTENT_TRAINING", <|"rank" -> fitRank, "training_rows" -> Length[z]|>]];
  n = Length[First[samples]["reduced"][[1]]];
  full = ConstantArray[0, {Length[letters["letters"]], Length[positions]}]; full[[cols]] = c;
  residues = SparseArray[Thread[positions -> #], {n, n}] & /@ full;
  matrices = Table[set["regulator"] Total[MapThread[#1 #2 &, {residues, gradient[[k]]}]], {k, Length[set["variables"]]}];
  atilde = Total[MapThread[#1 Log[#2] &, {residues, letters["letters"]}]];
  path = FileNameJoin[{out, "reconstruction.wl"}];
  sources = <|"sample_set" -> sourceRef[path, setPath], "raw_letters" -> sourceRef[path, letterPath],
    "training" -> (Join[<|"id" -> #["id"]|>, sourceRef[path, #["absolute_path"]]] & /@ samples)|>;
  reconstruction = Join[identity[set], <|"schema" -> "canon-neu/dlog-reconstruction/v1", "labels" -> letters["labels"],
    "letters" -> letters["letters"], "residue_matrices" -> residues, "residue_digest" -> digest[residues],
    "matrices" -> matrices, "Atilde" -> atilde, "matrix_shape" -> {n, n}, "arithmetic" -> a,
    "independent_columns" -> cols, "rank" -> fitRank, "sources" -> sources,
    "evidence" -> <|"training_ids" -> Lookup[samples, "id"], "training_rows" -> Length[z],
      "full_matrix_training_match" -> True, "epsilon_factorized_at_training_points" -> True, "active_training_positions" -> positions,
      "column_independence_scope" -> "training samples only; excluded columns need not be globally redundant",
      "heldout_checked" -> False, "boundary" -> $boundary|>|>];
  <|"status" -> "PROVISIONAL", "code" -> "DLOG_RECONSTRUCTED", "artifacts" -> writeArtifact[reconstruction, out, "reconstruction.wl", "reconstruction"],
    "summary" -> <|"rank" -> fitRank, "letters" -> Length[residues], "training_samples" -> Length[samples], "all_matrix_positions" -> n n,
      "fitted_nonzero_positions" -> Length[positions], "heldout_checked" -> False, "evidence_boundary" -> $boundary|>|>
];

check[task_, input_, out_] := Module[
  {set, setPath, letters, letterPath, cand, candPath, a, samples, train, heldout, gradient, residues, n,
   trainDesign, allDesign, trainRank, allRank, predicted, expectedMatrices, expectedAtilde, checked = {}, report, path, source, normalized},
  {set, setPath} = sampleSet[task, input]; {letters, letterPath} = rawLetters[task, input, set];
  {cand, candPath} = load[task, input, "reconstruction"];
  require[Lookup[cand, "schema", None] === "canon-neu/dlog-reconstruction/v1" && validIdentity[cand], "INVALID_RECONSTRUCTION"];
  sameIdentity[cand, set];
  require[Length[set["validation"]] > 0, "MISSING_VALIDATION"];
  require[Lookup[cand, "letters", None] === letters["letters"] && Lookup[cand, "labels", None] === letters["labels"], "RAW_LETTER_BINDING_MISMATCH"];
  Do[source = cand["sources", item[[1]]];
    require[source["sha256"] === sha[item[[2]]] && CanonMethodCard`ResolveInputPath[candPath, source["path"]] === item[[2]], "SOURCE_BINDING_MISMATCH", <|"artifact" -> item[[1]]|>],
    {item, {{"sample_set", setPath}, {"raw_letters", letterPath}}}];
  (* Use the frozen declared arithmetic, never a weakened checker tolerance. *)
  a = arithmetic[<|"payload" -> <|"arithmetic" -> cand["arithmetic"]|>|>];
  If[KeyExistsQ[task["payload"], "arithmetic"], require[arithmetic[task] === a, "ARITHMETIC_BINDING_MISMATCH"]];
  samples = readSamples[set, setPath, {"training", "validation", "blind"}, a];
  train = Select[samples, #["role"] === "training" &]; heldout = Select[samples, #["role"] =!= "training" &];
  require[Length[cand["sources", "training"]] === Length[train], "SOURCE_BINDING_MISMATCH"];
  Do[source = cand["sources", "training"][[i]];
    require[source["id"] === train[[i]]["id"] && source["sha256"] === sha[train[[i]]["absolute_path"]] &&
      CanonMethodCard`ResolveInputPath[candPath, source["path"]] === train[[i]]["absolute_path"], "SOURCE_BINDING_MISMATCH"], {i, Length[train]}];
  n = Length[First[train]["reduced"][[1]]]; residues = Lookup[cand, "residue_matrices", {}];
  require[Length[residues] === Length[letters["letters"]] && AllTrue[residues, Head[#] === SparseArray && Dimensions[#] === {n, n} &&
    TrueQ[Last[Last[ArrayRules[#]]] == 0] && AllTrue[Last /@ ArrayRules[#], rationalQ] &] &&
    Lookup[cand, "matrix_shape", None] === {n, n}, "INCOMPLETE_RESIDUE_MATRICES"];
  require[a["mode"] === "exact" ||
    AllTrue[storedValues[residues], Denominator[#] <= a["max_denominator"] &&
      Abs[Numerator[#]] <= a["max_numerator"] &], "RATIONAL_RECOGNITION_BOUND_EXCEEDED"];
  If[digest[residues] =!= Lookup[cand, "residue_digest", None], stop["FAIL", "COEFFICIENT_BINDING_MISMATCH"]];
  (* Independent differentiation from original analytic definitions; no fitted design cache is loaded. *)
  gradient = Table[Together[D[Log[w], x]], {x, set["variables"]}, {w, letters["letters"]}];
  trainDesign = design[gradient, train, a]; allDesign = design[gradient, samples, a];
  trainRank = Length[pivots[First[scaled[trainDesign, a]], a]];
  allRank = Length[pivots[First[scaled[allDesign, a]], a]];
  If[trainRank =!= allRank || Length[trainDesign] <= trainRank, stop["INCONCLUSIVE", "INSUFFICIENT_TRAINING_RANK", <|"training_rank" -> trainRank, "all_samples_rank" -> allRank|>]];
  require[cand["rank"] === trainRank, "RANK_BINDING_MISMATCH"];
  normalized = residues;
  expectedMatrices = Table[set["regulator"] Total[MapThread[#1 #2 &, {normalized, gradient[[k]]}]], {k, Length[set["variables"]]}];
  expectedAtilde = Total[MapThread[#1 Log[#2] &, {normalized, letters["letters"]}]];
  require[Dimensions[Lookup[cand, "matrices", {}]] === {Length[set["variables"]], n, n} &&
    AllTrue[cand["matrices"] - expectedMatrices, sparseZeroQ] &&
    Dimensions[Lookup[cand, "Atilde", {}]] === {n, n} && sparseZeroQ[cand["Atilde"] - expectedAtilde], "EXPLICIT_FORM_BINDING_MISMATCH"];
  Do[
    predicted = Table[Total[MapThread[#1 #2 &, {normalized, gradient[[k]] /. sample["point"]}]], {k, Length[set["variables"]]}];
    If[!sparseResidualOK[predicted - sample["reduced"], sample["reduced"], a],
      stop["FAIL", "RECONSTRUCTION_MISMATCH", <|"id" -> sample["id"], "role" -> sample["role"], "checked_directions" -> Length[set["variables"]], "checked_matrix_positions_per_direction" -> n n|>]];
    AppendTo[checked, <|"id" -> sample["id"], "role" -> sample["role"], "point" -> sample["point"], "epsilon_factorized" -> True,
      "all_directions_and_positions_match" -> True|>], {sample, samples}];
  path = FileNameJoin[{out, "reconstruction-check.wl"}];
  report = Join[identity[set], <|"schema" -> "canon-neu/reconstruction-check/v1", "status" -> "PASS", "code" -> "RECONSTRUCTION_VALIDATED",
    "arithmetic" -> a, "checks" -> checked, "matrix_shape" -> {n, n}, "rank" -> trainRank,
    "sources" -> <|"sample_set" -> sourceRef[path, setPath], "raw_letters" -> sourceRef[path, letterPath], "reconstruction" -> sourceRef[path, candPath],
      "samples" -> (Join[<|"id" -> #["id"], "role" -> #["role"]|>, sourceRef[path, #["absolute_path"]]] & /@ samples)|>,
    "evidence_boundary" -> $boundary, "global_gauge_checked" -> False, "alphabet_complete" -> False|>];
  <|"status" -> "PASS", "code" -> "RECONSTRUCTION_VALIDATED", "artifacts" -> writeArtifact[report, out, "reconstruction-check.wl", "reconstruction_check"],
    "summary" -> <|"training_samples" -> Length[train], "validation_samples" -> Length[set["validation"]], "blind_samples" -> Length[Lookup[set, "blind", {}]],
      "checked_matrix_entries" -> Length[samples] Length[set["variables"]] n n, "evidence_boundary" -> $boundary|>|>
];

propose[task_, input_, out_] := Module[{forms, formsPath, data, rational, candidates, budget, artifact, path, eps, vars},
  {forms, formsPath} = load[task, input, "one_forms"];
  require[Lookup[forms, "schema", None] === "canon-neu/analytic-one-forms/v1" && validIdentity[forms], "INVALID_ONE_FORMS"];
  vars = forms["variables"]; eps = forms["regulator"]; data = Lookup[forms, "one_forms", {}];
  require[ListQ[data] && data =!= {} && AllTrue[data, ListQ[#] && Length[#] === Length[vars] &] && FreeQ[data, _Log] && exactDataQ[data] && FreeQ[data, eps], "INVALID_ONE_FORMS"];
  budget = Lookup[task["payload"], "max_letters", 32]; require[IntegerQ[budget] && budget > 0, "INVALID_LETTER_BUDGET"];
  rational = Select[Flatten[data], CanonMethodCard`ExactRationalExpressionQ];
  candidates = Join[Lookup[forms, "seed_letters", {}], CanonMethodCard`DLogAlphabet[{eps rational}, vars, eps], CanonMethodCard`QuadraticRootLetters[data, vars]];
  candidates = DeleteDuplicates @ Select[candidates, FreeQ[#, _Log] && exactDataQ[#] && FreeQ[#, eps] && !FreeQ[#, Alternatives @@ vars] &];
  If[candidates === {}, stop["INCONCLUSIVE", "NO_LETTERS_PROPOSED"]];
  candidates = Take[candidates, UpTo[budget]]; path = FileNameJoin[{out, "raw-letters.wl"}];
  artifact = Join[identity[forms], <|"schema" -> "canon-neu/raw-letters/v1", "labels" -> Table["L" <> ToString[i], {i, Length[candidates]}], "letters" -> candidates,
    "proposal" -> <|"source" -> sourceRef[path, formsPath], "methods" -> {"DLogAlphabet rational pole factors", "QuadraticRootLetters norm ratios", "supplied seed letters"},
      "max_letters" -> budget, "scope" -> "bounded supplied analytic one-forms; no completeness or dlog-span proof", "b_wedge_b_completion_implemented" -> False|>|>];
  <|"status" -> "PROVISIONAL", "code" -> "LETTERS_PROPOSED", "artifacts" -> writeArtifact[artifact, out, "raw-letters.wl", "raw_letters"],
    "summary" -> <|"letter_count" -> Length[candidates], "max_letters" -> budget, "span_checked" -> False, "method_limit" -> "supply further exact analytic one-forms or seed letters for unsupported completion"|>|>
];

RunStep[input_String, out_String] := Module[{raw, task, result},
  raw = Quiet @ Check[Import[input, "RawJSON"], <||>];
  task = CanonMethodCard`ReadTask[input, Lookup[raw, "step", ""]];
  If[FailureQ[task], Return[$Failed]];
  result = Catch[Switch[task["step"],
    "RECONSTRUCT_DLOG", fit[task, input, out],
    "CHECK_RECONSTRUCTION", check[task, input, out],
    "PROPOSE_LETTERS", propose[task, input, out],
    _, stop["ERROR", "UNKNOWN_STEP"]], "dlog-result"];
  CanonMethodCard`WriteResult[task, out, result["status"], result["code"], result["artifacts"], result["summary"]]
];
End[];
EndPackage[];
