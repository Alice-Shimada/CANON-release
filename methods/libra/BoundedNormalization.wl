(* A finite adapter over Libra's public primitives, not Rookie's subset search. *)
BeginPackage["CanonLibraNormalization`"];
Normalize::usage = "Normalize[A,x,eps,budgets] returns a bounded normalization result and a JSON-safe trace.";
Begin["`Private`"];

exactZeroQ[value_] := TrueQ[Together[value] === 0];
zeroMatrixQ[value_] := MatrixQ[value] && And @@ (exactZeroQ /@ Flatten[value]);
exactMatrixQ[value_, n_] := MatrixQ[value] && Dimensions[value] === {n, n} &&
  And @@ (CanonMethodCard`ExactRationalExpressionQ /@ Flatten[value]);
render[value_] := ToString[value, InputForm];
SetAttributes[publicCall, HoldAll];
publicCall[expression_] := Block[{$MessageList = {}}, Module[{value},
  value = Quiet @ Check[expression, $Failed];
  <|"value" -> value, "messages" -> (render /@ $MessageList)|>
]];

(* Factor before finding poles. Nonlinear factors and moving epsilon poles have
   explicit limits; no Root expansion, specialization or assumptions are used. *)
singularities[m_, x_, eps_] := Catch[Module[{factors, points, factor, point},
  factors = DeleteDuplicates @ Flatten[
    First /@ Rest[FactorList[Denominator[Together[#]]]] & /@ Flatten[m]
  ];
  factors = Select[factors, !FreeQ[#, x] &];
  points = {};
  Do[
    If[!PolynomialQ[factor, x] || Exponent[factor, x] =!= 1,
      Throw[Failure["NONLINEAR_POLE", <|"factor" -> render[factor]|>], "singularities"]
    ];
    point = Together[-Coefficient[factor, x, 0]/Coefficient[factor, x, 1]];
    If[!FreeQ[point, eps] || !CanonMethodCard`ExactRationalExpressionQ[point],
      Throw[Failure["UNDECIDABLE_POLE", <|"point" -> render[point]|>], "singularities"]
    ];
    AppendTo[points, point],
    {factor, factors}
  ];
  Append[DeleteDuplicates[points], Infinity]
], "singularities"];

poleRank[m_, x_, point_] := Module[{values},
  values = If[point === Infinity,
    If[exactZeroQ[#], -1,
      Exponent[Numerator[Together[#]], x] - Exponent[Denominator[Together[#]], x] + 1
    ] & /@ Flatten[m],
    Module[{num, den, order},
      If[exactZeroQ[#], -1,
      {num, den} = {Numerator[Together[#]], Denominator[Together[#]]};
      (* Multiplicity is read from a finite Taylor polynomial. *)
      order[p_] := First @ FirstPosition[
        Table[!exactZeroQ[D[p, {x, k}] /. x -> point], {k, 0, Exponent[p, x]}], True
      ] - 1;
      order[den] - order[num] - 1
      ]
    ] & /@ Flatten[m]
  ];
  Max[-1, Sequence @@ values]
];

profile[m_, x_, eps_] := Module[
  {points, m0, ranks, ranks0, residues, eigenvalues, intercepts, point, result},
  points = singularities[m, x, eps];
  If[FailureQ[points], Return[points]];
  m0 = Quiet @ Check[Map[Together, m /. eps -> 0, {2}], $Failed];
  If[!exactMatrixQ[m0, Length[m]],
    Return[Failure["EPSILON_ZERO_UNDEFINED", <||>]]
  ];
  ranks = poleRank[m, x, #] & /@ points;
  ranks0 = poleRank[m0, x, #] & /@ points;
  If[!And @@ (IntegerQ /@ Join[ranks, ranks0]),
    Return[Failure["UNDECIDABLE_POLE_RANK", <||>]]
  ];
  If[AnyTrue[ranks0, # > 0 &],
    Return[Failure["EPSILON_ZERO_IRREGULAR", <|
      "points" -> (render /@ points), "ranks" -> ranks0|>]]
  ];
  residues = Quiet @ Check[
    If[# === Infinity, -SeriesCoefficient[m, {x, Infinity, 1}],
      SeriesCoefficient[m, {x, #, -1}]] & /@ points,
    $Failed
  ];
  If[!ListQ[residues] || !And @@ (exactMatrixQ[#, Length[m]] & /@ residues),
    Return[Failure["RESIDUE_ANALYSIS_FAILED", <||>]]
  ];
  (* Eigenvalues and Libra subspaces are calculated at generic epsilon. In
     particular, a coalescing Jordan block is never constructed at epsilon=0. *)
  eigenvalues = Quiet @ Check[Eigenvalues /@ residues, $Failed];
  If[!ListQ[eigenvalues] || !And @@ (Length[#] === Length[m] & /@ eigenvalues) ||
      !And @@ (CanonMethodCard`ExactRationalExpressionQ /@ Flatten[eigenvalues]),
    Return[Failure["UNDECIDABLE_GENERIC_SPECTRUM", <||>]]
  ];
  intercepts = Quiet @ Check[Map[Together, eigenvalues /. eps -> 0, {2}], $Failed];
  If[!ListQ[intercepts] || !And @@ (IntegerQ /@ Flatten[intercepts]),
    Return[Failure[If[ListQ[intercepts] && AnyTrue[Flatten[intercepts],
        NumberQ[#] && !IntegerQ[#] &], "NONINTEGER_INTERCEPT",
        "UNDECIDABLE_INTEGER_INTERCEPT"], <|
      "generic_eigenvalues" -> (render /@ eigenvalues),
      "intercepts" -> render[intercepts]|>]]
  ];
  <|"points" -> points, "ranks" -> ranks, "ranks0" -> ranks0,
    "metric" -> Total[Abs[Flatten[intercepts]]],
    "evidence" -> MapThread[
      <|"point" -> render[#1], "generic_rank" -> #2,
        "epsilon_zero_rank" -> #3, "generic_eigenvalues" -> (render /@ #4),
        "integer_intercepts" -> #5|> &,
      {points, ranks, ranks0, eigenvalues, intercepts}]
  |>
];

(* Only individual tower prefixes and prefixes of the ordered tower list are
   considered. There is no enumeration of arbitrary subsets of Jordan towers. *)
boundedSpaces[spaces_, n_] := Module[{candidates, prefixes},
  If[!ListQ[spaces] || !And @@ (MatrixQ[#] && Last[Dimensions[#]] === n & /@ spaces),
    Return[$Failed]
  ];
  candidates = Flatten[Table[Take[tower, k], {tower, spaces},
    {k, 1, Length[tower]}], 1];
  prefixes = Table[Flatten[Take[spaces, k], 1], {k, 1, Length[spaces]}];
  Select[DeleteDuplicates[Join[candidates, prefixes]],
    0 < Length[#] <= n && MatrixRank[#] === Length[#] &]
];

noRankIncreaseQ[before_, after_] := And @@ MapThread[
  (#2 <= If[MemberQ[before["points"], #1],
    before["ranks"][[First @ FirstPosition[before["points"], #1]]], -1]) &,
  {after["points"], after["ranks"]}
];

Normalize[source_, x_, eps_, budgets_Association] := Module[
  {n = Length[source], current = source, total, before, initial = {}, final = {},
    attempts = {}, accepted = {}, projectorCount = 0, stage = "scope",
    started = AbsoluteTime[], outcome, stop, result, step, left, right, spaces,
    li, ri, us, vs, p, t, target, after, record, call, diagnostics = {},
    progressed, maxSteps, maxProjectors},
  total = IdentityMatrix[n];
  maxSteps = budgets["normalization_max_steps"];
  maxProjectors = budgets["normalization_max_projectors"];
  stop[code_, reason_, details_:<||>] := Throw[
    <|"success" -> False, "limit_code" -> code, "reason" -> reason,
      "details" -> details|>, "bounded-normalization"];
  result = TimeConstrained[Catch[
    If[n > budgets["normalization_max_dimension"],
      stop["DIMENSION_BUDGET", "The cut dimension exceeds normalization_max_dimension"]
    ];
    before = profile[current, x, eps];
    If[FailureQ[before], stop[before[[1]], "The bounded normalization scope cannot be established", before[[2]]]];
    initial = before["evidence"]; final = initial;
    Do[
      If[before["metric"] === 0, Break[]];
      stage = "GetSubspaces";
      left = {}; right = {};
      Do[
        call = publicCall[Libra`GetSubspaces[current, {x, point}, eps,
          Left, All -> False, Fermatica`UseFermat -> False]];
        spaces = call["value"];
        If[call["messages"] =!= {}, AppendTo[diagnostics,
          <|"stage" -> stage, "point" -> render[point], "side" -> "Left", "messages" -> call["messages"]|>]];
        spaces = boundedSpaces[spaces, n];
        If[spaces === $Failed, stop["SUBSPACE_RESULT", "GetSubspaces returned invalid left subspaces"]];
        AppendTo[left, spaces];
        call = publicCall[Libra`GetSubspaces[current, {x, point}, eps,
          Right, All -> False, Fermatica`UseFermat -> False]];
        spaces = call["value"];
        If[call["messages"] =!= {}, AppendTo[diagnostics,
          <|"stage" -> stage, "point" -> render[point], "side" -> "Right", "messages" -> call["messages"]|>]];
        spaces = boundedSpaces[spaces, n];
        If[spaces === $Failed, stop["SUBSPACE_RESULT", "GetSubspaces returned invalid right subspaces"]];
        AppendTo[right, spaces], {point, before["points"]}
      ];
      progressed = False;
      Catch[Do[
        If[li === ri || Length[us] =!= Length[vs], Continue[]];
        If[projectorCount >= maxProjectors,
          stop["PROJECTOR_BUDGET", "normalization_max_projectors was exhausted"]
        ];
        projectorCount++; stage = "Projector";
        record = <|"step" -> step, "projector_attempt" -> projectorCount,
          "from" -> render[before["points"][[li]]],
          "to" -> render[before["points"][[ri]]], "rank" -> Length[us]|>;
        call = publicCall[Libra`Projector[us, vs, Fermatica`UseFermat -> False]];
        p = call["value"];
        If[call["messages"] =!= {}, AppendTo[diagnostics,
          <|"stage" -> stage, "projector_attempt" -> projectorCount, "messages" -> call["messages"]|>]];
        If[!exactMatrixQ[p, n] || !zeroMatrixQ[p.p - p] || MatrixRank[p] =!= Length[us],
          AppendTo[attempts, Join[record, <|"rejection" -> "INVALID_PROJECTOR"|>]]; Continue[]
        ];
        stage = "Balance";
        call = publicCall[Libra`Balance[p, {x, before["points"][[li]], before["points"][[ri]]}]];
        t = call["value"];
        If[call["messages"] =!= {}, AppendTo[diagnostics,
          <|"stage" -> stage, "projector_attempt" -> projectorCount, "messages" -> call["messages"]|>]];
        If[!exactMatrixQ[t, n] || exactZeroQ[Det[t]],
          AppendTo[attempts, Join[record, <|"rejection" -> "SINGULAR_BALANCE"|>]]; Continue[]
        ];
        stage = "gauge-check";
        call = publicCall[Libra`Transform[current, t, x, Print -> False,
          Fermatica`UseFermat -> False]];
        target = call["value"];
        If[call["messages"] =!= {}, AppendTo[diagnostics,
          <|"stage" -> stage, "projector_attempt" -> projectorCount, "messages" -> call["messages"]|>]];
        If[!exactMatrixQ[target, n] || !zeroMatrixQ[current.t - D[t, x] - t.target] ||
            !zeroMatrixQ[source.(total.t) - D[total.t, x] - (total.t).target],
          AppendTo[attempts, Join[record, <|"rejection" -> "GAUGE_IDENTITY"|>]]; Continue[]
        ];
        stage = "progress-check";
        after = profile[target, x, eps];
        If[FailureQ[after],
          AppendTo[attempts, Join[record, <|"rejection" -> after[[1]], "details" -> after[[2]]|>]]; Continue[]
        ];
        If[!noRankIncreaseQ[before, after],
          AppendTo[attempts, Join[record, <|"rejection" -> "IRREGULARITY_INCREASE",
            "singularities_before" -> before["evidence"],
            "singularities_after" -> after["evidence"]|>]]; Continue[]
        ];
        If[after["metric"] >= before["metric"],
          AppendTo[attempts, Join[record, <|"rejection" -> "NO_STRICT_PROGRESS",
            "metric_before" -> before["metric"], "metric_after" -> after["metric"]|>]]; Continue[]
        ];
        record = Join[record, <|"accepted" -> True, "projector" -> render[p],
          "transformation" -> render[t], "metric_before" -> before["metric"],
          "metric_after" -> after["metric"], "singularities_after" -> after["evidence"],
          "projector_idempotent" -> True, "invertible" -> True,
          "source_gauge" -> True, "generic_ranks_not_increased" -> True|>];
        AppendTo[attempts, record]; AppendTo[accepted, record];
        current = Map[Together, target, {2}]; total = Map[Together, total.t, {2}];
        before = after; final = after["evidence"]; progressed = True;
        Throw[Null, "progressed"],
        {li, Length[left]}, {ri, Length[right]}, {us, left[[li]]}, {vs, right[[ri]]}
      ], "progressed"];
      If[!progressed, stop["NO_PROGRESS_PROJECTOR", "No tested projector gave a strict global integer-deviation improvement"]],
      {step, 1, maxSteps}
    ];
    If[before["metric"] =!= 0,
      stop["STEP_BUDGET", "normalization_max_steps was exhausted"]
    ];
    stage = "normalized";
    <|"success" -> True, "transformation" -> total, "matrix" -> current|>,
    "bounded-normalization"], budgets["normalization_max_seconds"],
    <|"success" -> False, "limit_code" -> "SECONDS_BUDGET",
      "reason" -> "normalization_max_seconds was exhausted"|>
  ];
  Join[result, <|"evidence" -> Join[
    <|"strategy" -> "bounded", "budgets" -> budgets, "dimension" -> n,
      "steps_used" -> Length[accepted], "projectors_tested" -> projectorCount,
      "elapsed_seconds" -> N[AbsoluteTime[] - started], "stopped_stage" -> stage,
      "subspace_policy" -> "individual-tower-prefixes-and-ordered-tower-list-prefixes",
      "initial_singularities" -> initial, "final_singularities" -> final,
      "attempts" -> attempts, "provider_messages" -> diagnostics,
      "transformation" -> render[total]|>,
    KeyDrop[result, {"success", "transformation", "matrix"}]
  ]|>]
];

End[];
EndPackage[];
