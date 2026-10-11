(* Exact gauge transformations, curvature, epsilon factorization, and candidate checks.
   Loaded inside CanonMethodCard`Private` by MethodCardCore.wl. *)

ZeroMatrixQ[expr_] := MatrixQ[expr] &&
  And @@ (TrueQ[FullSimplify[Together[#]] === 0] & /@ Flatten[expr]);

FermatGaugeIdentityQ[matrices_List, variables_List, transformation_?MatrixQ, target_List] := Module[
  {powers, bases, orders, roots, formal, relations, t, residual},
  powers = DeleteDuplicates @ Cases[{matrices, transformation, target},
    Power[b_, p_Rational] :> {Factor[b], Denominator[p]}, Infinity];
  bases = DeleteDuplicates[First /@ powers];
  orders = (LCM @@ Cases[powers, {#, n_} :> n]) & /@ bases;
  roots = Table[Unique["root$"], {Length[bases]}];
  formal[expr_] := expr /. Power[b_, p_Rational] /;
      MemberQ[bases, Factor[b]] :> With[
        {i = First @ FirstPosition[bases, Factor[b]]}, roots[[i]]^(p orders[[i]])];
  relations = MapThread[#1 -> #1^#2 - formal[#3] &, {roots, orders, bases}];
  t = formal[transformation];
  And @@ Table[
    residual = Fermatica`FPlus[
      Fermatica`FDot[formal[matrices[[i]]], t],
      -formal[D[transformation, variables[[i]]]],
      -Fermatica`FDot[t, formal[target[[i]]]]];
    residual = Fermatica`FQuolyMod[residual, relations];
    And @@ (TrueQ[# === 0] & /@ Flatten[residual]),
    {i, Length[variables]}]
];

GaugeTransform[matrices_List, variables_List, transformation_?MatrixQ] :=
 With[{inverse = Inverse[transformation]},
  MapThread[
    Map[Together, inverse.(#1.transformation - D[transformation, #2]), {2}] &,
    {matrices, variables}
  ]];

FlatConnectionQ[matrices_List, variables_List] := With[
  {sparse = SparseArray /@ matrices},
  And @@ (Function[pair, With[{i = pair[[1]], j = pair[[2]]},
    ZeroMatrixQ[D[matrices[[j]], variables[[i]]] -
      D[matrices[[i]], variables[[j]]] +
      Normal[sparse[[j]].sparse[[i]] - sparse[[i]].sparse[[j]]]]
  ]] /@ Subsets[Range[Length[variables]], {2}])
];

EpsilonFactorizedQ[matrices_List, regulator_Symbol] :=
  And @@ (FreeQ[Together[#/regulator], regulator] & /@ Flatten[matrices]);

CheckCoreCandidate[
  candidate_Association,
  matrices_List,
  variables_List,
  regulator_Symbol,
  index_Integer,
  inverseProposal_:Automatic, domain_:"exact-algebraic-functions"
] := Module[
  {candidateID, construction, transformation, declared, computed, residuals,
    invertible, exactGauge, flat, epsilonForm, reasons, certifiedInverse,
    dimension, coefficientQ, reject, inverseVerification = "symbolic_inverse"},
  candidateID = candidate["candidate_id"];
  reject[reason_] := <|"candidate_id" -> candidateID, "index" -> index,
    "pass" -> False, "invertible" -> False, "rejection_signature" -> {reason}|>;
  construction = candidate["construction_rejection"];
  If[StringQ[construction], Return[<|
    "candidate_id" -> candidateID, "index" -> index, "pass" -> False,
    "invertible" -> False, "rejection_signature" -> {construction}|>]];
  transformation = candidate["transformation"];
  declared = candidate["transformed_matrices"];
  dimension = Length[First[matrices]];
  If[!squareMatrixQ[transformation, dimension] ||
    !matrixListShapeQ[declared, Length[variables], dimension],
    Return[reject["candidate_shape_invalid"]]];
  coefficientQ = If[domain === "exact-rational-functions",
    ExactRationalExpressionQ, ExactAlgebraicExpressionQ];
  If[!AllTrue[Flatten[{transformation, declared}], coefficientQ],
    Return[reject["coefficient_domain_invalid"]]];
  (* A supplied row matrix is only a proposal. Both exact inverse identities
     must hold before it replaces symbolic determinant/inverse construction. *)
  certifiedInverse = MatrixQ[inverseProposal] &&
    Dimensions[inverseProposal] === Dimensions[transformation] &&
    ZeroMatrixQ[transformation.inverseProposal - IdentityMatrix[Length[transformation]]] &&
    ZeroMatrixQ[inverseProposal.transformation - IdentityMatrix[Length[transformation]]];
  invertible = TrueQ[certifiedInverse] || TrueQ[Together[Det[transformation]] =!= 0];
  If[!invertible, Return[<|
    "candidate_id" -> candidateID, "index" -> index, "pass" -> False,
    "invertible" -> False, "rejection_signature" -> {"singular_transformation"}|>]];
  If[TrueQ[certifiedInverse],
    inverseVerification = "two_sided_exact_identity";
    residuals = MapThread[#1.transformation - D[transformation, #2] -
      transformation.#3 &, {matrices, variables, declared}];
    exactGauge = And @@ (ZeroMatrixQ /@ residuals);
    (* The independently verified invertibility and exact source equation
       uniquely determine B. No provider flag or numerical test is trusted. *)
    computed = If[exactGauge, declared, MapThread[
      Map[Together, inverseProposal.(#1.transformation - D[transformation, #2]), {2}] &,
      {matrices, variables}]],
    computed = GaugeTransform[matrices, variables, transformation];
    residuals = MapThread[Map[Together, #1 - #2, {2}] &, {computed, declared}];
    exactGauge = And @@ (ZeroMatrixQ /@ residuals)
  ];
  flat = FlatConnectionQ[computed, variables];
  epsilonForm = EpsilonFactorizedQ[computed, regulator];
  reasons = Pick[
    {"gauge_residual", "nonflat_connection", "not_epsilon_factorized"},
    Not /@ {exactGauge, flat, epsilonForm}];
  <|
    "candidate_id" -> candidateID, "index" -> index, "pass" -> (reasons === {}),
    "invertible" -> invertible,
    "inverse_verification" -> inverseVerification,
    "exact_gauge" -> exactGauge,
    "flat_connection" -> flat,
    "epsilon_factorized" -> epsilonForm,
    "rejection_signature" -> reasons,
    "transformation" -> transformation,
    "transformed_matrices" -> computed
  |>
];
