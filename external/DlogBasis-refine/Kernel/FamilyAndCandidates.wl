(* Explicit family objects and the exact bounded exponent lattice. *)

Options[CreateDlogFamily] = {
  "Name" -> "DlogFamily",
  "LoopMomenta" -> {},
  "ExternalMomenta" -> {},
  "Propagators" -> {},
  "KinematicVariables" -> {},
  "KinematicRules" -> {}
};

familyHash[data_] := IntegerString[Hash[HoldComplete[data], "SHA256"], 16, 64];

CreateDlogFamily[OptionsPattern[]] := Module[{data},
  data = <|
    "Name" -> OptionValue["Name"],
    "LoopMomenta" -> OptionValue["LoopMomenta"],
    "ExternalMomenta" -> OptionValue["ExternalMomenta"],
    "Propagators" -> OptionValue["Propagators"],
    "KinematicVariables" -> OptionValue["KinematicVariables"],
    "KinematicRules" -> OptionValue["KinematicRules"]
  |>;
  Join[<|"ObjectType" -> "DlogFamily", "FamilyHash" -> familyHash[data]|>, data]
];

weakCompositions[0, 0] := {{}};
weakCompositions[n_Integer, 1] := {{n}};
weakCompositions[n_Integer, k_Integer] := Flatten[
  Table[Prepend[#, first]& /@ weakCompositions[n - first, k - 1], {first, 0, n}],
  1
];

weakCompositionsUpTo[bound_Integer, 0] := If[bound >= 0, {{}}, {}];
weakCompositionsUpTo[bound_Integer, length_Integer] :=
  Join@@Table[weakCompositions[degree, length], {degree, 0, bound}];

EnumerateDlogCandidates[
  family_Association,
  sector_List,
  numeratorBound_Integer,
  dotBound_Integer
] := Module[
  {active, inactive, dots, numerators, indices, expected},
  (* Active a_i=1+d_i and inactive a_j=-n_j with separate total bounds. *)
  If[
    Length[sector] =!= Length[family["Propagators"]] ||
      !VectorQ[sector, (# === 0 || # === 1)&] ||
      numeratorBound < 0 || dotBound < 0,
    Return[Failure["InvalidSectorOrBounds", <|
      "Sector" -> sector,
      "PropagatorCount" -> Length[family["Propagators"]],
      "NumeratorDegreeBound" -> numeratorBound,
      "DotDegreeBound" -> dotBound
    |>]]
  ];
  active = Flatten@Position[sector, 1];
  inactive = Flatten@Position[sector, 0];
  dots = weakCompositionsUpTo[dotBound, Length[active]];
  numerators = weakCompositionsUpTo[numeratorBound, Length[inactive]];
  indices = Flatten[
    Table[
      ReplacePart[
        ConstantArray[0, Length[sector]],
        Join[Thread[active -> (1 + dot)], Thread[inactive -> (-numerator)]]
      ],
      {dot, dots}, {numerator, numerators}
    ],
    1
  ];
  expected = Binomial[Length[active] + dotBound, Length[active]]*
    Binomial[Length[inactive] + numeratorBound, Length[inactive]];
  <|
    "FamilyHash" -> family["FamilyHash"],
    "Sector" -> sector,
    "ActivePositions" -> active,
    "InactivePositions" -> inactive,
    "NumeratorDegreeBound" -> numeratorBound,
    "DotDegreeBound" -> dotBound,
    "ExpectedCount" -> expected,
    "CandidateCount" -> Length[indices],
    "Candidates" -> MapIndexed[
      <|
        "CandidateID" -> First[#2],
        "IndexVector" -> #1,
        "Integral" -> DlogIntegral[family["FamilyHash"], #1]
      |>&,
      indices
    ]
  |>
];
