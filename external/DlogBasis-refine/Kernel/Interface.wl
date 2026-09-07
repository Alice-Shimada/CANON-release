(* Main interface: the supplied D0 is always evaluated at D=D0-2 epsilon. *)

Options[DlogBasisSearch] = {
  "LoopSpecifications" -> {},
  "NumeratorDegreeBound" -> 0,
  "DotDegreeBound" -> 0,
  "NumeratorPositions" -> Automatic,
  "FiniteFlowPackageFile" -> Automatic,
  "ResidualBackend" -> "Current",
  "SingularExecutable" -> "Singular"
};

DlogBasisSearch[
  family_Association,
  sector_List,
  OptionsPattern[]
] := Module[
  {lattice, numeratorPositions, search, chartResults, result, chart, mapped,
   represented, completeChartQ, baseForms, signature, parameters, lift,
   directions, parities, combinations, atlasCompleteQ, candidateStatus,
   scientificStatus, residualBackends, residualCompleteQ, constraintRows},
  lattice = EnumerateDlogCandidates[
    family, sector, OptionValue["NumeratorDegreeBound"],
    OptionValue["DotDegreeBound"]
  ];
  If[FailureQ[lattice], Return[lattice]];
  (* Candidate mode keeps numerator charts minimal instead of forcing one
     complete multivariate algebraic cover. *)
  If[
    OptionValue["NumeratorPositions"] === Automatic &&
      lattice["NumeratorDegreeBound"] > 0,
    search[positions_List] := Module[{searchResult},
      searchResult = DlogBasisSearch[
        family, sector,
        "LoopSpecifications" -> OptionValue["LoopSpecifications"],
        "NumeratorDegreeBound" -> OptionValue["NumeratorDegreeBound"],
        "DotDegreeBound" -> OptionValue["DotDegreeBound"],
        "NumeratorPositions" -> positions,
        "FiniteFlowPackageFile" -> OptionValue["FiniteFlowPackageFile"],
        "ResidualBackend" -> OptionValue["ResidualBackend"],
        "SingularExecutable" -> OptionValue["SingularExecutable"]
      ];
      If[FailureQ[searchResult], searchResult,
        Join[searchResult, <|"NumeratorPositions" -> positions|>]
      ]
    ];
    result = search[{}];
    If[FailureQ[result], Return[result]];
    numeratorPositions = result["Chart"]["UnrepresentedPropagatorPositions"];
    chartResults = Prepend[
      search /@ List /@ numeratorPositions,
      result
    ];
    If[MemberQ[chartResults, _Failure], Return[FirstCase[chartResults, _Failure]]];
    result = First@MaximalBy[
      chartResults,
      {
        Length[Lookup[#, "CandidateCombinations", {}]],
        Boole[KeyExistsQ[#, "LeadingSingularitySignature"]],
        Length[Lookup[#, "RepresentedCandidates", {}]]
      }&
    ];
    Return[Join[result, <|
      "CandidateGenerationMode" -> "SingletonNumeratorCharts",
      "NumeratorChartScan" -> Map[
        <|
          "NumeratorPositions" -> #["NumeratorPositions"],
          "ScientificStatus" -> #["ScientificStatus"],
          "RepresentedCount" -> Length[#["RepresentedCandidates"]],
          "CombinationCount" -> Length[#["CandidateCombinations"]],
          "CandidateCombinations" -> #["CandidateCombinations"],
          "CandidateParities" -> Lookup[#, "CandidateParities", {}]
        |>&,
        chartResults
      ]
    |>]]
  ];
  numeratorPositions = Replace[
    OptionValue["NumeratorPositions"], Automatic -> {}
  ];
  chart = LoopByLoopBaikovChart[
    family, sector, OptionValue["LoopSpecifications"], numeratorPositions
  ];
  If[FailureQ[chart], Return[chart]];
  mapped = MapDlogCandidates[chart, lattice["Candidates"]];
  represented = Select[mapped, #["MappingStatus"] === "Exact"&];
  completeChartQ = Length[represented] === Length[mapped];
  If[represented === {},
    Return[<|
      "ScientificStatus" -> "UnrepresentedCandidate",
      "DimensionConvention" -> chart["DimensionConvention"],
      "Regulator" -> DimensionalRegulator,
      "FamilyHash" -> family["FamilyHash"],
      "Sector" -> sector,
      "CandidateLattice" -> lattice,
      "Chart" -> chart,
      "MappedCandidates" -> mapped,
      "RepresentedCandidates" -> {},
      "CandidateChartCompleteQ" -> False,
      "CandidateCombinations" -> {},
      "AffineFiniteConstantResiduesVerifiedQ" -> False,
      "ConstantLeadingSingularityCertifiedQ" -> False,
      "UniformTranscendentalityCertifiedQ" -> False,
      "CanonicalBasisCertifiedQ" -> False
    |>]
  ];
  baseForms = Lookup[represented, "BaseBaikovForm"];
  signature = DimensionallyRegulatedMaximalCutSignature[
    baseForms,
    chart["RegulatorRatio"],
    chart["BaikovVariables"],
    family["KinematicVariables"],
    chart["PhysicalVariables"],
    "FiniteFlowPackageFile" -> OptionValue["FiniteFlowPackageFile"],
    "ResidualBackend" -> OptionValue["ResidualBackend"]
  ];
  If[FailureQ[signature],
    Return[<|
      "ScientificStatus" -> ToString[First[signature]],
      "DimensionConvention" -> chart["DimensionConvention"],
      "Regulator" -> DimensionalRegulator,
      "FamilyHash" -> family["FamilyHash"],
      "Sector" -> sector,
      "CandidateLattice" -> lattice,
      "Chart" -> chart,
      "MappedCandidates" -> mapped,
      "RepresentedCandidates" -> represented,
      "CandidateChartCompleteQ" -> completeChartQ,
      "LeadingSingularityFailure" -> signature,
      "CandidateCombinations" -> {},
      "AffineFiniteConstantResiduesVerifiedQ" -> False,
      "ConstantLeadingSingularityCertifiedQ" -> False,
      "UniformTranscendentalityCertifiedQ" -> False,
      "CanonicalBasisCertifiedQ" -> False
    |>]
  ];
  parameters = Append[family["KinematicVariables"], DimensionalRegulator];
  constraintRows = Lookup[
    signature, "ModuleConstraintRows", signature["HigherPoleRows"]
  ];
  If[signature["AlgebraicField"] === {},
    lift = SingularModuleLift[
      constraintRows, signature["TerminalResidueRows"],
      parameters,
      "SingularExecutable" -> OptionValue["SingularExecutable"]
    ];
    parities = {},
    lift = AlgebraicConstantLSLift[
      signature, parameters, OptionValue["SingularExecutable"]
    ];
    If[FailureQ[lift],
      Return[<|
        "ScientificStatus" -> ToString[First[lift]],
        "DimensionConvention" -> chart["DimensionConvention"],
        "Regulator" -> DimensionalRegulator,
        "FamilyHash" -> family["FamilyHash"],
        "Sector" -> sector,
        "CandidateLattice" -> lattice,
        "Chart" -> chart,
        "MappedCandidates" -> mapped,
        "RepresentedCandidates" -> represented,
        "CandidateChartCompleteQ" -> completeChartQ,
        "LeadingSingularitySignature" -> signature,
        "ModuleLiftFailure" -> lift,
        "CandidateCombinations" -> {},
        "AffineFiniteConstantResiduesVerifiedQ" -> False,
        "ConstantLeadingSingularityCertifiedQ" -> False,
        "UniformTranscendentalityCertifiedQ" -> False,
        "CanonicalBasisCertifiedQ" -> False
      |>]
    ];
    parities = lift["DirectionParities"]
  ];
  If[!TrueQ[lift["ModuleLiftVerifiedQ"]],
    Return[<|
      "ScientificStatus" -> "ModuleLiftVerificationFailed",
      "DimensionConvention" -> chart["DimensionConvention"],
      "Regulator" -> DimensionalRegulator,
      "FamilyHash" -> family["FamilyHash"],
      "Sector" -> sector,
      "CandidateLattice" -> lattice,
      "Chart" -> chart,
      "MappedCandidates" -> mapped,
      "RepresentedCandidates" -> represented,
      "CandidateChartCompleteQ" -> completeChartQ,
      "LeadingSingularitySignature" -> signature,
      "ModuleLift" -> lift,
      "CandidateCombinations" -> {},
      "AffineFiniteConstantResiduesVerifiedQ" -> False,
      "ConstantLeadingSingularityCertifiedQ" -> False,
      "UniformTranscendentalityCertifiedQ" -> False,
      "CanonicalBasisCertifiedQ" -> False
    |>]
  ];
  directions = Lookup[lift, "CoefficientDirections", {}];
  combinations = Factor[Total[#*Lookup[represented, "Integral"]]]& /@
    directions;
  atlasCompleteQ = TrueQ[Lookup[signature, "AffineAtlasCompleteQ", True]];
  residualCompleteQ = TrueQ[
    Lookup[signature, "CandidateResidualCompleteQ", True]
  ];
  residualBackends = Lookup[
    signature, "ResidualBackends", {signature["Backend"]}
  ];
  candidateStatus = Which[
    AnyTrue[
      residualBackends,
      StringContainsQ[#, "ExactAlgebraicUnivariate"]&
    ],
      "FiniteUnivariateAlgebraicConstantLSCandidate",
    AnyTrue[
      residualBackends,
      StringContainsQ[#, "FiniteFlowAfterCertifiedSquareReduction"]&
    ],
      "FiniteRationalizedAlgebraicConstantLSCandidate",
    signature["AlgebraicField"] =!= {},
      "FiniteAlgebraicConstantLSCandidate",
    True,
      "AffineFiniteMaximalCutCandidate"
  ];
  scientificStatus = Which[
    chart["RepresentationStatus"] === "MixedDimensionProposal",
      "MixedDimensionProposal",
    !residualCompleteQ && combinations === {},
      "UnresolvedGeneralizedCutCandidates",
    !residualCompleteQ,
      candidateStatus <> "PartialGeneralizedCutCoverage",
    !atlasCompleteQ,
      "FinitePoleConstraintsSatisfiedButAtlasIncomplete",
    !completeChartQ && combinations === {},
      "NoConstantLSCandidateAmongRepresentedCandidatesPartialChart",
    combinations === {},
      "NoCandidateWithinBounds",
    !completeChartQ,
      candidateStatus <> "PartialChart",
    True,
      candidateStatus
  ];
  <|
    "ScientificStatus" -> scientificStatus,
    "DimensionConvention" -> chart["DimensionConvention"],
    "Regulator" -> DimensionalRegulator,
    "FamilyHash" -> family["FamilyHash"],
    "Sector" -> sector,
    "CandidateLattice" -> lattice,
    "Chart" -> chart,
    "MappedCandidates" -> mapped,
    "RepresentedCandidates" -> represented,
    "CandidateChartCompleteQ" -> completeChartQ,
    "LeadingSingularitySignature" -> signature,
    "ModuleLift" -> lift,
    "CandidateCombinations" -> combinations,
    "CandidateParities" -> parities,
    "AffineFiniteConstantResiduesVerifiedQ" ->
      atlasCompleteQ && residualCompleteQ &&
        TrueQ[lift["ModuleLiftVerifiedQ"]] &&
        directions =!= {} &&
        chart["RepresentationStatus"] === "CommonDimension",
    "ConstantLeadingSingularityCertifiedQ" -> False,
    "UniformTranscendentalityCertifiedQ" -> False,
    "CanonicalBasisCertifiedQ" -> False
  |>
];
