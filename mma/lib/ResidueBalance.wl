(* Bounded rational one-variable normalization, with exact homogeneous-scale lifting.
   A candidate provider: independent CANON checkers retain acceptance authority. *)
BeginPackage["CANON`ResidueBalance`"];
AnalyzeCore::usage = "AnalyzeCore[cut, options] diagnoses a checked rational core and the applicability of residue balancing; it never proves nonexistence.";
ProposeCore::usage = "ProposeCore[cut, options] constructs a bounded rational epsilon-form candidate, or returns a scoped Failure.";
Begin["`Private`"];

simplify[m_] := Map[Factor, m, {2}];
zeroQ[m_] := And @@ (TrueQ[Together[#] === 0] & /@ Flatten[m]);
finiteQ[e_] := FreeQ[e, Indeterminate | ComplexInfinity | DirectedInfinity[___] | _Real];
fail[tag_, reason_, extra_ : <||>] := Throw[
  Failure[tag, Join[<|"reason" -> reason, "nonexistence_proved" -> False|>, extra]], failureTag];

options[given_Association] := Module[{result},
  If[Complement[Keys[given], {"max_dimension", "max_balance_steps", "max_shear_power",
      "reference_regulators"}] =!= {}, fail["INVALID_OPTIONS", "Unknown method option"]];
  result = Join[<|"max_dimension" -> 6, "max_balance_steps" -> 12,
    "max_shear_power" -> 4, "reference_regulators" -> {1/2, 1/3, 1/5, 1/7, 2/7}|>, given];
  If[!IntegerQ[result["max_dimension"]] || result["max_dimension"] < 1 ||
      !And @@ (IntegerQ[result[#]] && result[#] >= 0 & /@
        {"max_balance_steps", "max_shear_power"}) ||
      !MatchQ[result["reference_regulators"], {(_Integer | _Rational) ..}] ||
      MemberQ[result["reference_regulators"], 0],
    fail["INVALID_OPTIONS", "Use positive dimension, nonnegative integer search bounds, and nonzero exact rational references"]];
  result
];
options[_] := fail["INVALID_OPTIONS", "method_options must be an Association"];

(* Keep all original directions. Only an exactly proved scalar epsilon spectator
   can be omitted from the subsequent one-variable construction. *)
prepare[cut_, opts_] := Catch[Module[{a, vars, eps, n, h, b, weights, slopes, good, trial},
  If[!CanonMethodCard`ValidCutDEQ[cut], fail["INVALID_INPUT", "Invalid exact rational cut DE"]];
  {a, vars, eps} = Lookup[cut, {"matrices", "variables", "regulator"}]; n = Length[cut["basis"]];
  If[!And @@ (MatchQ[#, _Symbol] & /@ vars) || MemberQ[vars, eps] ||
      Length[DeleteDuplicates[vars]] =!= Length[vars] ||
      !And @@ (CanonMethodCard`DeclaredCoefficientDomainQ[#, Append[vars, eps]] & /@ Flatten[a]),
    fail["INVALID_INPUT", "Variables/regulator must be distinct declared symbols; coefficients cannot contain unbound symbols"]];
  If[n > opts["max_dimension"], fail["OUT_OF_SCOPE", "Core exceeds max_dimension"]];
  a = simplify /@ a;
  If[!CanonMethodCard`FlatConnectionQ[a, vars], fail["INVALID_INPUT", "Input connection is not flat"]];
  If[CanonMethodCard`EpsilonFactorizedQ[a, eps],
    Return[<|"cut" -> cut, "options" -> opts, "already_epsilon_form" -> True,
      "scale_rows" -> IdentityMatrix[n], "matrices" -> a, "active_index" -> 1|>]];
  Do[
    h = ConstantArray[1, n]; good = True;
    Do[If[j =!= k,
      If[!zeroQ[a[[j]] - DiagonalMatrix[Diagonal[a[[j]]]]], good = False; Break[]];
      weights = Factor /@ (vars[[j]] Diagonal[a[[j]]]);
      If[!FreeQ[weights, Alternatives @@ vars] ||
          !And @@ (PolynomialQ[#, eps] && Exponent[#, eps] <= 1 & /@ weights),
        good = False; Break[]];
      slopes = Coefficient[#, eps] & /@ weights; weights = weights /. eps -> 0;
      If[!And @@ (IntegerQ /@ weights) || !Apply[SameQ, slopes],
        good = False; Break[]];
      h *= vars[[j]]^(-weights)
    ], {j, Length[vars]}];
    If[good,
      trial = DiagonalMatrix[h];
      b = simplify /@ CanonMethodCard`GaugeTransform[a, vars, DiagonalMatrix[1/h]];
      If[FreeQ[b[[k]], Alternatives @@ Delete[vars, k]] &&
          And @@ Table[j === k || (CanonMethodCard`EpsilonFactorizedQ[{b[[j]]}, eps] &&
            zeroQ[b[[j]] - b[[j, 1, 1]] IdentityMatrix[n]]), {j, Length[vars]}],
        Throw[<|"cut" -> cut, "options" -> opts, "already_epsilon_form" -> False,
          "scale_rows" -> trial, "matrices" -> b, "active_index" -> k|>, scaleFrame]]
    ], {k, Length[vars]}];
  fail["OUT_OF_SCOPE", "No single essential variable after exact integer homogeneous-scale separation"]
], scaleFrame];

polynomialOrder[p_, x_, a_] := Module[{cs},
  If[TrueQ[p === 0], Return[Infinity]];
  cs = Factor /@ CoefficientList[Expand[p /. x -> x + a], x];
  SelectFirst[Range[Length[cs]], cs[[#]] =!= 0 &] - 1
];
valuation[e_, x_, a_] := With[{v = Together[e]},
  If[v === 0, Infinity,
    polynomialOrder[Numerator[v], x, a] - polynomialOrder[Denominator[v], x, a]]];
degree[e_, x_] := With[{v = Together[e]},
  If[v === 0, -Infinity, Exponent[Numerator[v], x] - Exponent[Denominator[v], x]]];

poles[a_, x_, eps_] := Module[{factors, roots, root},
  factors = DeleteDuplicates[Flatten[(First /@ Rest[FactorList[Denominator[Together[#]]]]) & /@ Flatten[a]]];
  factors = Select[factors, !FreeQ[#, x] &]; roots = {};
  Do[
    If[Exponent[f, x] =!= 1, fail["OUT_OF_SCOPE", "Finite poles are not all rational linear factors"]];
    root = Factor[-Coefficient[f, x, 0]/Coefficient[f, x, 1]];
    If[!MatchQ[root, _Integer | _Rational],
      fail["OUT_OF_SCOPE", "Pole positions must be regulator-independent rational numbers"]];
    AppendTo[roots, root], {f, factors}];
  Sort[DeleteDuplicates[roots]]
];

fuchsianQ[a_, x_, ps_] := And[
  And @@ Flatten[Table[valuation[v, x, p] >= -1, {p, ps}, {v, Flatten[a]}]],
  And @@ (degree[#, x] <= -1 & /@ Flatten[a])];

(* Difference constraints find a diagonal shear without an exponential scan.
   h_j-h_i <= val(A_ij)+1 at p; h_i-h_j <= -1-deg(A_ij) at infinity. *)
shearPowers[a_, x_, p_, bound_] := Module[{n = Length[a], edges = {}, h, changed},
  Do[If[a[[i, j]] =!= 0,
    AppendTo[edges, {i, j, valuation[a[[i, j]], x, p] + 1}];
    AppendTo[edges, {j, i, -1 - degree[a[[i, j]], x]}]], {i, n}, {j, n}];
  h = ConstantArray[0, n];
  Do[
    changed = False;
    Do[If[h[[edge[[2]]]] > h[[edge[[1]]]] + edge[[3]],
      h[[edge[[2]]]] = h[[edge[[1]]]] + edge[[3]]; changed = True], {edge, edges}];
    If[!changed, Break[]];
    If[k === n, fail["METHOD_EXHAUSTED", "Diagonal shears cannot make this pole and infinity Fuchsian",
      <|"stage" -> "diagonal-shearing", "pole" -> p|>]], {k, n}];
  h -= First[h];
  If[Max[Abs[h]] > bound, fail["METHOD_EXHAUSTED", "Required shear exceeds max_shear_power",
    <|"stage" -> "diagonal-shearing", "powers" -> h|>]];
  h
];

residues[a_, x_, ps_] := Module[{rs, residual},
  rs = Table[simplify[Map[Cancel[(x - p) #] /. x -> p &, a, {2}]], {p, ps}];
  residual = a - Total[MapThread[#1/(x - #2) &, {rs, ps}]];
  If[!zeroQ[residual], fail["METHOD_EXHAUSTED", "Connection is not a proper Fuchsian partial-fraction sum"]];
  Append[rs, -Total[rs]]
];

spectrum[r_, eps_] := Module[{lambda, fs, result = {}, value, integer, slope},
  lambda = Unique["lambda$"];
  fs = Rest[FactorList[Numerator[Together[CharacteristicPolynomial[r, lambda]]]]];
  Do[If[!FreeQ[f[[1]], lambda],
    If[Exponent[f[[1]], lambda] =!= 1,
      fail["OUT_OF_SCOPE", "Residue spectrum is not rational affine in the regulator"]];
    value = Factor[-Coefficient[f[[1]], lambda, 0]/Coefficient[f[[1]], lambda, 1]];
    integer = Quiet[value /. eps -> 0]; slope = Cancel[(value - integer)/eps];
    If[!IntegerQ[integer] || !FreeQ[slope, eps],
      fail["OUT_OF_SCOPE", "Residue eigenvalues require normalization beyond integer shifts"]];
    result = Join[result, ConstantArray[<|"value" -> value, "integer" -> integer|>, f[[2]]]]
  ], {f, fs}];
  result
];

normalizationCost[spectra_] := Total[Abs[Flatten[Lookup[#, "integer"] & /@ spectra]]];

balanced[a_, x_, eps_, ps_, budget_] := Catch[Module[
  {n = Length[a], rows, current = a, trace = {}, rs, sp, points, negatives, positives,
    found, vset, wset, pairing, projector, g, b, binv, trial, trialRS, trialSP, cost},
  rows = IdentityMatrix[n]; points = Append[ps, Infinity];
  Do[
    rs = residues[current, x, ps]; sp = spectrum[#, eps] & /@ rs;
    cost = normalizationCost[sp]; If[cost === 0, Throw[{current, rows, trace, rs}, normalizedFrame]];
    If[step === budget, fail["METHOD_EXHAUSTED", "Integer normalization reached max_balance_steps",
      <|"stage" -> "integer-balances", "remaining_integer_cost" -> cost, "balances" -> trace|>]];
    negatives = Flatten[Table[({i, #} &) /@ Select[sp[[i]], #["integer"] < 0 &], {i, Length[rs]}], 1];
    positives = Flatten[Table[({i, #} &) /@ Select[sp[[i]], #["integer"] > 0 &], {i, Length[rs]}], 1];
    found = Catch[Do[
      If[neg[[1]] === pos[[1]], Continue[]];
      vset = NullSpace[rs[[neg[[1]]]] - neg[[2]]["value"] IdentityMatrix[n]];
      wset = NullSpace[Transpose[rs[[pos[[1]]]] - pos[[2]]["value"] IdentityMatrix[n]]];
      Do[
        pairing = Factor[w.v]; If[pairing === 0, Continue[]];
        projector = simplify[Outer[Times, v, w]/pairing];
        g = Which[points[[pos[[1]]]] === Infinity, x - points[[neg[[1]]]],
          points[[neg[[1]]]] === Infinity, 1/(x - points[[pos[[1]]]]),
          True, (x - points[[neg[[1]]]])/(x - points[[pos[[1]]]])];
        b = IdentityMatrix[n] + (g - 1) projector;
        binv = IdentityMatrix[n] + (1/g - 1) projector;
        trial = simplify[(b.current + D[b, x]).binv];
        If[!fuchsianQ[trial, x, ps], Continue[]];
        trialRS = residues[trial, x, ps]; trialSP = spectrum[#, eps] & /@ trialRS;
        If[normalizationCost[trialSP] =!= cost - 2, Continue[]];
        Throw[{trial, b, <|"raised_pole" -> points[[neg[[1]]]],
          "lowered_pole" -> points[[pos[[1]]]], "raised_eigenvalue" -> neg[[2]]["value"],
          "lowered_eigenvalue" -> pos[[2]]["value"], "projector" -> projector|>}, foundBalance],
        {v, vset}, {w, wset}], {neg, negatives}, {pos, positives}]; $Failed, foundBalance];
    If[found === $Failed, fail["METHOD_EXHAUSTED", "No admissible rank-one balance in the current eigenspaces",
      <|"stage" -> "integer-balances", "remaining_integer_cost" -> cost, "balances" -> trace|>]];
    current = found[[1]]; rows = simplify[found[[2]].rows]; AppendTo[trace, found[[3]]],
    {step, 0, budget}]
], normalizedFrame];

(* Choose a nonsingular member of a linear matrix space deterministically.
   det has degree <= n in each coefficient, so n+1 exact choices suffice at
   each elimination step whenever the determinant polynomial is nonzero. *)
invertibleMember[space_, n_] := Catch[Module[{parameters, matrix, determinant, choices = {}, value},
  If[space === {}, Return[$Failed]];
  parameters = Table[Unique["c$"], {Length[space]}];
  matrix = Total[MapThread[#1 Partition[#2, n] &, {parameters, space}]];
  determinant = Factor[Det[matrix]]; If[determinant === 0, Return[$Failed]];
  Do[
    value = SelectFirst[Range[0, n], !TrueQ[Factor[determinant /. parameter -> #] === 0] &, Missing["none"]];
    If[MissingQ[value], Throw[$Failed, singularMember]];
    AppendTo[choices, parameter -> value]; determinant = Factor[determinant /. parameter -> value],
    {parameter, parameters}];
  simplify[matrix /. choices]
], singularMember];

factorRegulator[rs_, eps_, references_] := Catch[Module[{n = Length[First[rs]], q, unknowns, equations, linear,
    space, result, trials = {}, sampled},
  unknowns = Table[Unique["q$"], {n n}]; q = Partition[unknowns, n];
  Do[
    sampled = Quiet[rs /. eps -> reference];
    If[!finiteQ[sampled], AppendTo[trials, <|"reference" -> reference, "reason" -> "pole"|>]; Continue[]];
    equations = Flatten[MapThread[#1.q - (eps/reference) q.#2 &, {rs, sampled}]];
    equations = Numerator[Together[#]] & /@ equations;
    linear = If[zeroQ[equations], ConstantArray[0, {1, n n}],
      Normal[CoefficientArrays[equations, unknowns][[2]]]];
    space = NullSpace[linear]; result = invertibleMember[space, n];
    If[result =!= $Failed,
      Throw[<|"transformation" -> result, "reference" -> reference,
        "nullity" -> Length[space], "reference_trials" -> trials|>, factoredFrame]];
    AppendTo[trials, <|"reference" -> reference, "reason" -> "no invertible intertwiner"|>],
    {reference, references}];
  fail["METHOD_EXHAUSTED", "No invertible regulator intertwiner at the declared references",
    <|"stage" -> "regulator-factorization", "reference_trials" -> trials|>]
], factoredFrame];

AnalyzeCore[cut_, given_ : <||>] := Catch[Module[{opts, prepared, a, x, eps, ps, atZero, regular},
  opts = options[given]; prepared = prepare[cut, opts];
  eps = cut["regulator"]; x = cut["variables"][[prepared["active_index"]]];
  a = prepared["matrices"][[prepared["active_index"]]];
  regular = And @@ (valuation[#, eps, 0] >= 0 & /@ Flatten[a]);
  ps = If[prepared["already_epsilon_form"], {}, poles[a, x, eps]];
  atZero = If[regular, simplify[Map[Limit[#, eps -> 0] &, a, {2}]], Missing["RegulatorPole"]];
  <|"schema" -> "canon-neu/core-diagnosis/v1", "family_id" -> cut["family_id"],
    "basis_id" -> cut["basis_id"], "sector" -> cut["sector"], "variables" -> cut["variables"],
    "regulator" -> eps, "active_variable" -> x, "scale_rows" -> prepared["scale_rows"],
    "already_epsilon_form" -> prepared["already_epsilon_form"], "finite_poles" -> ps,
    "fuchsian" -> If[prepared["already_epsilon_form"], Missing["NotNeeded"], fuchsianQ[a, x, ps]],
    "regular_at_regulator_zero" -> regular,
    "zero_order_matrix" -> atZero, "nonexistence_proved" -> False,
    "admissible_transformations" -> <|"regulator_poles_allowed" -> True,
      "invertibility" -> "generic over the rational function field; not at regulator=0"|>,
    "zero_order_monodromy_scope" -> "An epsilon-zero obstruction only concerns transformations with a finite invertible specialization; it cannot exclude epsilon-meromorphic gauges.",
    "recommended_method" -> "residue-balance", "options" -> opts|>
], failureTag];

ProposeCore[cut_, given_ : <||>] := Catch[Module[{opts, prepared, x, eps, a, ps, n, rows, powers, h,
    shears = {}, normalized, factor, transformation, transformed},
  opts = options[given]; prepared = prepare[cut, opts];
  eps = cut["regulator"]; x = cut["variables"][[prepared["active_index"]]];
  n = Length[cut["basis"]]; rows = prepared["scale_rows"];
  a = prepared["matrices"][[prepared["active_index"]]];
  If[!prepared["already_epsilon_form"],
    ps = poles[a, x, eps]; If[ps === {}, ps = {0}];
    Do[If[!fuchsianQ[a, x, {point}],
      powers = shearPowers[a, x, point, opts["max_shear_power"]];
      h = DiagonalMatrix[(x - point)^powers];
      a = simplify[(h.a + D[h, x]).DiagonalMatrix[(x - point)^(-powers)]];
      rows = simplify[h.rows]; AppendTo[shears, <|"pole" -> point, "powers" -> powers|>]
    ], {point, ps}];
    If[!fuchsianQ[a, x, ps], fail["METHOD_EXHAUSTED", "Declared diagonal-shear ansatz did not yield a Fuchsian system"]];
    normalized = balanced[a, x, eps, ps, opts["max_balance_steps"]];
    rows = simplify[normalized[[2]].rows];
    factor = factorRegulator[Most[normalized[[4]]], eps, opts["reference_regulators"]];
    rows = simplify[Inverse[factor["transformation"]].rows],
    normalized = {a, IdentityMatrix[n], {}, {}};
    factor = <|"transformation" -> IdentityMatrix[n], "reference" -> None,
      "nullity" -> 0, "reference_trials" -> {}|>
  ];
  transformation = simplify[Inverse[rows]];
  transformed = simplify /@ CanonMethodCard`GaugeTransform[cut["matrices"], cut["variables"], transformation];
  If[!CanonMethodCard`EpsilonFactorizedQ[transformed, eps],
    fail["METHOD_EXHAUSTED", "Constructed transformation did not factor epsilon in every original direction"]];
  <|"transformation" -> transformation, "rows" -> rows, "transformed_matrices" -> transformed,
    "active_variable" -> x, "scale_rows" -> prepared["scale_rows"], "shears" -> shears,
    "balances" -> normalized[[3]], "regulator_factorization" -> factor,
    "regulator_zero_invertibility_required" -> False, "options" -> opts|>
], failureTag];

End[];
EndPackage[];
