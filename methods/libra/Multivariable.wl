(* A finite directional proposal with one exact, shared regulator intertwiner. *)
BeginPackage["CanonLibraMultivariable`"];
Propose::usage = "Propose[cut,directions,hierarchy,maxEquations,maxSeconds,factorOptions] proposes a shared rational core transformation.";
Begin["`Private`"];

SetAttributes[publicCall, HoldFirst];
publicCall[expression_] := CheckAbort[Quiet[Check[expression, $Failed]], $Aborted];

rationalMatrixQ[m_, n_] := MatrixQ[m] && Dimensions[m] === {n, n} &&
  And @@ (CanonMethodCard`ExactRationalExpressionQ /@ Flatten[m]);
connectionQ[matrices_, count_, n_] := ListQ[matrices] && Length[matrices] === count &&
  And @@ (rationalMatrixQ[#, n] & /@ matrices);
failedCallQ[value_] := MemberQ[{$Failed, $Aborted}, value] || FailureQ[value];

invertibleMatrixQ[m_, n_] := Module[{determinant},
  If[!rationalMatrixQ[m, n], Return[False]];
  determinant = publicCall[Together[Det[m]]];
  CanonMethodCard`ExactRationalExpressionQ[determinant] && determinant =!= 0
];

connectionMask[matrices_, n_] := Module[{adjacency},
  adjacency = Table[Boole[AnyTrue[matrices,
    !CanonMethodCard`ZeroMatrixQ[{{#[[i, j]]}}] &]], {i, n}, {j, n}];
  publicCall[Libra`TClosure[adjacency]]
];

(* Clear denominators before collecting every declared kinematic monomial.
   The budget counts nonzero coefficients before deduplication. *)
coefficientEquations[equations_, variables_, unknowns_, budget_] := Module[
  {coefficients = {}, count = 0, value, numerator, terms, outcome,
    tag = Unique["coefficientStop"]},
  outcome = Catch[Do[
    value = publicCall[Together[equation]];
    If[value === $Failed || !FreeQ[Denominator[value], Alternatives @@ unknowns],
      Throw[<|"success" -> False, "limit_code" -> "INVALID_LINEAR_EQUATIONS"|>, tag]];
    numerator = Numerator[value];
    If[!PolynomialQ[numerator, variables],
      Throw[<|"success" -> False, "limit_code" -> "NONPOLYNOMIAL_EQUATIONS"|>, tag]];
    terms = publicCall[Last /@ CoefficientRules[numerator, variables]];
    If[!ListQ[terms],
      Throw[<|"success" -> False, "limit_code" -> "COEFFICIENT_EXTRACTION"|>, tag]];
    count += Length[terms];
    If[count > budget,
      Throw[<|"success" -> False, "limit_code" -> "EQUATION_BUDGET",
        "equation_count" -> count|>, tag]];
    coefficients = Join[coefficients, terms],
    {equation, equations}], tag];
  If[AssociationQ[outcome], Return[outcome]];
  coefficients = DeleteDuplicates[DeleteCases[coefficients, 0]];
  <|"success" -> True, "equation_count" -> count,
    "original_equations" -> coefficients,
    (* Remove only exact numeric content, retaining symbolic factors and the
       first-occurrence order. Check the solution against the originals. *)
    "equations" -> DeleteDuplicates[Last[FactorTermsList[#]] & /@ coefficients]|>
];

Propose[cut_Association, directions_List, hierarchy_, maxEquations_Integer, maxSeconds_,
    factorOptions_Association] := Module[
  {variables = cut["variables"], regulator = cut["regulator"],
    n = Length[cut["basis"]], source = cut["matrices"], ds,
    matrices, cumulative, trace, retained, nextCumulative, nextTrace,
    stage = "initialize", evidence, stopped, stop,
    tag = Unique["libraStop"], result, t, direction, fuchsian, normalized,
    reference, mask = Automatic, maskEvidence = <||>, raw, equations, template,
    unknowns, coefficients, solution, free, substitutions, factor, inverse,
    snapshot, callResult, equationCount = 0, solverEquationCount = Null, epsilonForm, selection,
    referenceValue = factorOptions["reference_regulator"], factorEvidence = <||>},
  matrices = source;
  cumulative = IdentityMatrix[n];
  trace = {};
  retained = <|"transformation" -> cumulative, "transformed_matrices" -> matrices,
    "steps" -> trace|>;
  evidence[] := Join[<|"strategy" -> "directional-shared-coefficients",
    "direction_sequence" -> directions,
    "completed_directions" -> Length[retained["steps"]], "steps" -> retained["steps"],
    "variables" -> variables, "regulator" -> regulator,
    "source_basis" -> cut["basis"], "stopped_stage" -> stage,
    "transformation" -> retained["transformation"],
    "transformed_matrices" -> retained["transformed_matrices"],
    "factorization_max_equations" -> maxEquations,
    "max_wall_seconds" -> maxSeconds, "factor_out_mu" -> referenceValue,
    "reference_regulator_exact" -> factorOptions["reference_regulator_exact"],
    "use_fermatica" -> False, "dependent_rows" -> maskEvidence,
    "factorization_equation_count" -> equationCount,
    "factorization_solver_equation_count" -> solverEquationCount|>, factorEvidence,
    KeyTake[retained, {"shared_factor"}]];
  stopped[code_, reason_, extra_:<||>] := <|"success" -> False,
    "reason" -> reason, "evidence" -> Join[evidence[],
      <|"limit_code" -> code, "timed_out" -> False|>, extra]|>;
  stop[code_, reason_, extra_:<||>] := Throw[stopped[code, reason, extra], tag];
  result = TimeConstrained[Catch[
    matrices = Map[Together, source, {3}];
    callResult = publicCall[Libra`NewDSystem[ds, Thread[variables -> matrices], Print -> False]];
    snapshot = publicCall[ds[#] & /@ variables];
    If[failedCallQ[callResult] || !connectionQ[snapshot, Length[variables], n],
      stop["INITIALIZATION", "Libra could not initialize the full connection"]];
    Do[
      stage = "directional-fuchsify";
      direction = variables[[index]];
      t = publicCall[Libra`Fuchsify[ds, direction]];
      If[t === $Aborted, stop["ABORTED", "Libra aborted a directional Fuchsify call"]];
      If[!invertibleMatrixQ[t, n],
        stop["FUCHSIFY_TRANSFORMATION", "Libra produced no invertible rational directional transformation"]];
      callResult = publicCall[Libra`Transform[ds, t, Print -> False,
          Fermatica`UseFermat -> False]];
      snapshot = publicCall[Map[Together, ds[#] & /@ variables, {3}]];
      If[failedCallQ[callResult] || !connectionQ[snapshot, Length[variables], n],
        stop["APPLY_DIRECTION", "Libra could not apply a directional transformation"]];
      nextCumulative = Map[Together, cumulative.t, {2}];
      nextTrace = Append[trace, <|"direction_index" -> index, "variable" -> direction,
        "transformation" -> t|>];
      (* Commit a complete snapshot at once; a timeout retains the previous one. *)
      retained = <|"transformation" -> nextCumulative, "transformed_matrices" -> snapshot,
        "steps" -> nextTrace|>;
      {matrices, cumulative, trace} = {snapshot, nextCumulative, nextTrace},
      {index, directions}];
    stage = "joint-fuchsian-check";
    fuchsian = MapThread[TrueQ[publicCall[Libra`FuchsianQ[#1, #2]]] &,
      {matrices, variables}];
    If[!And @@ fuchsian,
      stop["NOT_JOINTLY_FUCHSIAN", "The requested directions did not yield a jointly Fuchsian connection",
        <|"directional_fuchsian" -> fuchsian|>]];
    normalized = Map[Together, matrices/regulator, {3}];
    reference = publicCall[normalized /. regulator -> referenceValue];
    If[!ListQ[reference] || !And @@ (rationalMatrixQ[#, n] & /@ reference),
      stop["REFERENCE_EPSILON_SINGULAR", "The selected regulator reference is singular"]];
    stage = "factorization-equations";
    maskEvidence = <|"dependent_row_strategy" -> "automatic",
      "hierarchy_stage" -> "all-direction-symbolic-connections"|>;
    If[AssociationQ[hierarchy],
      mask = connectionMask[normalized, n];
      maskEvidence = Join[maskEvidence, <|"n" -> n,
        "hsector_nonzeros" -> Count[hierarchy["sector_hierarchy"], 1, {2}],
        "hde_nonzeros" -> Count[mask, 1, {2}]|>];
      mask = publicCall[Libra`TClosure[hierarchy["sector_hierarchy"] + mask]];
      If[!MatrixQ[mask, IntegerQ[#] && MemberQ[{0, 1}, #] &] ||
          Dimensions[mask] =!= {n, n} || Diagonal[mask] =!= ConstantArray[1, n],
        stop["DEPENDENT_ROW_MASK", "Cannot form the joint dependent-row closure"]];
      maskEvidence = Join[maskEvidence, <|"dependent_row_strategy" -> "sector-de-closure",
        "combined_mask" -> mask, "combined_mask_nonzeros" -> Count[mask, 1, {2}],
        "max_mask_nonzeros" -> hierarchy["max_mask_nonzeros"]|>];
      If[maskEvidence["combined_mask_nonzeros"] > hierarchy["max_mask_nonzeros"],
        stop["MASK_BUDGET", "The joint dependent-row closure exceeds the declared budget",
          <|"dependent_rows" -> maskEvidence|>]]];
    raw = publicCall[Libra`FactorDependence[normalized, regulator, referenceValue,
      Solve -> False, Sort -> False, Libra`DependentRowIndices -> mask,
      Fermatica`UseFermat -> False]];
    If[!MatchQ[raw, {_List, _?MatrixQ, _List}] || Dimensions[raw[[2]]] =!= {n, n},
      stop["FACTOR_EQUATIONS", "Libra produced no shared linear-equation template"]];
    {equations, template, unknowns} = raw;
    If[!And @@ (MatchQ[#, _Symbol] & /@ unknowns) || !DuplicateFreeQ[unknowns] ||
        Sort[DeleteCases[Flatten[template], 0]] =!= Sort[unknowns],
      stop["FACTOR_TEMPLATE", "Libra returned an invalid factorization template"]];
    stage = "coefficient-extraction";
    coefficients = coefficientEquations[equations, variables, unknowns, maxEquations];
    equationCount = Lookup[coefficients, "equation_count", 0];
    If[!TrueQ[coefficients["success"]],
      stop[coefficients["limit_code"], "Cannot complete the declared coefficient-equation construction",
        KeyTake[coefficients, {"equation_count"}]]];
    solverEquationCount = Length[coefficients["equations"]];
    stage = "linear-solve";
    solution = publicCall[Libra`GaussSolve[coefficients["equations"], unknowns,
      Continue -> False, Monitor -> False]];
    If[!MatchQ[solution, {___Rule}] ||
        !SubsetQ[unknowns, First /@ solution],
      stop["LINEAR_SOLVE", "Libra produced no shared factorization solution"]];
    free = Complement[unknowns, First /@ solution];
    stage = "free-parameter-selection";
    selection = CanonLibraFactorization`SelectFactor[
      publicCall[template //. Dispatch[solution]], free, factorOptions,
      Function[{candidate, specification},
        substitutions = Thread[unknowns -> publicCall[
          (unknowns //. Dispatch[solution]) /. specification]];
        <|"kinematically_constant" -> FreeQ[candidate, Alternatives @@ Join[variables, unknowns]],
          "equations_satisfied" -> And @@
            (TrueQ[Together[# /. substitutions] === 0] & /@ coefficients["original_equations"]),
          "reference_identity_all_directions" -> And @@ MapThread[
            CanonMethodCard`ZeroMatrixQ[Map[Together, #1.candidate - candidate.#2, {2}]] &,
            {normalized, reference}]|>]];
    factorEvidence = selection["evidence"];
    If[!TrueQ[selection["success"]],
      stop[selection["limit_code"], "No tried free-parameter point supplied a valid exact shared factor"]];
    factor = selection["factor"];
    stage = "apply-factor";
    callResult = publicCall[Libra`Transform[ds, factor, Print -> False,
        Fermatica`UseFermat -> False]];
    snapshot = publicCall[Map[Together, ds[#] & /@ variables, {3}]];
    If[failedCallQ[callResult] || !connectionQ[snapshot, Length[variables], n],
      stop["APPLY_FACTOR", "Libra could not apply the shared factorization transformation"]];
    nextCumulative = Map[Together, cumulative.factor, {2}];
    retained = <|"transformation" -> nextCumulative, "transformed_matrices" -> snapshot,
      "steps" -> trace, "shared_factor" -> factor|>;
    cumulative = nextCumulative;
    matrices = snapshot;
    epsilonForm = And @@ (TrueQ[publicCall[Libra`EFormQ[#, regulator]]] & /@ matrices);
    fuchsian = MapThread[TrueQ[publicCall[Libra`FuchsianQ[#1, #2]]] &, {matrices, variables}];
    If[!epsilonForm || !And @@ fuchsian,
      stop["FINAL_CONNECTION", "The full symbolic connection failed the provider's endpoint checks"]];
    inverse = publicCall[Map[Together, Inverse[cumulative], {2}]];
    If[!rationalMatrixQ[inverse, n],
      stop["CUMULATIVE_INVERSE", "Cannot construct exact rational cumulative inverse rows"]];
    stage = "complete";
    <|"success" -> True, "transformation" -> cumulative,
      "full_new_basis_rows" -> inverse, "transformed_matrices" -> matrices,
      "evidence" -> Join[evidence[], <|"check_eps_form" -> epsilonForm,
        "directional_fuchsian" -> fuchsian, "shared_factor" -> factor,
        "factorization_equation_count" -> coefficients["equation_count"],
        "dependent_rows" -> maskEvidence|>]|>,
    tag], maxSeconds,
    stopped["TIME_BUDGET", "The multivariable proposal reached its wall-time limit", <|"timed_out" -> True|>]];
  result
];

End[];
EndPackage[];
