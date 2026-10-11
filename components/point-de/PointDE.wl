BeginPackage["CanonPointDE`"];
PreparePoint::usage = "PreparePoint[family, masters, candidates, pointSpec] differentiates symbolic external geometry before point substitution.";
BuildPointDE::usage = "BuildPointDE[prepared, rules] reduces the complete target union and constructs the supplied-frame connection.";
CollectSamples::usage = "CollectSamples[roles, requestFile, outputFile] checks identities and independent point roles, returning a relative sample index.";

Begin["`Private`"];
rat[e_] := Cancel[Together[e]];
need[q_, code_, details_: <||>] := If[!TrueQ[q], Throw[Failure[code, details]]];
finiteExactQ[e_] := FreeQ[e, _Real | (z_Complex /; Precision[z] =!= Infinity) | Indeterminate | _DirectedInfinity | Undefined];
namedHeadQ[e_, name_] := !AtomQ[e] && Head[Head[e]] === Symbol && SymbolName[Head[e]] === name;
identityKeys = {"family_id", "basis_id", "chart_id", "frame_id", "scope", "variables", "regulator"};
convention = "D[basis, variables[[i]]] = matrices[[i]] . basis";
zeroQ[e_] := And @@ (TrueQ[rat[#] === 0] & /@ Flatten[{e}]);

validPointQ[point_, vars_, eps_] := ListQ[point] && Length[point] === Length[vars] &&
  And @@ (MatchQ[#, _Rule] & /@ point) && Sort[First /@ point] === Sort[vars] &&
  And @@ (NumericQ /@ (vars /. point)) && finiteExactQ[vars /. point] && FreeQ[vars /. point, eps];

PreparePoint[family_Association, masterData_Association, candidates_Association, spec_Association] := Catch[Module[
  {vars, eps, point, loops, ext, full, positions, signature, masters, head, n, nv, nl, ns,
   vectors, dvectors, frame, dframe, invFrame, coeff, dcoeff, gram, dgram, pairs, ss, zz,
   ll, le, metric, dmetric, symbols, embedding, dembedding, momentumRow, vc, dvc, bilinear, dbilinear,
   propagators, momenta, den, affine, invAffine, ssRules, dss, metricZ, dmetricZ,
   spValue, spDerivative, externalVector, externalDerivative, atomValue, atomDerivative,
   rows, rSymbolic, atoms, atomSymbols, values, derivatives, atomRules, valueRules,
   evaluate, polynomialIntegral, lifts, fixedLoop, ops, operators, gDerivative,
   expressions, rawDerivatives, masterDerivatives, targets, term, evaluated, r, dr, metadata,
   externalPairs, reductionKinematics},
  need[MemberQ[{"canon-neu/parameterized-family/v1", "canon-neu/twistor-family/v1"}, Lookup[family, "schema", None]], "UNSUPPORTED_FAMILY"];
  If[family["schema"] === "canon-neu/parameterized-family/v1",
    need[Lookup[family, "chart_type", None] === "vectors", "UNSUPPORTED_POINT_DE_CHART",
      <|"supported" -> "four-dimensional external vector chart", "received" -> Lookup[family, "chart_type", None]|>];
    need[ListQ[family["propagator_masses_squared"]] &&
      Length[family["propagator_masses_squared"]] === Length[family["propagator_momenta"]] &&
      zeroQ[family["propagator_masses_squared"]], "UNSUPPORTED_POINT_DE_MASSES",
      <|"supported" -> "symbolically zero internal squared masses"|>]
  ];
  need[Lookup[masterData, "schema", None] === "canon-neu/master-basis/v1", "INVALID_MASTERS"];
  need[Lookup[candidates, "schema", None] === "canon-neu/point-candidates/v1", "INVALID_CANDIDATES"];
  need[Lookup[spec, "schema", None] === "canon-neu/point-spec/v1", "INVALID_POINT_SPEC"];
  vars = family["variables"]; eps = family["regulator"]; point = spec["point"];
  need[validPointQ[point, vars, eps], "INVALID_EXACT_POINT"];
  point = Thread[vars -> (vars /. point)]; nv = Length[vars];
  need[And @@ (StringQ[Lookup[spec, #, None]] & /@ {"family_id", "basis_id", "chart_id", "frame_id"}) &&
    AssociationQ[Lookup[spec, "scope", None]], "MISSING_SAMPLE_IDENTITY"];
  need[family["family_ref"] === masterData["family_ref"] === spec["family_id"], "FAMILY_MISMATCH"];
  need[Lookup[family, "chart_id", spec["chart_id"]] === spec["chart_id"], "CHART_MISMATCH"];
  loops = family["loop_momenta"]; ext = family["external_momenta"];
  full = family["vectors"]; positions = family["external_basis"]; signature = family["metric"];
  masters = masterData["masters"]; n = Length[masters]; nl = Length[loops];
  need[n > 0 && DuplicateFreeQ[masters] && nl > 0 && Dimensions[full] === {Length[ext], 4} && Length[positions] === 4 &&
    signature === {1, -1, -1, -1}, "UNSUPPORTED_EXTERNAL_GEOMETRY"];
  head = Head[First[masters]];
  need[SymbolName[head] === family["integral_head"] && And @@ (Head[#] === head & /@ masters), "INTEGRAL_HEAD_MISMATCH"];
  ns = nl (nl + 1)/2 + 4 nl;
  If[family["schema"] === "canon-neu/parameterized-family/v1",
    momenta = family["propagator_momenta"],
    propagators = family["propagators"];
    need[And @@ (MatchQ[#, Power[_, 2]] & /@ propagators), "INCOMPLETE_PROPAGATOR_COORDINATES"];
    momenta = First /@ propagators
  ];
  need[Length[momenta] === ns &&
    And @@ (Length[#] === ns && VectorQ[List @@ #, IntegerQ] & /@ masters), "INCOMPLETE_PROPAGATOR_COORDINATES"];

  (* External four-vectors are differentiated symbolically, then specialized. *)
  vectors = rat[full /. point]; dvectors = Table[rat[D[full, vars[[k]]] /. point], {k, nv}];
  frame = vectors[[positions]]; dframe = dvectors[[All, positions]];
  invFrame = Quiet[Check[Inverse[frame], $Failed]];
  need[MatrixQ[invFrame] && finiteExactQ[invFrame], "SINGULAR_EXTERNAL_FRAME"];
  coeff = rat[vectors . invFrame];
  dcoeff = Table[rat[(dvectors[[k]] - coeff . dframe[[k]]) . invFrame], {k, nv}];
  gram = rat[frame . DiagonalMatrix[signature] . Transpose[frame]];
  dgram = Table[rat[dframe[[k]] . DiagonalMatrix[signature] . Transpose[frame] +
    frame . DiagonalMatrix[signature] . Transpose[dframe[[k]]]], {k, nv}];

  (* Loop-loop entries remain independent regulated scalar products. *)
  pairs = Flatten[Table[{i, j}, {i, nl}, {j, i, nl}], 1];
  ss = Table[Unique["s$"], {ns}]; zz = Table[Unique["z$"], {ns}];
  ll = Table[ss[[First[FirstPosition[pairs, Sort[{i, j}]]]]], {i, nl}, {j, nl}];
  le = Partition[Drop[ss, Length[pairs]], 4];
  metric = ArrayFlatten[{{ll, le}, {Transpose[le], gram}}];
  dmetric = Table[ArrayFlatten[{{ConstantArray[0, {nl, nl}], ConstantArray[0, {nl, 4}]},
    {ConstantArray[0, {4, nl}], dgram[[k]]}}], {k, nv}];
  symbols = Join[loops, ext];
  embedding = Join[IdentityMatrix[nl + 4][[1 ;; nl]], (Join[ConstantArray[0, nl], #] & /@ coeff)];
  dembedding = Table[Join[ConstantArray[0, {nl, nl + 4}],
    (Join[ConstantArray[0, nl], #] & /@ dcoeff[[k]])], {k, nv}];
  momentumRow[q_] := momentumRow[q] = Module[{row = Coefficient[Expand[q], #] & /@ symbols},
    need[zeroQ[q - row.symbols] && FreeQ[row, Alternatives @@ symbols],
      "NONLINEAR_OR_UNDECLARED_MOMENTUM"]; row];
  vc[q_] := rat[momentumRow[q] /. point] . embedding;
  dvc[q_, k_] := rat[D[momentumRow[q], vars[[k]]] /. point] . embedding +
    rat[momentumRow[q] /. point] . dembedding[[k]];
  bilinear[q_, u_] := vc[q] . metric . vc[u];
  dbilinear[q_, u_, k_] := dvc[q, k] . metric . vc[u] + vc[q] . metric . dvc[u, k] + vc[q] . dmetric[[k]] . vc[u];
  den = Expand[bilinear[#, #] & /@ momenta];
  affine = Table[Coefficient[den[[i]], ss[[j]]], {i, ns}, {j, ns}];
  invAffine = Quiet[Check[Inverse[affine], $Failed]];
  need[MatrixQ[invAffine] && finiteExactQ[invAffine], "SINGULAR_PROPAGATOR_COORDINATES"];
  ssRules = Thread[ss -> rat[invAffine . (zz - (den /. Thread[ss -> 0]))]];
  dss = Table[rat[-invAffine . (dbilinear[#, #, k] & /@ momenta) /. ssRules], {k, nv}];
  metricZ = rat[metric /. ssRules];
  dmetricZ = Table[rat[(dmetric[[k]] + Sum[D[metric, ss[[j]]] dss[[k, j]], {j, ns}]) /. ssRules], {k, nv}];
  spValue[q_, u_] := rat[vc[q] . metricZ . vc[u]];
  spDerivative[q_, u_, k_] := rat[dvc[q, k] . metricZ . vc[u] +
    vc[q] . metricZ . dvc[u, k] + vc[q] . dmetricZ[[k]] . vc[u]];
  externalVector[q_] := Module[{row = momentumRow[q]},
    need[zeroQ[Take[row, nl]], "LOOP_EPSILON_UNSUPPORTED"]; Drop[row, nl].full];
  externalDerivative[q_, k_] := rat[D[externalVector[q], vars[[k]]] /. point];
  atomValue[a_] := Switch[SymbolName[Head[a]],
    "sp", spValue[First[a], Last[a]],
    "Gram", rat[Det[Table[2 spValue[q, u], {q, a[[1]]}, {u, a[[2]]}]]],
    "Eps", need[Length[a] === 4 && FreeQ[a, Alternatives @@ loops], "LOOP_EPSILON_UNSUPPORTED"];
      rat[4 I Det[(externalVector /@ (List @@ a)) /. point]]];
  atomDerivative[a_, k_] := Module[{m, dm}, Switch[SymbolName[Head[a]],
    "sp", spDerivative[First[a], Last[a], k],
    "Gram", m = Table[2 spValue[q, u], {q, a[[1]]}, {u, a[[2]]}];
      dm = Table[2 spDerivative[q, u, k], {q, a[[1]]}, {u, a[[2]]}];
      rat[Sum[Det[ReplacePart[m, j -> dm[[j]]]], {j, Length[m]}]],
    "Eps", m = (externalVector /@ (List @@ a)) /. point;
      dm = externalDerivative[#, k] & /@ (List @@ a);
      rat[4 I Sum[Det[ReplacePart[m, j -> dm[[j]]]], {j, 4}]]]];

  rows = candidates["rows"]; rSymbolic = spec["frame"];
  need[ListQ[rows] && Length[rows] > 0 && Dimensions[rSymbolic] === {Length[rows], Length[rows]}, "INVALID_CANDIDATE_FRAME"];
  atoms = DeleteDuplicates[Cases[{rows, rSymbolic}, a_ /;
    Or @@ (namedHeadQ[a, #] & /@ {"sp", "Gram", "Eps"}), Infinity]];
  atomSymbols = Table[Unique["atom$"], {Length[atoms]}];
  values = atomValue /@ atoms;
  derivatives = Table[atomDerivative[#, k] & /@ atoms, {k, nv}];
  atomRules = Thread[atoms -> atomSymbols]; valueRules = Thread[atomSymbols -> values];
  evaluate[e_] := Module[{t},
    t = e /. atomRules /. (a_ /; namedHeadQ[a, "prop"]) :> zz[[First[a]]];
    {rat[t /. valueRules /. point], Table[rat[(D[t, vars[[k]]] +
      Sum[D[t, atomSymbols[[j]]] derivatives[[k, j]], {j, Length[atoms]}]) /. valueRules /. point], {k, nv}]}];
  polynomialIntegral[e_, indices_] := Module[{cr},
    need[VectorQ[indices, IntegerQ] && Length[indices] === ns && PolynomialQ[e, zz] && finiteExactQ[e], "NONPOLYNOMIAL_NUMERATOR"];
    cr = CoefficientRules[Expand[e], zz];
    Total[(Last[#] Apply[head, indices - First[#]]) & /@ cr]];

  (* Symmetric external lift; loop-loop scalars and transverse components stay free. *)
  lifts = Table[rat[1/2 dgram[[k]] . Inverse[gram]], {k, nv}];
  fixedLoop = Table[Join[ConstantArray[0, Length[pairs]], Flatten[(lifts[[k]] . # & /@ le)]], {k, nv}];
  ops = Table[rat[(dbilinear[#, #, k] & /@ momenta) + affine . fixedLoop[[k]] /. ssRules], {k, nv}];
  operators = Table[Prepend[Coefficient[ops[[k, i]], #] & /@ zz, ops[[k, i]] /. Thread[zz -> 0]], {k, nv}, {i, ns}];
  gDerivative[g_, k_] := Module[{a = List @@ g},
    Total[Flatten[Table[If[a[[i]] === 0, 0, -a[[i]] operators[[k, i, j + 1]]
      Apply[head, a + UnitVector[ns, i] - If[j === 0, ConstantArray[0, ns], UnitVector[ns, j]]]],
      {i, ns}, {j, 0, ns}]]]];
  expressions = {}; rawDerivatives = {};
  Do[
    need[ListQ[row] && Length[row] > 0 && And @@ (AssociationQ /@ row), "INVALID_CANDIDATE_ROW"];
    term = Table[evaluated = evaluate[t["numerator"]];
      {polynomialIntegral[evaluated[[1]], t["indices"]],
       polynomialIntegral[#, t["indices"]] & /@ evaluated[[2]]}, {t, row}];
    AppendTo[expressions, rat[Total[term[[All, 1]]]]];
    AppendTo[rawDerivatives, Table[rat[Total[term[[All, 2, k]]] +
      (Last[expressions] /. (g_ /; Head[g] === head) :> gDerivative[g, k])], {k, nv}]], {row, rows}];
  rawDerivatives = Transpose[rawDerivatives];
  masterDerivatives = Table[rat[gDerivative[#, k]] & /@ masters, {k, nv}];
  targets = Union[masters, Cases[{expressions, rawDerivatives, masterDerivatives}, g_ /; Head[g] === head, Infinity]];
  {r, dr} = evaluate[rSymbolic];
  need[FreeQ[{r, dr}, Alternatives @@ zz] && finiteExactQ[{r, dr}], "LOOP_DEPENDENT_OR_SINGULAR_FRAME"];
  metadata = Join[KeyTake[spec, {"family_id", "basis_id", "chart_id", "frame_id", "scope"}],
    <|"variables" -> vars, "regulator" -> eps, "point" -> point, "source_basis_id" -> masterData["basis_ref"],
      "candidate_basis_id" -> candidates["basis_id"], "frame_expression" -> rSymbolic|>];
  externalPairs = Flatten[Table[{i, j}, {i, 4}, {j, i, 4}], 1];
  reductionKinematics = <|"schema" -> "canon-neu/point-kinematics/v1", "family_id" -> spec["family_id"],
    "variables" -> vars, "point" -> point, "loop_momenta" -> loops, "external_momenta" -> ext[[positions]],
    "propagator_momenta" -> (Expand[vc[#] . Join[loops, ext[[positions]]]] & /@ momenta),
    "scalar_products" -> Thread[(ext[[positions]][[#]] & /@ externalPairs) -> (Extract[gram, #] & /@ externalPairs)]|>;
  Join[metadata, <|"schema" -> "canon-neu/prepared-point/v1", "dimension_rule" -> family["dimension_rule"],
    "masters" -> masters, "expressions" -> expressions, "candidate_derivatives" -> rawDerivatives,
    "master_derivatives" -> masterDerivatives, "frame" -> r, "frame_derivatives" -> dr,
    "operators" -> operators, "targets" -> targets, "reduction_kinematics" -> reductionKinematics, "convention" -> convention|>]
]];

BuildPointDE[p_Association, rules_List] := Catch[Module[
  {masters = p["masters"], head, n, nv, eps, reduced, missing, row, t, q, ak, r, dr, inv,
   projection, projectionDerivatives, matrices, sample, report, pointRules, dispatch, pointCoefficientQ, integrals},
  need[p["schema"] === "canon-neu/prepared-point/v1", "INVALID_PREPARED_POINT"];
  n = Length[masters]; nv = Length[p["variables"]]; eps = p["regulator"];
  need[ListQ[masters] && n > 0 && DuplicateFreeQ[masters] &&
    ListQ[p["variables"]] && nv > 0 && DuplicateFreeQ[p["variables"]] &&
    validPointQ[p["point"], p["variables"], eps] &&
    Dimensions[p["expressions"]] === {n} &&
    Dimensions[p["candidate_derivatives"]] === {nv,n} &&
    Dimensions[p["master_derivatives"]] === {nv,n} &&
    Dimensions[p["frame"]] === {n,n} && Dimensions[p["frame_derivatives"]] === {nv,n,n} &&
    ListQ[p["targets"]], "INVALID_PREPARED_POINT"];
  head = Head[First[masters]];
  need[AllTrue[masters, Head[#] === head && VectorQ[List @@ #, IntegerQ] &], "INVALID_PREPARED_POINT"];
  integrals = DeleteDuplicates @ Cases[{masters,p["expressions"],p["candidate_derivatives"],p["master_derivatives"]},
    g_ /; Head[g] === head, Infinity];
  need[SubsetQ[p["targets"],integrals], "INCOMPLETE_TARGET_UNION"];
  need[AllTrue[rules, MatchQ[#, _Rule] && Head[First[#]] === head &&
      VectorQ[List @@ First[#], IntegerQ] &] && DuplicateFreeQ[First /@ rules], "INVALID_REDUCTION_RULES"];
  pointCoefficientQ[e_] := CanonMethodCard`ExactAlgebraicExpressionQ[e] &&
    FreeQ[e, s_Symbol /; Context[s] =!= "System`" && s =!= eps];
  pointRules = rules /. p["point"];
  dispatch = Dispatch[pointRules];
  reduced = p["targets"] /. dispatch;
  missing = Complement[DeleteDuplicates[Cases[reduced, g_ /; Head[g] === head, Infinity]], masters];
  need[missing === {}, "MISSING_TARGETS", <|"missing" -> missing|>];
  row[e_] := row[e] = Module[{v},
    v = First[CanonMethodCard`IntegralCoefficientRows[
      {e /. dispatch /. p["dimension_rule"]}, masters, head]];
    need[v =!= $Failed && finiteExactQ[v], "NONLINEAR_OR_INEXACT_REDUCTION"];
    need[AllTrue[v, pointCoefficientQ], "UNRESOLVED_POINT_COEFFICIENT"];
    rat[v]];
  (* Check every target, including master derivatives not used by a candidate row. *)
  row /@ p["targets"];
  need[zeroQ[(row /@ masters) - IdentityMatrix[n]], "MASTER_BASIS_CHANGED"];
  t = row /@ p["expressions"];
  q = Table[row /@ p["candidate_derivatives"][[k]], {k, nv}];
  ak = Table[row /@ p["master_derivatives"][[k]], {k, nv}];
  r = p["frame"] /. p["dimension_rule"]; dr = p["frame_derivatives"] /. p["dimension_rule"];
  projection = rat[r . t];
  need[Dimensions[projection] === {n, n}, "RANK_FAILURE", <|"shape" -> Dimensions[projection]|>];
  inv = Quiet[Check[Inverse[projection], $Failed]];
  need[MatrixQ[inv] && finiteExactQ[inv], "RANK_FAILURE"];
  projectionDerivatives = Table[rat[dr[[k]] . t + r . (q[[k]] - t . ak[[k]])], {k, nv}];
  matrices = Table[rat[(dr[[k]] . t + r . q[[k]]) . inv], {k, nv}];
  need[finiteExactQ[{projection, projectionDerivatives, matrices}], "NONFINITE_POINT_DE"];
  need[AllTrue[Flatten[{projection, projectionDerivatives, matrices}], pointCoefficientQ], "UNRESOLVED_POINT_COEFFICIENT"];
  sample = Join[KeyTake[p, Join[identityKeys, {"point", "source_basis_id", "candidate_basis_id", "frame_expression"}]],
    <|"schema" -> "canon-neu/de-sample/v1", "matrices" -> matrices, "convention" -> convention|>];
  report = <|"schema" -> "canon-neu/point-de-check/v1", "target_coverage_complete" -> True,
    "gauge_identity" -> zeroQ[Table[matrices[[k]] . projection - projectionDerivatives[[k]] - projection . ak[[k]], {k, nv}]],
    "epsilon_factorized_at_this_point" -> zeroQ[D[matrices/eps, eps]],
    "scope" -> "Exact supplied reductions and point only; no global canonical or UT acceptance.",
    "masters" -> n, "directions" -> nv, "targets" -> Length[p["targets"]]|>;
  <|"sample" -> sample, "projection" -> <|"schema" -> "canon-neu/point-projection/v1",
    "masters" -> masters, "projection" -> projection, "projection_derivatives" -> projectionDerivatives,
    "master_matrices" -> ak, "convention" -> "basis = projection . masters"|>, "check" -> report|>
]];

CollectSamples[roles_Association, requestFile_String, outputFile_String] := Catch[Module[
  {names = {"training", "validation", "blind"}, entries, sample, paths, reference, shape, points = {}, hashes = <||>, result},
  need[Length[Lookup[roles, "training", {}]] > 0 && Length[Lookup[roles, "validation", {}]] > 0, "MISSING_SAMPLE_ROLES"];
  entries = Flatten[Lookup[roles, names, {}], 1];
  need[And @@ (AssociationQ[#] && StringQ[Lookup[#, "id", None]] && StringQ[Lookup[#, "path", None]] & /@ entries), "INVALID_SAMPLE_ENTRY"];
  paths = CanonMethodCard`ResolveInputPath[requestFile, #["path"]] & /@ entries;
  need[DuplicateFreeQ[Lookup[entries, "id"]] && DuplicateFreeQ[paths], "OVERLAPPING_SAMPLE_ROLES"];
  Do[
    hashes[paths[[i]]] = FileHash[paths[[i]], "SHA256", "HexString"];
    If[KeyExistsQ[entries[[i]], "sha256"],
      need[StringQ[entries[[i,"sha256"]]] && ToLowerCase[entries[[i,"sha256"]]] ===
        hashes[paths[[i]]], "SOURCE_HASH_MISMATCH"]];
    sample = CanonMethodCard`ReadWLData[paths[[i]]];
    need[AssociationQ[sample] && Lookup[sample, "schema", None] === "canon-neu/de-sample/v1", "INVALID_SAMPLE"];
    If[i === 1,
      reference = Lookup[sample, identityKeys]; shape = Dimensions[sample["matrices"]];
      need[Length[shape] === 3 && shape[[1]] === Length[reference[[-2]]] && shape[[2]] === shape[[3]], "INVALID_SAMPLE_SHAPE"];
      result = Join[KeyTake[sample, identityKeys], <|"schema" -> "canon-neu/de-sample-set/v1", "convention" -> convention|>]
    ];
    need[Lookup[sample, identityKeys] === reference && sample["convention"] === convention &&
      Dimensions[sample["matrices"]] === shape && finiteExactQ[sample["matrices"]] &&
      validPointQ[sample["point"], sample["variables"], sample["regulator"]], "SAMPLE_IDENTITY_MISMATCH"];
    AppendTo[points, sample["variables"] /. sample["point"]];
    Clear[sample],
    {i, Length[paths]}
  ];
  need[DuplicateFreeQ[points], "OVERLAPPING_SAMPLE_POINTS"];
  Do[If[KeyExistsQ[roles, role], result[role] = (With[
    {path = CanonMethodCard`ResolveInputPath[requestFile, #["path"]]},
    <|"id" -> #["id"], "path" -> CanonMethodCard`RelativeArtifactPath[outputFile, path],
      "sha256" -> hashes[path]|>] & /@ roles[role])], {role, names}];
  result
]];
End[];
EndPackage[];
