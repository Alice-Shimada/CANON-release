testDirectory = Environment["DLOGBASIS_TEST_DIRECTORY"];
packageRoot = DirectoryName[testDirectory];
finiteFlowFile = Environment["DLOGBASIS_FINITEFLOW_FILE"];
Get[FileNameJoin[{packageRoot, "DlogBasis.wl"}]];
twoLoop = Get[FileNameJoin[{testDirectory, "Families", "Massless2L5P.wl"}]];
threeLoop = Get[FileNameJoin[{testDirectory, "Families", "PBP3L5P.wl"}]];

VerificationTest[
  With[{lattice = DlogBasis`EnumerateDlogCandidates[
      twoLoop["Family"], twoLoop["Sector"], 2, 1]},
    {lattice["CandidateCount"], lattice["ExpectedCount"],
      MemberQ[Lookup[lattice["Candidates"], "IndexVector"],
        {2, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0}]}
  ],
  {90, 90, True},
  TestID -> "exact-sector numerator-and-dot-lattice"
]

VerificationTest[
  Module[{family, result},
    family = DlogBasis`CreateDlogFamily[
      "LoopMomenta" -> {numeratorLoop},
      "ExternalMomenta" -> {numeratorExternal},
      "Propagators" -> {
        numeratorLoop^2, (numeratorLoop + numeratorExternal)^2
      },
      "KinematicVariables" -> {numeratorScale},
      "KinematicRules" -> {numeratorExternal^2 -> numeratorScale}
    ];
    result = DlogBasis`DlogBasisSearch[
      family, {1, 0},
      "LoopSpecifications" -> {
        <|"Momentum" -> numeratorLoop, "BaseDimension" -> 2|>
      },
      "NumeratorDegreeBound" -> 1,
      "FiniteFlowPackageFile" -> finiteFlowFile
    ];
    {
      {result["CandidateLattice"]["CandidateCount"],
        Length[result["RepresentedCandidates"]]},
      result["CandidateChartCompleteQ"],
      Lookup[result["Chart"]["ExtraRecords"], "Position"],
      result["Chart"]["UnrepresentedPropagatorPositions"],
      result["CandidateGenerationMode"],
      result["NumeratorPositions"],
      Lookup[result["NumeratorChartScan"], "NumeratorPositions"]
    }
  ],
  {{2, 2}, True, {2}, {}, "SingletonNumeratorCharts", {2}, {{}, {2}}},
  TestID -> "search-scans-bounded-numerator-positions-as-singleton-charts"
]

VerificationTest[
  Module[{family},
    family = DlogBasis`CreateDlogFamily[
      "LoopMomenta" -> {boundLoop},
      "Propagators" -> {boundLoop^2, boundLoop^2 + 1}
    ];
    First /@ {
      DlogBasis`EnumerateDlogCandidates[family, {1}, 0, 0],
      DlogBasis`EnumerateDlogCandidates[family, {1, 2}, 0, 0],
      DlogBasis`EnumerateDlogCandidates[family, {1, 0}, -1, 0],
      DlogBasis`EnumerateDlogCandidates[family, {1, 0}, 0, -1]
    }
  ],
  ConstantArray["InvalidSectorOrBounds", 4],
  TestID -> "invalid-sector-or-bounds-return-one-input-failure"
]

VerificationTest[
  With[{chart = DlogBasis`LoopByLoopBaikovChart[
      twoLoop["Family"], twoLoop["Sector"], twoLoop["Common4DOrder"],
      twoLoop["NumeratorPositions"]]},
    {Det[chart["CoordinateMatrix"]],
      Lookup[chart["LoopData"], "ExternalCount"],
      chart["FamilyPropagatorValues"] === chart["BaikovVariables"],
      AllTrue[chart["PhysicalMappingResiduals"], TrueQ[# === 0]&]}
  ],
  {512, {5, 4}, True, True},
  TestID -> "massless-2l5p-top-sector-LBL-chart"
]

VerificationTest[
  With[{
      forward = DlogBasis`LoopByLoopBaikovChart[
        twoLoop["Family"], twoLoop["Sector"], twoLoop["NamedMixedOrder"],
        twoLoop["NumeratorPositions"]],
      reverse = DlogBasis`LoopByLoopBaikovChart[
        twoLoop["Family"], twoLoop["Sector"], Reverse[twoLoop["NamedMixedOrder"]],
        twoLoop["NumeratorPositions"]]
    },
    {Lookup[forward["LoopData"], {"Loop", "BaseDimension"}],
      Lookup[reverse["LoopData"], {"Loop", "BaseDimension"}],
      {forward["RepresentationStatus"], reverse["RepresentationStatus"]}}
  ],
  {{{DlogBasisTests`Massless2L5P`k1, 2},
    {DlogBasisTests`Massless2L5P`k2, 6}},
   {{DlogBasisTests`Massless2L5P`k2, 6},
    {DlogBasisTests`Massless2L5P`k1, 2}},
   {"MixedDimensionProposal", "MixedDimensionProposal"}},
  TestID -> "dimensions-are-bound-to-named-loops"
]

VerificationTest[
  Module[{chart, lattice, mapped},
    chart = DlogBasis`LoopByLoopBaikovChart[
      twoLoop["Family"], twoLoop["Sector"], twoLoop["Common4DOrder"], {}
    ];
    lattice = DlogBasis`EnumerateDlogCandidates[
      twoLoop["Family"], twoLoop["Sector"], 0, 0
    ];
    mapped = First@DlogBasis`MapDlogCandidates[
      chart, lattice["Candidates"]
    ];
    {
      Lookup[chart["LoopData"], "Dimension"],
      Lookup[chart["LoopData"], "ExternalExponent"] -
        Lookup[chart["LoopData"], "BaseExternalExponent"],
      Lookup[chart["LoopData"], "BaikovExponent"] -
        Lookup[chart["LoopData"], "BaseBaikovExponent"],
      chart["KinematicMeasure"] ===
        chart["BaseKinematicMeasure"] chart["RegulatorWeight"],
      mapped["BaikovForm"] ===
        mapped["BaseBaikovForm"] chart["RegulatorWeight"]
    }
  ],
  {{4 - 2 DlogBasis`DimensionalRegulator,
      4 - 2 DlogBasis`DimensionalRegulator},
    {DlogBasis`DimensionalRegulator, DlogBasis`DimensionalRegulator},
    {-DlogBasis`DimensionalRegulator, -DlogBasis`DimensionalRegulator},
    True, True},
  TestID -> "base-dimension-input-builds-D0-minus-2epsilon-physical-form"
]

VerificationTest[
  Module[{signature},
    signature = DlogBasis`DimensionallyRegulatedMaximalCutSignature[
      {1/x^3, 1/x^2, 1/x},
      (1 + a x + b x^2)/(1 + x),
      {x}, {a, b}, {x}
    ];
    {
      signature["HigherPoleRows"],
      signature["TerminalResidueRows"],
      Lookup[signature["GeneralizedCutRecords"], "RegulatorValuation"],
      Lookup[signature["PhysicalCutRecords"], "TwistValuation"],
      signature["DimensionConvention"]
    }
  ],
  {
    {},
    {
      {(1 - a^2 + 2 b) DlogBasis`DimensionalRegulator/2,
        (-1 + a) DlogBasis`DimensionalRegulator, 1}
    },
    {1, 1, 0},
    {0}, "D=D0-2 DimensionalRegulator"
  },
  TestID -> "regulated-cut-keeps-each-first-nonzero-generalized-residue"
]

VerificationTest[
  With[{signature =
      DlogBasis`DimensionallyRegulatedMaximalCutSignature[
        {Sqrt[s]/x^2 + 1/x}, 1, {x}, {s}, {x}
      ]},
    {signature["HigherPoleRows"], signature["TerminalResidueRows"],
      First@Lookup[signature["GeneralizedCutRecords"], "RegulatorValuation"]}
  ],
  {{}, {{1}}, 0},
  TestID -> "subleading-simple-pole-precedes-regulated-double-pole"
]

VerificationTest[
  Module[{signature, lift},
    signature = DlogBasis`DimensionallyRegulatedMaximalCutSignature[
      {Sqrt[a] (1/y^2 + 1/y)/x, (1/y^2 - 1/y)/x},
      1, {x, y}, {a}, {x}
    ];
    lift = DlogBasis`Private`AlgebraicConstantLSLift[
      signature, {a, DlogBasis`DimensionalRegulator}, "Singular"
    ];
    {signature["HigherPoleRows"], signature["TerminalResidueRows"],
      lift["CoefficientDirections"], lift["ModuleLiftVerifiedQ"]}
  ],
  {{{Sqrt[a], 1}}, {{Sqrt[a], -1}},
    {{1/(2 Sqrt[a]), -1/2}}, True},
  TestID -> "algebraic-prefactors-cancel-higher-poles-in-one-joint-system"
]

VerificationTest[
  With[{signature = DlogBasis`DimensionallyRegulatedMaximalCutSignature[
      {(1 + y)/(x^2 y)}, x + y, {x, y}, {}, {x, y}
    ]},
    {signature["HigherPoleRows"], signature["TerminalResidueRows"],
      Lookup[signature["GeneralizedCutRecords"],
        {"RegulatorValuation", "CutForm"}],
      Lookup[signature["PhysicalCutRecords"],
        {"TwistValuation", "RestrictedUnit"}]}
  ],
  {{}, {{DlogBasis`DimensionalRegulator}},
    {{1, DlogBasis`DimensionalRegulator}}, {{0, 1}, {1, 1}}},
  TestID -> "ordered-regulator-units-propagate-child-residue-forms"
]

VerificationTest[
  With[{signature = DlogBasis`DimensionallyRegulatedMaximalCutSignature[
      {(1 + y)/x^2}, x + y, {x, y}, {}, {x, y}
    ]},
    {signature["TerminalResidueRows"],
      Lookup[signature["GeneralizedCutRecords"],
        {"PoleOrders", "RegulatorValuation", "CutForm"}]}
  ],
  {{{DlogBasis`DimensionalRegulator}},
    {{{2, 0}, 1, DlogBasis`DimensionalRegulator}}},
  TestID -> "earlier-ordered-unit-can-create-a-later-cut-pole"
]

VerificationTest[
  With[{signature = DlogBasis`DimensionallyRegulatedMaximalCutSignature[
      {(1 + c y)/(x^2 y)}, x + y^2 (1 + c y),
      {x, y}, {c}, {x, y}
    ]},
    {signature["TerminalResidueRows"],
      Lookup[signature["GeneralizedCutRecords"],
        {"RegulatorValuation", "CutForm"}]}
  ],
  {{{-c^2 DlogBasis`DimensionalRegulator^2/2}},
    {{2, -c^2 DlogBasis`DimensionalRegulator^2/2}}},
  TestID -> "ordered-child-poles-set-the-local-regulator-order-bound"
]

VerificationTest[
  With[{signature = DlogBasis`DimensionallyRegulatedMaximalCutSignature[
      {(1 + Sqrt[a + x])/x^2,
        (1 + Sqrt[a + x]) (1 + c x)/x^2},
      1, {x}, {a, c}, {x}
    ]},
    {signature["HigherPoleRows"], signature["TerminalResidueRows"],
      signature["ExcludedCandidateRows"],
      Lookup[signature["CandidateResidualFailures"], "CandidatePosition"]}
  ],
  {{}, {}, {{1, 0}, {0, 1}}, {1, 2}},
  TestID -> "unresolved-algebraic-leading-factors-exclude-their-candidates"
]

VerificationTest[
  FreeQ[
    DownValues /@ {
      DlogBasis`Private`orderedAlgebraicCut,
      DlogBasis`Private`regulatedGeneralizedCutRecord,
      DlogBasis`Private`regulatedLocalResidue,
      DlogBasis`Private`mixedTaylorCoefficient
    },
    DlogBasis`Private`Series | DlogBasis`Private`SeriesCoefficient |
      Series | SeriesCoefficient
  ],
  True,
  TestID -> "ordered-cuts-contain-no-Mathematica-Series-backend"
]

VerificationTest[
  With[{signature = DlogBasis`DimensionallyRegulatedMaximalCutSignature[
      {1/Sqrt[x^2]}, 1, {x}, {}, {x}
    ]},
    {signature["HigherPoleRows"], signature["TerminalResidueRows"],
      signature["ExcludedCandidateRows"],
      Lookup[signature["CandidateResidualFailures"], "CandidatePosition"]}
  ],
  {{}, {}, {{1}}, {1}},
  TestID -> "ramified-cut-divisor-excludes-its-candidate"
]

VerificationTest[
  With[{signature = DlogBasis`DimensionallyRegulatedMaximalCutSignature[
      {1/x, 1/x^2}, 1, {x}, {}, {x}
    ]},
    {signature["HigherPoleRows"], signature["ExcludedCandidateRows"],
      signature["TerminalResidueRows"],
      signature["CutNullCandidatePositions"],
      signature["CandidateResidualFailures"],
      signature["CandidateResidualCompleteQ"]}
  ],
  {{}, {{0, 1}}, {{1, 0}}, {2}, {}, True},
  TestID -> "exact-cut-null-is-not-reported-as-unresolved"
]

VerificationTest[
  With[{signature = DlogBasis`DimensionallyRegulatedMaximalCutSignature[
      {1/x^2}, 1, {x}, {}, {x}
    ]},
    {signature["CutNullCandidatePositions"],
      signature["CandidateResidualCompleteQ"],
      signature["AffineAtlasCompleteQ"]}
  ],
  {{1}, True, True},
  TestID -> "all-cut-null-is-a-complete-empty-residual-search"
]

VerificationTest[
  Module[{family},
    family = DlogBasis`CreateDlogFamily[
      "LoopMomenta" -> {loopQ},
      "ExternalMomenta" -> {externalP},
      "Propagators" -> {(loopQ + externalP)^2}
    ];
    First[DlogBasis`LoopByLoopBaikovChart[family, {1}, #]]& /@ {
      {<|"Momentum" -> externalP, "BaseDimension" -> 2|>},
      {<|"Momentum" -> loopQ + externalP, "BaseDimension" -> 2|>},
      {<|"Momentum" -> loopQ, "BaseDimension" -> 2|>,
       <|"Momentum" -> loopQ, "BaseDimension" -> 4|>},
      {}
    }
  ],
  ConstantArray["InvalidLoopSpecifications", 4],
  TestID -> "loop-specifications-must-be-exact-loop-permutation"
]

VerificationTest[
  First@DlogBasis`DlogBasisSearch[
    twoLoop["Family"], twoLoop["Sector"],
    "LoopSpecifications" -> Take[twoLoop["Common4DOrder"], 1],
    "NumeratorDegreeBound" -> 1,
    "FiniteFlowPackageFile" -> finiteFlowFile
  ],
  "InvalidLoopSpecifications",
  TestID -> "automatic-numerator-chart-scan-preserves-loop-input-failure"
]

VerificationTest[
  With[{lattice = DlogBasis`EnumerateDlogCandidates[
      threeLoop["Family"], threeLoop["Sector"], 3, 0]},
    lattice["CandidateCount"]
  ],
  120,
  TestID -> "3l5p-bound3-keeps-complete-120-atom-lattice"
]

VerificationTest[
  With[{chart = DlogBasis`LoopByLoopBaikovChart[
      threeLoop["Family"], threeLoop["Sector"],
      threeLoop["LoopSpecifications"], threeLoop["NumeratorPositions"]]},
    {Abs[Det[chart["CoordinateMatrix"]]],
      Lookup[chart["LoopData"], "ExternalCount"],
      chart["FamilyPropagatorValues"] === chart["BaikovVariables"]}
  ],
  {32768, {6, 5, 4}, True},
  TestID -> "collaborator-3l5p-PBP-top-sector-LBL-chart"
]

VerificationTest[
  Module[{result, failures},
    result = DlogBasis`DlogBasisSearch[
      twoLoop["Family"], twoLoop["Sector"],
      "LoopSpecifications" -> twoLoop["Common4DOrder"]
    ];
    failures = result["LeadingSingularitySignature"][
      "CandidateResidualFailures"
    ];
    {result["ScientificStatus"],
      result["CandidateLattice"]["CandidateCount"],
      Length[failures],
      AllTrue[Lookup[failures, "Failure"], FailureQ],
      result["CandidateCombinations"] === {},
      result["ConstantLeadingSingularityCertifiedQ"]}
  ],
  {"UnresolvedGeneralizedCutCandidates", 1, 1, True, True,
    False},
  TestID -> "2l5p-noninteger-Gram-cover-is-not-falsely-certified"
]

VerificationTest[
  Module[{result, signature, lift, rationalRows, algebraicRows,
    momenta, delta5, denominator, parityEven, expectedAlgebraic,
    expectedRational, proportionalQ},
    result = DlogBasis`DlogBasisSearch[
      twoLoop["Family"], twoLoop["Sector"],
      "LoopSpecifications" -> Reverse[twoLoop["Common4DOrder"]]
    ];
    signature = result["LeadingSingularitySignature"];
    lift = result["ModuleLift"];
    rationalRows = Flatten[lift["RationalResidueRows"]];
    algebraicRows = Flatten[lift["AlgebraicResidueRows"]];
    momenta = twoLoop["Family"]["ExternalMomenta"];
    delta5 = Factor[
      Det[Table[2 momenta[[i]] momenta[[j]], {i, 4}, {j, 4}] /.
        twoLoop["Family"]["KinematicRules"]]
    ];
    denominator = DlogBasisTests`Massless2L5P`s12*
      DlogBasisTests`Massless2L5P`s23*
      DlogBasisTests`Massless2L5P`s34*
      DlogBasisTests`Massless2L5P`s45^2*
      DlogBasisTests`Massless2L5P`s51;
    parityEven = DlogBasisTests`Massless2L5P`s12*
        DlogBasisTests`Massless2L5P`s23 -
      DlogBasisTests`Massless2L5P`s23*
        DlogBasisTests`Massless2L5P`s34 +
      DlogBasisTests`Massless2L5P`s34*
        DlogBasisTests`Massless2L5P`s45 -
      DlogBasisTests`Massless2L5P`s12*
        DlogBasisTests`Massless2L5P`s51 +
      DlogBasisTests`Massless2L5P`s45*
        DlogBasisTests`Massless2L5P`s51;
    expectedAlgebraic = 1/denominator;
    expectedRational = parityEven/denominator;
    proportionalQ[value_, expected_] :=
      NumberQ[Factor[Together[value/expected]]];
    {
      result["ScientificStatus"],
      Lookup[signature["AlgebraicField"], "SquareClass"] === {delta5} &&
        First[signature["AlgebraicField"]][
          "MinimalPolynomialCoefficients"].{1, Sqrt[delta5], delta5} === 0,
      Dimensions[signature["TerminalResidueRows"]],
      AnyTrue[algebraicRows, proportionalQ[#, expectedAlgebraic]&],
      AnyTrue[rationalRows, proportionalQ[#, expectedRational]&],
      Length[lift["CoefficientDirections"]],
      Lookup[signature, {"FiniteDivisorsOnlyQ", "InfinityCheckedQ",
        "BranchTransitionsCheckedQ", "ChartTransitionsCheckedQ"}],
      result["ConstantLeadingSingularityCertifiedQ"]
    }
  ],
  {"NoCandidateWithinBounds", True, {3, 1}, True, True, 0,
    {True, False, False, False}, False},
  TestID -> "2l5p-scalar-signature-has-rational-and-Gram-root-components"
]

VerificationTest[
  Module[{signature, singularities, symmetric, antisymmetric},
    signature = DlogBasis`AlgebraicMaximalCutSignature[
      {(u x + v)/(a x^2 + b x + c)}, {x}, {a, b, c, u, v}, {}
    ];
    singularities = Flatten[signature["TerminalResidueRows"]];
    symmetric = u/(2 a);
    antisymmetric = (2 a v - u b)/(2 a Sqrt[b^2 - 4 a c]);
    And@@MapThread[TrueQ[Factor[Together[#1 - #2]] === 0]&,
      {singularities, {symmetric + antisymmetric,
        symmetric - antisymmetric}}]
  ],
  True,
  TestID -> "quadratic-divisor-local-residues-follow-paper-formula"
]

VerificationTest[
  {
    First@DlogBasis`AlgebraicMaximalCutSignature[
      {Exp[s]/(z - 1)}, {z}, {s}, {}
    ],
    Lookup[
      DlogBasis`AlgebraicMaximalCutSignature[{Sqrt[s] z}, {z}, {s}, {}],
      {"FiniteDivisorsOnlyQ", "InfinityCheckedQ"}
    ]
  },
  {"UnsupportedAlgebraicForm", {True, False}},
  TestID -> "algebraic-dispatch-is-typed-and-infinity-is-not-overclaimed"
]

VerificationTest[
  First@DlogBasis`AlgebraicMaximalCutSignature[
    {1/(x Sqrt[x])}, {x, z}, {}, {x}
  ],
  "RamifiedCutDivisor",
  TestID -> "ramified-Puiseux-cut-is-not-treated-as-zero-residue"
]

VerificationTest[
  Module[{dotted, cubic},
    dotted = DlogBasis`AlgebraicMaximalCutSignature[
      {1/(z - 1)^2}, {z}, {}, {}
    ];
    cubic = DlogBasis`AlgebraicMaximalCutSignature[
      {1/(z^3 + z + 1)}, {z}, {}, {}
    ];
    {dotted["HigherPoleRows"], dotted["TerminalResidueRows"], First[cubic]}
  ],
  {{{1}}, {}, "HigherDegreeAlgebraicDivisor"},
  TestID -> "univariate-dots-become-constraints-and-cubic-divisors-remain-unresolved"
]

VerificationTest[
  Module[{q, signature, simple, dotted},
    q = z^5 + z + a;
    signature = DlogBasis`ImplicitDivisorPrincipalPart[
      {1/q, z/q, 1/q^2}, z, q
    ];
    simple = signature["ResidueElements"][[1]];
    dotted = signature["ResidueElements"][[3]];
    {
      signature["Degree"],
      FreeQ[signature, _Root | Power[_, exponent_Rational] /;
        Denominator[exponent] === 2],
      TrueQ[Factor[Together[PolynomialRemainder[
        Together[simple D[q, z] - 1], q, z
      ]]] === 0],
      TrueQ[Factor[Together[
        DlogBasis`Private`implicitQuotientReduce[
          dotted - D[1/D[q, z], z]/D[q, z], z, q
        ]
      ]] === 0],
      Length[signature["HigherPoleRows"]]
    }
  ],
  {5, True, True, True, 5},
  TestID -> "implicit-quintic-principal-part-never-solves-for-roots"
]

VerificationTest[
  With[{signature = DlogBasis`ImplicitAlgebraicResidueSignature[
      {Sqrt[s (1 + x + y)]/(x y)}, {x, y}, {s}
    ]},
    {signature["Backend"], signature["FiniteDivisors"],
      signature["DivisorPairs"], signature["HigherPoleRows"],
      signature["TerminalResidueRows"], signature["AffineAtlasCompleteQ"]}
  ],
  {"ImplicitAlgebraicFinitePairsExperimental", {x, y}, {{x, y}}, {},
    {{-Sqrt[s]}, {Sqrt[s]}}, True},
  TestID -> "implicit-cover-enumerates-all-finite-simple-divisor-pairs"
]

VerificationTest[
  Module[{signature, lift},
    signature = DlogBasis`AlgebraicMaximalCutSignature[
      {Sqrt[2 s]/z}, {z}, {s}, {}
    ];
    lift = DlogBasis`Private`AlgebraicConstantLSLift[
      signature, {s}, "Singular"
    ];
    {Lookup[signature["AlgebraicField"], "SquareClass"],
      lift["CoefficientDirections"], lift["DirectionParities"],
      lift["ConstantResidueDirections"], lift["ModuleLiftVerifiedQ"]}
  ],
  {{2 s}, {{1/Sqrt[2 s]}}, {"Odd"}, {{1}}, True},
  TestID -> "nonsquare-rational-content-remains-in-one-quadratic-field"
]

VerificationTest[
  Module[{signature, lift},
    signature = DlogBasis`AlgebraicMaximalCutSignature[
      {(Sqrt[2] + Sqrt[s])/z}, {z}, {s}, {}
    ];
    lift = DlogBasis`Private`AlgebraicConstantLSLift[
      signature, {s}, "Singular"
    ];
    {Lookup[signature["AlgebraicField"], "SquareClass"],
      Length[lift["CoefficientDirections"]], lift["DirectionParities"],
      lift["ConstantResidueDirections"], lift["ModuleLiftVerifiedQ"]}
  ],
  {{2, s}, 1, {"Algebraic"}, {{1}}, True},
  TestID -> "independent-square-classes-use-one-finite-algebra-basis"
]

VerificationTest[
  Module[{signature, lift},
    signature = DlogBasis`AlgebraicMaximalCutSignature[
      {
        Sqrt[a]/((x^2 - a) (w^2 - b)),
        Sqrt[b]/((x^2 - a) (w^2 - b))
      },
      {x, w}, {a, b}, {}, "FiniteFlowPackageFile" -> finiteFlowFile
    ];
    lift = DlogBasis`Private`AlgebraicConstantLSLift[
      signature, {a, b}, "Singular"
    ];
    {
      signature["Backend"],
      Length[signature["TerminalResidueRows"]],
      SortBy[Lookup[signature["AlgebraicField"], "SquareClass"], ToString],
      Length[lift["CoefficientDirections"]],
      AllTrue[Flatten[lift["ConstantResidueDirections"]], NumberQ],
      lift["ModuleLiftVerifiedQ"]
    }
  ],
  {"ExactLocalQuadraticDivisorTree", 4, {a, b}, 1, True, True},
  TestID -> "two-independent-roots-factor-quadratic-divisors-and-lift"
]

VerificationTest[
  Module[{signature, lift},
    signature = DlogBasis`AlgebraicMaximalCutSignature[
      {(Sqrt[a] + Sqrt[b] + Sqrt[a b])/z}, {z}, {a, b}, {},
      "FiniteFlowPackageFile" -> finiteFlowFile
    ];
    lift = DlogBasis`Private`AlgebraicConstantLSLift[
      signature, {a, b}, "Singular"
    ];
    {SortBy[Lookup[signature["AlgebraicField"], "SquareClass"], ToString],
      Length[lift["FieldBasis"]], Length[lift["CoefficientDirections"]],
      lift["ModuleLiftVerifiedQ"]}
  ],
  {{a, b}, 4, 1, True},
  TestID -> "dependent-root-sqrt-ab-does-not-add-a-third-generator"
]

VerificationTest[
  Module[{signature, lift, direction},
    signature = <|
      "AlgebraicField" -> {
        <|"SquareClass" -> a|>, <|"SquareClass" -> b|>
      },
      "HigherPoleRows" -> {{Sqrt[a], -Sqrt[b]}},
      "TerminalResidueRows" -> {{Sqrt[a], Sqrt[b]}}
    |>;
    lift = DlogBasis`Private`AlgebraicConstantLSLift[
      signature, {a, b}, "Singular"
    ];
    direction = First[lift["CoefficientDirections"]];
    {Factor[Together[Sqrt[a] direction[[1]] - Sqrt[b] direction[[2]]]],
      Factor[Together[Sqrt[a] direction[[1]] + Sqrt[b] direction[[2]]]],
      lift["DirectionParities"], lift["ModuleLiftVerifiedQ"]}
  ],
  {0, 1, {"Algebraic"}, True},
  TestID -> "finite-algebra-block-allows-different-root-coefficients"
]

VerificationTest[
  Module[{field, rebased},
    field = DlogBasis`Private`multiquadraticFieldData[{a}];
    rebased = DlogBasis`Private`algebraicDirectionRebasis[
      {{1, a}, {0, 1}}, {{1}, {1}}, field, {a}
    ];
    {rebased["Parities"], FreeQ[rebased["Targets"], a]}
  ],
  {{"Odd", "Algebraic"}, True},
  TestID -> "algebraic-rebasis-keeps-residue-targets-constant"
]

VerificationTest[
  Module[{signature, lift, values},
    signature = DlogBasis`AlgebraicMaximalCutSignature[
      {1/(x^2 + 1), x/(x^2 + 1)}, {x}, {}, {},
      "FiniteFlowPackageFile" -> finiteFlowFile
    ];
    lift = DlogBasis`Private`AlgebraicConstantLSLift[
      signature, {}, "Singular"
    ];
    values = signature["TerminalResidueRows"].#& /@
      lift["CoefficientDirections"];
    {Lookup[signature["AlgebraicField"], "SquareClass"],
      Length[lift["CoefficientDirections"]],
      AllTrue[Flatten[values], NumberQ], lift["ModuleLiftVerifiedQ"]}
  ],
  {{-1}, 2, True, True},
  TestID -> "exact-complex-residues-use-the-sqrt-minus-one-field-component"
]

VerificationTest[
  With[{signature = DlogBasis`AlgebraicMaximalCutSignature[
      {x/((x - I) (y - 1))}, {x, y}, {}, {},
      "FiniteFlowPackageFile" -> finiteFlowFile
    ]},
    {signature["Backend"],
      Lookup[signature["AlgebraicField"], "SquareClass"],
      signature["TerminalResidueRows"]}
  ],
  {"ExactLocalQuadraticDivisorTree", {-1}, {{-I}}},
  TestID -> "multivariate-complex-rational-forms-use-the-algebraic-tree"
]

VerificationTest[
  First@DlogBasis`AlgebraicMaximalCutSignature[
    {Sqrt[a]/((x^2 - y)^3 (y^2 + 1))}, {x, y}, {a}, {},
    "FiniteFlowPackageFile" -> finiteFlowFile
  ],
  "MultivariateAlgebraicCoverUnresolved",
  TestID -> "variable-dependent-algebraic-roots-do-not-enter-rational-Laurent-graphs"
]

VerificationTest[
  First@DlogBasis`AlgebraicMaximalCutSignature[
    {Sqrt[a (1 + I)]/z}, {z}, {a}, {}
  ],
  "UnsupportedNestedComplexSquareClass",
  TestID -> "nested-complex-square-classes-stay-outside-base-multiquadratic-field"
]

VerificationTest[
  Module[{signature, lift},
    signature = DlogBasis`AlgebraicMaximalCutSignature[
      {1/(z - 1)^2 + 1/(z - 1),
        -1/(z - 1)^2 + 2/(z - 1)},
      {z}, {}, {}
    ];
    lift = DlogBasis`Private`AlgebraicConstantLSLift[
      signature, {}, "Singular"
    ];
    {signature["HigherPoleRows"], signature["TerminalResidueRows"],
      lift["CoefficientDirections"], lift["ConstantResidueDirections"],
      lift["ModuleLiftVerifiedQ"]}
  ],
  {{{1, -1}}, {{1, 2}}, {{1/3, 1/3}}, {{1}}, True},
  TestID -> "algebraic-signature-module-lift-cancels-dotted-double-pole"
]

VerificationTest[
  First@DlogBasis`AlgebraicMaximalCutSignature[
      {(1 + Sqrt[s] z)/x^2 + 1/(x z),
        (1 - Sqrt[s] z)/x^2 + 2/(x z)},
      {x, z}, {s}, {x}
    ],
  "NonCommonAlgebraicCutFactor",
  TestID -> "noncommon-candidate-units-are-not-mixed-in-one-FiniteFlow-basis"
]

VerificationTest[
  {
    First@Flatten@DlogBasis`AlgebraicMaximalCutSignature[
      {1/(x y)}, {x, y}, {}, {x}
    ]["TerminalResidueRows"],
    First@Flatten@DlogBasis`AlgebraicMaximalCutSignature[
      {1/(x y)}, {x, y}, {}, {y}
    ]["TerminalResidueRows"]
  },
  {1, -1},
  TestID -> "ordered-algebraic-cut-preserves-wedge-orientation"
]

VerificationTest[
  With[{signature = DlogBasis`AlgebraicMaximalCutSignature[
      {1/(x y w z), 1/(x z)}, {x, y, w, z}, {}, {x, y, w}
    ]},
    {signature["HigherPoleRows"], signature["TerminalResidueRows"]}
  ],
  {{}, {{1, 0}}},
  TestID -> "zero-form-survives-later-ordered-cuts-with-infinite-start-order"
]

VerificationTest[
  Module[{result, failures},
    result = DlogBasis`DlogBasisSearch[
      twoLoop["Family"], twoLoop["Sector"],
      "LoopSpecifications" -> twoLoop["Common4DOrder"],
      "NumeratorDegreeBound" -> 1,
      "NumeratorPositions" -> {}
    ];
    failures = result["LeadingSingularitySignature"][
      "CandidateResidualFailures"
    ];
    {result["ScientificStatus"],
      result["CandidateLattice"]["CandidateCount"],
      DeleteDuplicates[First /@ Lookup[failures, "Failure"]],
      Length[result["RepresentedCandidates"]],
      Lookup[failures, "CandidatePosition"],
      Length[result["CandidateCombinations"]]}
  ],
  {"UnresolvedGeneralizedCutCandidates", 4,
    {"MultivariateAlgebraicCoverUnresolved"}, 3, {1, 2, 3}, 0},
  TestID -> "2l5p-explicit-partial-numerator-chart-remains-bivariate"
]

VerificationTest[
  Module[{result, lift, residuals},
    result = DlogBasis`DlogBasisSearch[
      twoLoop["Family"], twoLoop["Sector"],
      "LoopSpecifications" -> Reverse[twoLoop["Common4DOrder"]],
      "NumeratorDegreeBound" -> 1,
      "NumeratorPositions" -> {}
    ];
    lift = result["ModuleLift"];
    residuals = Flatten[lift["ExpandedLift"]["LiftResiduals"]];
    {
      result["ScientificStatus"],
      {result["CandidateLattice"]["CandidateCount"],
        Length[result["RepresentedCandidates"]]},
      Lookup[result["RepresentedCandidates"], "IndexVector"],
      result["CandidateParities"],
      Length[result["CandidateCombinations"]],
      AllTrue[residuals, TrueQ[Factor[Together[#]] === 0]&],
      result["AffineFiniteConstantResiduesVerifiedQ"],
      result["ConstantLeadingSingularityCertifiedQ"]
    }
  ],
  {"FiniteUnivariateAlgebraicConstantLSCandidatePartialChart", {4, 2},
    {{1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0},
      {1, 1, 1, 1, 1, 1, 1, 1, -1, 0, 0}},
    {"Even", "Odd"}, 2, True, True, False},
  TestID -> "2l5p-top-sector-returns-even-and-odd-constant-LS-candidates"
]

VerificationTest[
  Module[{result, block},
    result = DlogBasis`DlogBasisSearch[
      twoLoop["Family"], twoLoop["Sector"],
      "LoopSpecifications" -> twoLoop["Common4DOrder"],
      "NumeratorDegreeBound" -> 1,
      "NumeratorPositions" -> {},
      "FiniteFlowPackageFile" -> finiteFlowFile,
      "ResidualBackend" -> "ImplicitAlgebraicExperimental"
    ];
    block = First[
      result["LeadingSingularitySignature"]["CandidateResidualSignatures"]
    ]["Signature"];
    {
      result["ScientificStatus"],
      result["LeadingSingularitySignature"]["ResidualBackends"],
      Length[block["FiniteDivisors"]],
      Length[block["DivisorPairs"]],
      Dimensions[result["LeadingSingularitySignature"][
        "TerminalResidueRows"]],
      Length[result["CandidateCombinations"]],
      result["ModuleLift"]["ModuleLiftVerifiedQ"],
      result["LeadingSingularitySignature"]["CandidateResidualCompleteQ"],
      result["LeadingSingularitySignature"]["AffineAtlasCompleteQ"],
      result["AffineFiniteConstantResiduesVerifiedQ"],
      result["ConstantLeadingSingularityCertifiedQ"]
    }
  ],
  {"NoConstantLSCandidateAmongRepresentedCandidatesPartialChart",
    {"ImplicitAlgebraicFinitePairsExperimental"}, 3, 3, {10, 3},
    0, True, True, True, False, False},
  TestID -> "2l5p-forward-top-rejects-coordinate-only-false-positive"
]

VerificationTest[
  Module[{settings, results},
    settings = {
      {2, Reverse[twoLoop["Common4DOrder"]]},
      {5, Reverse[twoLoop["Common4DOrder"]]},
      {7, twoLoop["Common4DOrder"]}
    };
    results = DlogBasis`DlogBasisSearch[
        twoLoop["Family"], ReplacePart[twoLoop["Sector"], First[#] -> 0],
        "LoopSpecifications" -> Last[#],
        "NumeratorDegreeBound" -> 1,
        "NumeratorPositions" -> {},
        "FiniteFlowPackageFile" -> finiteFlowFile
      ]& /@ settings;
    {
      Lookup[results, "ScientificStatus"],
      ({#["CandidateLattice"]["CandidateCount"],
          Length[#["RepresentedCandidates"]],
          Length[#["CandidateCombinations"]]}& /@ results),
      Lookup[results, "CandidateParities", {}],
      Lookup[results, "AffineFiniteConstantResiduesVerifiedQ"],
      Lookup[results, "ConstantLeadingSingularityCertifiedQ"]
    }
  ],
  {{"AffineFiniteMaximalCutCandidatePartialChart",
      "FiniteUnivariateAlgebraicConstantLSCandidatePartialChart",
      "AffineFiniteMaximalCutCandidatePartialChart"},
    {{5, 2, 2}, {5, 2, 2}, {5, 3, 1}},
    {{}, {"Even", "Odd"}, {}},
    {True, True, True}, {False, False, False}},
  TestID -> "2l5p-single-pinches-return-constant-LS-candidates"
]

VerificationTest[
  Module[{sixDimensionalOrder, result},
    sixDimensionalOrder = (
      <|"Momentum" -> #, "BaseDimension" -> 6|>& /@
        Reverse[twoLoop["Family"]["LoopMomenta"]]
    );
    result = DlogBasis`DlogBasisSearch[
      twoLoop["Family"], twoLoop["Sector"],
      "LoopSpecifications" -> sixDimensionalOrder,
      "NumeratorDegreeBound" -> 1,
      "NumeratorPositions" -> {}
    ];
    {result["ScientificStatus"], result["CandidateParities"],
      Length[result["CandidateCombinations"]],
      result["AffineFiniteConstantResiduesVerifiedQ"]}
  ],
  {"FiniteUnivariateAlgebraicConstantLSCandidatePartialChart",
    {"Odd"}, 1, True},
  TestID -> "2l5p-top-sector-dimension-six-changes-constant-LS-space"
]

VerificationTest[
  Module[{twoDimensionalOrder, result},
    twoDimensionalOrder = (
      <|"Momentum" -> #, "BaseDimension" -> 2|>& /@
        Reverse[twoLoop["Family"]["LoopMomenta"]]
    );
    result = DlogBasis`DlogBasisSearch[
      twoLoop["Family"], twoLoop["Sector"],
      "LoopSpecifications" -> twoDimensionalOrder,
      "NumeratorDegreeBound" -> 1,
      "NumeratorPositions" -> {}
    ];
    {result["ScientificStatus"],
      {result["CandidateLattice"]["CandidateCount"],
        Length[result["RepresentedCandidates"]]},
      Length[result["CandidateCombinations"]],
      result["ConstantLeadingSingularityCertifiedQ"]}
  ],
  {"NoConstantLSCandidateAmongRepresentedCandidatesPartialChart",
    {4, 2}, 0, False},
  TestID -> "2l5p-two-dimensional-top-does-not-overstate-partial-chart-exhaustion"
]

VerificationTest[
  With[{signature = DlogBasis`FinitePoleSignature[
      {Together[1/x^2 + 1/x], Together[-1/x^2 + 2/x]},
      {x}, {}, "InitialDivisors" -> {x},
      "FiniteFlowPackageFile" -> finiteFlowFile]},
    {signature["HigherPoleRows"], signature["TerminalResidueRows"]}
  ],
  {{{1, -1}}, {{1, 2}}},
  TestID -> "FiniteFlow-full-principal-part-includes-dot-obstruction"
]

VerificationTest[
  With[{signature = DlogBasis`FinitePoleSignature[
      {Together[1/x^4 + aa/x^3 + bb/x^2 + cc/x]},
      {x}, {aa, bb, cc}, "InitialDivisors" -> {x},
      "FiniteFlowPackageFile" -> finiteFlowFile]},
    {Lookup[signature["HigherPoleRecords"], {"Order", "CoefficientForm"}],
      signature["TerminalResidueRows"]}
  ],
  {{{-4, {1}}, {-3, {aa}}, {-2, {bb}}}, {{cc}}},
  TestID -> "FiniteFlow-retains-every-negative-Laurent-coefficient"
]

VerificationTest[
  With[{signature = DlogBasis`FinitePoleSignature[
      {1/(x y)}, {x, y}, {},
      "FiniteFlowPackageFile" -> finiteFlowFile]},
    Lookup[signature["TerminalResidueRecords"], {"Flag", "ResidueRow"}]
  ],
  {{{x, y}, {1}}, {{y, x}, {-1}}},
  TestID -> "positive-dimensional-residue-recurses-as-child-form"
]

VerificationTest[
  Module[{simple, dotted},
    simple = DlogBasis`AlgebraicMaximalCutSignature[
      {1/(Sqrt[-x^2] Sqrt[y^2]),
        2/(Sqrt[-x^2] Sqrt[y^2])},
      {x, y}, {}, {},
      "FiniteFlowPackageFile" -> finiteFlowFile
    ];
    dotted = DlogBasis`AlgebraicMaximalCutSignature[
      {1/(x^2 Sqrt[y^2])}, {x, y}, {}, {},
      "FiniteFlowPackageFile" -> finiteFlowFile
    ];
    {simple["Backend"], simple["HigherPoleRows"],
      simple["TerminalResidueRows"], dotted["HigherPoleRows"],
      dotted["TerminalResidueRows"]}
  ],
  {"ExactLocalQuadraticDivisorTree", {}, {{1, 2}},
    {{1}, {-1}}, {}},
  TestID -> "certified-square-cover-keeps-one-canonical-divisor-flag-with-dots"
]

VerificationTest[
  With[{signature = DlogBasis`AlgebraicMaximalCutSignature[
      {1/(Sqrt[x^2] Sqrt[y^2]), 1/(Sqrt[-x^2] Sqrt[y^2])},
      {x, y}, {}, {}, "FiniteFlowPackageFile" -> finiteFlowFile
    ]},
    {signature["Backend"],
      Lookup[signature["AlgebraicField"], "SquareClass"],
      signature["TerminalResidueRows"]}
  ],
  {"ExactLocalQuadraticDivisorTree", {-1}, {{1, -I}}},
  TestID -> "noncommon-constant-phases-use-the-sqrt-minus-one-field"
]

VerificationTest[
  Module[{signature, lift},
    signature = DlogBasis`AlgebraicMaximalCutSignature[
      {1/(u^2 Sqrt[x^2] Sqrt[y^2]),
        -1/(u^2 Sqrt[x^2] Sqrt[y^2]) +
          1/(u Sqrt[x^2] Sqrt[y^2])},
      {u, x, y}, {}, {u}, "FiniteFlowPackageFile" -> finiteFlowFile
    ];
    lift = DlogBasis`Private`AlgebraicConstantLSLift[
      signature, {}, "Singular"
    ];
    {signature["HigherPoleRows"], signature["TerminalResidueRows"],
      lift["CoefficientDirections"], lift["ModuleLiftVerifiedQ"]}
  ],
  {{{1, -1}}, {{0, 1}, {0, -1}}, {{1, 1}}, True},
  TestID -> "ordered-cut-dots-merge-with-rationalized-residual-divisor-rows"
]

VerificationTest[
  Lookup[
    DlogBasis`SingularModuleLift[{{1, -1}}, {{1, 2}}, {}],
    {"CoefficientDirections", "ConstantResidueDirections", "ModuleLiftVerifiedQ"}
  ],
  {{{1/3, 1/3}}, {{1}}, True},
  TestID -> "Singular-module-lift-cancels-double-pole"
]

VerificationTest[
  Lookup[
    DlogBasis`SingularModuleLift[{{1, -1}}, {{1, s}}, {s}],
    {"CoefficientDirections", "ConstantTargetBasis", "ModuleLiftVerifiedQ"}
  ],
  {{{1/(1 + s), 1/(1 + s)}}, {{1}}, True},
  TestID -> "kinematic-rational-normalization-matches-original-Solve-semantics"
]

VerificationTest[
  Module[{lift, directions},
    lift = DlogBasis`SingularModuleLift[{}, {{1, -1}}, {}];
    directions = lift["CoefficientDirections"];
    {Length[directions], directions.{1, -1},
      lift["ConstantResidueDirections"], lift["ModuleLiftVerifiedQ"]}
  ],
  {1, {1}, {{1}}, True},
  TestID -> "zero-signature-syzygy-is-not-promoted-to-candidate"
]

VerificationTest[
  Lookup[
    DlogBasis`SingularModuleLift[
      {{-1, s, 0, 0}, {0, 0, 0, 1}},
      {{1/s, 0, 0, 0}, {-1/s, 0, 1, 0}},
      {s}
    ],
    {"CoefficientDirections", "ConstantResidueDirections",
      "ModuleLiftVerifiedQ"}
  ],
  {{{s, 1, 1, 0}, {0, 0, 1, 0}}, IdentityMatrix[2], True},
  TestID -> "module-lift-reproduces-original-DlogBasis-section-3.5"
]

VerificationTest[
  First@DlogBasis`FinitePoleSignature[
    {1/(x^2 + y^2)}, {x, y}, {},
    "FiniteFlowPackageFile" -> finiteFlowFile
  ]["UnresolvedDivisors"],
  _Failure,
  SameTest -> MatchQ,
  TestID -> "nonlinear-divisor-remains-scientifically-unresolved"
]

VerificationTest[
  First@DlogBasis`FinitePoleSignature[
    {1/(x^2 + y^2)}, {x, y}, {},
    "InitialDivisors" -> {x^2 + y^2},
    "FiniteFlowPackageFile" -> finiteFlowFile
  ],
  "NonLinearDivisorUnresolved",
  TestID -> "unsupported-fixed-initial-divisor-propagates-failure"
]

VerificationTest[
  DlogBasis`FinitePoleSignature[
    {Sqrt[1 + x]/x}, {x}, {},
    "FiniteFlowPackageFile" -> finiteFlowFile
  ],
  Failure["TwistedOrAlgebraicForm", _Association],
  SameTest -> MatchQ,
  TestID -> "twisted-form-is-not-sent-to-rational-FiniteFlow-graph"
]

VerificationTest[
  With[{signature = DlogBasis`FinitePoleSignature[
      {1/((x y + 1) z)}, {x, y, z}, {},
      "FiniteFlowPackageFile" -> finiteFlowFile
    ]},
    {signature["AffineAtlasCompleteQ"],
      Length[signature["UnresolvedDivisors"]],
      signature["TerminalResidueRows"]}
  ],
  {False, 2, {}},
  TestID -> "variable-leading-linear-divisor-is-local-only-by-default"
]

VerificationTest[
  With[{signature = DlogBasis`AlgebraicMaximalCutSignature[
      {1/(x z Sqrt[x^2 + x + 1])}, {x, z}, {}, {},
      "FiniteFlowPackageFile" -> finiteFlowFile
    ]},
    {signature["Backend"], signature["HigherPoleRows"],
      Sort@DeleteDuplicates@Flatten[signature["TerminalResidueRows"]],
      Length[signature["ConicCharts"]],
      signature["AffineAtlasCompleteQ"]}
  ],
  {"FiniteFlowOnLocalRationalConicCharts", {}, {-1/2, 1/2}, 2, False},
  TestID -> "two-local-conic-charts-cover-both-affine-sheets"
]

VerificationTest[
  First@DlogBasis`AlgebraicMaximalCutSignature[
    {1/(z Sqrt[x^2 - 1]), 1/z}, {x, z}, {}, {},
    "FiniteFlowPackageFile" -> finiteFlowFile
  ],
  "NonCommonAlgebraicConstantPhase",
  TestID -> "mixed-conic-sheet-phases-fail-closed"
]

VerificationTest[
  Module[{sector, result, directions, undotted, dotted},
    sector = Join[Reverse[IntegerDigits[182, 2, 8]], {0, 0, 0}];
    result = DlogBasis`DlogBasisSearch[
      twoLoop["Family"], sector,
      "LoopSpecifications" -> twoLoop["Common4DOrder"],
      "DotDegreeBound" -> 1,
      "FiniteFlowPackageFile" -> finiteFlowFile
    ];
    directions = result["ModuleLift"]["CoefficientDirections"];
    undotted = SelectFirst[directions, TrueQ[#[[1]] =!= 0]&];
    dotted = SelectFirst[directions, TrueQ[#[[2]] =!= 0]&];
    {result["ScientificStatus"], Length[directions],
      NumberQ@Factor[
        undotted[[1]]/(
          DlogBasisTests`Massless2L5P`s12 +
          DlogBasisTests`Massless2L5P`s23
        )
      ],
      AllTrue[Rest[undotted], TrueQ[# === 0]&],
      NumberQ@Factor[
        dotted[[2]] DlogBasis`DimensionalRegulator/(
          DlogBasisTests`Massless2L5P`s12*
            DlogBasisTests`Massless2L5P`s23
        )
      ],
      TrueQ[dotted[[1]] === 0] &&
        AllTrue[Drop[dotted, 2], TrueQ[# === 0]&],
      result["ModuleLift"]["ModuleLiftVerifiedQ"],
      result["LeadingSingularitySignature"]["AffineAtlasCompleteQ"],
      result["LeadingSingularitySignature"]["CandidateResidualCompleteQ"],
      Lookup[
        result["LeadingSingularitySignature"]["CandidateResidualFailures"],
        "CandidatePosition"
      ]}
  ],
  {"AffineFiniteMaximalCutCandidatePartialGeneralizedCutCoverage", 2,
    True, True, True, True, True, False, False, {6}},
  TestID -> "2l5p-sector-182-recovers-undotted-and-dot8-candidates"
]

VerificationTest[
  Module[{sector, result, direction, expected},
    sector = Join[Reverse[IntegerDigits[246, 2, 8]], {0, 0, 0}];
    result = DlogBasis`DlogBasisSearch[
      twoLoop["Family"], sector,
      "LoopSpecifications" -> twoLoop["Common4DOrder"],
      "DotDegreeBound" -> 1,
      "FiniteFlowPackageFile" -> finiteFlowFile
    ];
    direction = First[result["ModuleLift"]["CoefficientDirections"]];
    expected = DlogBasisTests`Massless2L5P`s45 (
      DlogBasisTests`Massless2L5P`s34 -
        DlogBasisTests`Massless2L5P`s51
    );
    {result["ScientificStatus"],
      result["LeadingSingularitySignature"]["Backend"],
      NumberQ[Factor[First[direction]/expected]],
      AllTrue[Rest[direction], TrueQ[# === 0]&],
      result["ModuleLift"]["ModuleLiftVerifiedQ"],
      result["LeadingSingularitySignature"]["CandidateResidualCompleteQ"],
      Lookup[
        result["LeadingSingularitySignature"]["CandidateResidualFailures"],
        "CandidatePosition"
      ]}
  ],
  {"FiniteAlgebraicConstantLSCandidatePartialGeneralizedCutCoverage",
    "RegulatedGeneralizedCut", True, True, True, False, {3, 7}},
  TestID -> "2l5p-sector-246-is-recovered-by-quadratic-divisor-tree"
]

VerificationTest[
  Module[{family, result},
    family = DlogBasis`CreateDlogFamily[
      "Name" -> "InfinityCounterexample",
      "LoopMomenta" -> {infinityLoop},
      "ExternalMomenta" -> {},
      "Propagators" -> {infinityLoop^2, infinityLoop^2 + 1}
    ];
    result = DlogBasis`DlogBasisSearch[
      family, {1, 0},
      "LoopSpecifications" -> {
        <|"Momentum" -> infinityLoop, "BaseDimension" -> 2|>
      },
      "NumeratorDegreeBound" -> 1,
      "FiniteFlowPackageFile" -> finiteFlowFile
    ];
    {result["ScientificStatus"],
      result["AffineFiniteConstantResiduesVerifiedQ"],
      result["ConstantLeadingSingularityCertifiedQ"],
      KeyExistsQ[result, "CandidateCombinations"],
      KeyExistsQ[result, "Basis"]}
  ],
  {"AffineFiniteMaximalCutCandidate", True, False, True, False},
  TestID -> "finite-affine-result-is-not-global-constant-LS-certificate"
]

VerificationTest[
  Module[{family, result},
    family = DlogBasis`CreateDlogFamily[
      "Name" -> "TwoDimensionalTadpole",
      "LoopMomenta" -> {q},
      "ExternalMomenta" -> {},
      "Propagators" -> {q^2}
    ];
    result = DlogBasis`DlogBasisSearch[
      family, {1},
      "LoopSpecifications" -> {<|"Momentum" -> q, "BaseDimension" -> 2|>},
      "DotDegreeBound" -> 1,
      "FiniteFlowPackageFile" -> finiteFlowFile
    ];
    {result["ScientificStatus"],
      Lookup[result["CandidateLattice"], "CandidateCount"],
      result["CandidateCombinations"],
      result["ModuleLift"]["ModuleLiftVerifiedQ"],
      result["ModuleLift"]["CoefficientRing"][
        "RationalFunctionParameters"]}
  ],
  {"AffineFiniteMaximalCutCandidate", 2,
    {DlogBasis`DlogIntegral[_, {1}]}, True,
    {DlogBasis`DimensionalRegulator}},
  SameTest -> MatchQ,
  TestID -> "end-to-end-2D-tadpole-with-dot-search"
]
