(* Supplied-order loop-by-loop Baikov parametrization. *)

dlogZeroQ[expression_] := TrueQ[Cancel[expression] === 0];

(* Expand linear combinations of declared momenta before scalar-product rules. *)
expandVectorExpression[term_, vectors_List] := Module[{marked, scale},
  marked = term /. Dispatch[Thread[vectors -> (dlogVector /@ vectors)]];
  marked = marked /. {
    Dot[a_, b_] :> Dot[Expand[a], Expand[b]],
    q_^power_Integer /; EvenQ[power] &&
        Exponent[q /. dlogVector[x_] :> scale*dlogVector[x], scale] === 1 :>
      Expand[q]^power
  };
  marked = marked /. dlogVector[a_]*dlogVector[b_] :> dlogVector[a].dlogVector[b];
  marked = marked /. a_^power_Integer /;
      EvenQ[power] &&
        Exponent[a /. dlogVector[x_] :> scale*dlogVector[x], scale] === 1 :>
    (Expand[a].Expand[a])^(power/2);
  marked = marked //. Dot[a_ + b_, c_] :> a.c + b.c;
  marked = marked //. Dot[a_, b_ + c_] :> a.b + a.c;
  marked = marked /. Dot[q_*a_dlogVector, b_] :> q*a.b;
  marked = marked /. Dot[a_, q_*b_dlogVector] :> q*a.b;
  marked = marked /.
    Dot[a_dlogVector, b_dlogVector] /; Order[a, b] === -1 :> b.a;
  marked /. dlogVector[a_] :> a
];

expandedDot[a_, b_, vectors_List] :=
  If[dlogZeroQ[a] || dlogZeroQ[b], 0, expandVectorExpression[a.b, vectors]];

expandedKinematicRules[family_Association] := Module[{vectors},
  vectors = Join[family["LoopMomenta"], family["ExternalMomenta"]];
  expandVectorExpression[family["KinematicRules"], vectors]
];

loopScalarProducts[family_Association] := Module[{loops, external, vectors},
  loops = family["LoopMomenta"];
  external = family["ExternalMomenta"];
  vectors = Join[loops, external];
  Join[
    Flatten@Table[expandedDot[loops[[i]], loops[[j]], vectors],
      {i, Length[loops]}, {j, i, Length[loops]}],
    Flatten@Table[expandedDot[loops[[i]], external[[j]], vectors],
      {i, Length[loops]}, {j, Length[external]}]
  ]
];

affineCoordinateData[family_Association, items_List] := Module[
  {vectors, scalarProducts, rules, polynomials, offsets, matrix, residuals},
  vectors = Join[family["LoopMomenta"], family["ExternalMomenta"]];
  scalarProducts = loopScalarProducts[family];
  rules = expandedKinematicRules[family];
  polynomials = Expand[expandVectorExpression[#, vectors] /. Dispatch[rules]]& /@ items;
  offsets = polynomials /. Dispatch[Thread[scalarProducts -> 0]];
  matrix = Table[Coefficient[polynomials[[i]], scalarProducts[[j]]],
    {i, Length[polynomials]}, {j, Length[scalarProducts]}];
  residuals = MapThread[Cancel[#1 - #2.scalarProducts - #3] &,
    {polynomials, matrix, offsets}];
  If[AnyTrue[residuals, !dlogZeroQ[#]&],
    Failure["NonAffineCoordinate", <|"Residuals" -> residuals|>],
    <|"Polynomials" -> polynomials, "Offsets" -> offsets, "Matrix" -> matrix|>
  ]
];

matrixRank[matrix_List] := If[matrix === {}, 0, MatrixRank[matrix]];

rowPivotColumns[matrix_List] := Module[{rows},
  rows = Select[RowReduce[matrix], AnyTrue[#, !dlogZeroQ[#]&]&];
  (First@First@Position[
    #, entry_ /; !dlogZeroQ[entry], {1}, 1, Heads -> False
  ])& /@ rows
];

linearVectorCoefficients[vector_, basis_List] := Module[{coefficients, residual},
  coefficients = Coefficient[Expand[vector], #]& /@ basis;
  residual = Expand[vector - coefficients.basis];
  If[dlogZeroQ[residual], coefficients, $Failed]
];

independentVectorBasis[vectors_List, basis_List] := Module[
  {selected = {}, rows = {}, row},
  Do[
    row = linearVectorCoefficients[vector, basis];
    If[row === $Failed, Return[$Failed]];
    If[matrixRank[Append[rows, row]] > matrixRank[rows],
      selected = Append[selected, vector];
      rows = Append[rows, row]
    ],
    {vector, vectors}
  ];
  selected
];

loopBlockPropagatorData[family_Association, propagator_, currentLoop_] := Module[
  {loops, external, spectators, dummy, vectors, rules, expanded, loopSquare,
   loopProducts, normalization, shiftCoefficients, shift, constant, reconstructed},
  loops = family["LoopMomenta"];
  external = family["ExternalMomenta"];
  spectators = Join[DeleteCases[loops, currentLoop], external];
  dummy = Unique["DlogBasis`Private`lblLoop$"];
  vectors = Append[spectators, dummy];
  rules = expandedKinematicRules[family];
  expanded = Expand[
    expandVectorExpression[propagator /. currentLoop -> dummy, vectors] /. Dispatch[rules]
  ];
  loopSquare = expandedDot[dummy, dummy, vectors];
  loopProducts = expandedDot[dummy, #, vectors]& /@ spectators;
  normalization = Factor[Coefficient[expanded, loopSquare]];
  If[dlogZeroQ[normalization], Return[$Failed]];
  shiftCoefficients = Factor[Coefficient[expanded, #]/(2 normalization)]& /@ loopProducts;
  shift = Total[shiftCoefficients*spectators];
  constant = expanded /. Dispatch[Thread[Join[{loopSquare}, loopProducts] -> 0]];
  reconstructed = Expand[
    normalization*(loopSquare + 2 Total[shiftCoefficients*loopProducts]) + constant
  ];
  If[!dlogZeroQ[expanded - reconstructed], Return[$Failed]];
  <|"Normalization" -> normalization, "Shift" -> shift, "Constant" -> constant|>
];

gramNeeds[family_Association, momenta_List] := Module[{vectors},
  vectors = Join[family["LoopMomenta"], family["ExternalMomenta"]];
  Flatten@Table[expandedDot[momenta[[i]], momenta[[j]], vectors],
    {i, Length[momenta]}, {j, i, Length[momenta]}]
];

gramCandidates[momenta_List] := DeleteDuplicates@Join[
  Expand[#]^2& /@ momenta,
  Flatten@Table[Expand[momenta[[i]] - momenta[[j]]]^2,
    {i, Length[momenta]}, {j, i + 1, Length[momenta]}],
  Flatten@Table[Expand[momenta[[i]] + momenta[[j]]]^2,
    {i, Length[momenta]}, {j, i + 1, Length[momenta]}]
];

completeGramCoordinates[
  family_Association,
  remainingRecords_List,
  momenta_List,
  counter_Integer
] := Module[
  {existingData, needsData, currentMatrix, currentRank, targetRank, records,
   extras = {}, next = counter, candidateData, row},
  existingData = affineCoordinateData[family, Lookup[remainingRecords, "Expression", {}]];
  needsData = affineCoordinateData[family, gramNeeds[family, momenta]];
  If[FailureQ[existingData] || FailureQ[needsData],
    Return[Failure["NonAffineGramCoordinate", <||>]]
  ];
  currentMatrix = existingData["Matrix"];
  currentRank = matrixRank[currentMatrix];
  targetRank = matrixRank[Join[currentMatrix, needsData["Matrix"]]];
  records = remainingRecords;
  Do[
    If[currentRank >= targetRank, Break[]];
    candidateData = affineCoordinateData[family, {candidate}];
    If[FailureQ[candidateData], Continue[]];
    row = First[candidateData["Matrix"]];
    If[matrixRank[Append[currentMatrix, row]] > currentRank,
      next++;
      With[{record = <|
          "ID" -> ("extra$" <> ToString[next]),
          "Role" -> "Extra",
          "Expression" -> candidate,
          "Origin" -> "LBLGramCompletion"
        |>},
        records = Append[records, record];
        extras = Append[extras, record]
      ];
      currentMatrix = Append[currentMatrix, row];
      currentRank++
    ],
    {candidate, gramCandidates[momenta]}
  ];
  If[currentRank =!= targetRank, Return[Failure["GramCompletionFailed", <||>]]];
  <|"RemainingRecords" -> records, "NewExtras" -> extras, "NextCounter" -> next|>
];

finalizeLBLChart[
  family_Association,
  sector_List,
  specifications_List,
  physicalRecords_List,
  extraRecords_List,
  blocks_List
] := Module[
  {records, coordinates, scalarCoordinates, count, scalarData, coordinateData,
   scalarMatrix, scalarOffsets, coordinateRows, rawOffsets, pivots, pivotMatrix,
   representRow, coordinateMatrix, offsets, determinant, variables,
   physicalVariables, scalarValues, jacobian, express, propagatorValues,
   loopData, baseKernel, regulatorRatio, regulatorWeight, kernel,
   dimensions, status},
  records = Join[physicalRecords, extraRecords];
  coordinates = Lookup[records, "Expression"];
  scalarCoordinates = Flatten[Lookup[blocks, "ScalarCoordinates"]];
  count = Length[scalarCoordinates];
  If[Length[coordinates] =!= count,
    Return[Failure["LBLCoordinateCountMismatch", <|
      "Coordinates" -> Length[coordinates], "ScalarCoordinates" -> count|>]]
  ];
  scalarData = affineCoordinateData[family, scalarCoordinates];
  coordinateData = affineCoordinateData[family, coordinates];
  If[FailureQ[scalarData] || FailureQ[coordinateData],
    Return[Failure["NonAffineLBLCoordinates", <||>]]
  ];
  scalarMatrix = scalarData["Matrix"];
  scalarOffsets = scalarData["Offsets"];
  coordinateRows = coordinateData["Matrix"];
  rawOffsets = coordinateData["Offsets"];
  If[matrixRank[scalarMatrix] =!= count,
    Return[Failure["DependentLBLScalarCoordinates", <||>]]
  ];
  pivots = rowPivotColumns[scalarMatrix];
  pivotMatrix = scalarMatrix[[All, pivots]];
  representRow = Function[currentRow,
    Module[{coefficients},
      coefficients = LinearSolve[
        Transpose[pivotMatrix], currentRow[[pivots]]
      ];
      If[
        AllTrue[coefficients.scalarMatrix - currentRow, dlogZeroQ],
        coefficients,
        $Failed
      ]
    ]
  ];
  coordinateMatrix = representRow /@ coordinateRows;
  If[MemberQ[coordinateMatrix, $Failed],
    Return[Failure["CoordinateOutsideLBLSpan", <||>]]
  ];
  offsets = Factor /@ (rawOffsets - coordinateMatrix.scalarOffsets);
  determinant = Factor[Det[coordinateMatrix]];
  If[dlogZeroQ[determinant], Return[Failure["SingularLBLCoordinateMap", <||>]]];
  variables = Table[Symbol["DlogBasis`Private`z" <> ToString[i]], {i, count}];
  physicalVariables = Take[variables, Length[physicalRecords]];
  scalarValues = LinearSolve[coordinateMatrix, variables - offsets];
  jacobian = Factor[1/determinant];
  express[expression_] := Module[{data, coefficients},
    data = affineCoordinateData[family, {expression}];
    coefficients = representRow[First[data["Matrix"]]];
    If[coefficients === $Failed, Return[$Failed]];
    Cancel[coefficients.scalarValues + First[data["Offsets"]] - coefficients.scalarOffsets]
  ];
  propagatorValues = express /@ family["Propagators"];
  loopData = Map[
    Function[block,
      Module[{momenta, shifted, externalGramMatrix, baikovVectors,
       baikovGramMatrix, dimension, vectors},
        momenta = block["ExternalMomenta"];
        shifted = block["ShiftedLoop"];
        dimension = block["BaseDimension"];
        vectors = Join[family["LoopMomenta"], family["ExternalMomenta"]];
        externalGramMatrix = Table[
          express[expandedDot[momenta[[i]], momenta[[j]], vectors]],
          {i, Length[momenta]}, {j, Length[momenta]}];
        baikovVectors = Prepend[momenta, shifted];
        baikovGramMatrix = Table[
          express[expandedDot[baikovVectors[[i]], baikovVectors[[j]], vectors]],
          {i, Length[baikovVectors]}, {j, Length[baikovVectors]}];
        Join[block, <|
          "ExternalGram" -> If[momenta === {}, 1, Cancel[Det[externalGramMatrix]]],
          "BaikovGram" -> Cancel[Det[baikovGramMatrix]],
          "Dimension" -> dimension - 2 DimensionalRegulator,
          "BaseExternalExponent" -> (Length[momenta] - dimension + 1)/2,
          "BaseBaikovExponent" -> (dimension - Length[momenta] - 2)/2,
          "ExternalExponent" ->
            (Length[momenta] - dimension + 1)/2 + DimensionalRegulator,
          "BaikovExponent" ->
            (dimension - Length[momenta] - 2)/2 - DimensionalRegulator
        |>]
      ]
    ],
    blocks
  ];
  (* D=D0-2 epsilon gives K(D)=K(D0) Product[EGram/BGram]^epsilon. *)
  baseKernel = jacobian Times@@(
    #["ExternalGram"]^#["BaseExternalExponent"]*
      #["BaikovGram"]^#["BaseBaikovExponent"]& /@ loopData
  );
  regulatorRatio = Cancel[Times@@(
    #["ExternalGram"]/#["BaikovGram"]& /@ loopData
  )];
  regulatorWeight = regulatorRatio^DimensionalRegulator;
  kernel = baseKernel regulatorWeight;
  dimensions = Lookup[specifications, "BaseDimension"];
  status = If[SameQ@@dimensions, "CommonDimension", "MixedDimensionProposal"];
  <|
    "Method" -> "LoopByLoopBaikov",
    "FamilyHash" -> family["FamilyHash"],
    "Sector" -> sector,
    "LoopSpecifications" -> specifications,
    "RepresentationStatus" -> status,
    "PhysicalRecords" -> physicalRecords,
    "ExtraRecords" -> extraRecords,
    "PhysicalVariables" -> physicalVariables,
    "ExtraVariables" -> Drop[variables, Length[physicalRecords]],
    "BaikovVariables" -> variables,
    "PhysicalVariableByPosition" -> AssociationThread[
      Lookup[physicalRecords, "Position"], physicalVariables],
    "FamilyPropagatorValues" -> propagatorValues,
    "UnrepresentedPropagatorPositions" -> Flatten@Position[propagatorValues, $Failed],
    "ScalarCoordinates" -> scalarCoordinates,
    "ScalarCoordinateValues" -> scalarValues,
    "ScalarCoordinateMatrix" -> scalarMatrix,
    "CoordinateRows" -> coordinateRows,
    "CoordinateMatrix" -> coordinateMatrix,
    "CoordinateOffsets" -> offsets,
    "Jacobian" -> jacobian,
    "LoopData" -> loopData,
    "BaseKinematicMeasure" -> baseKernel,
    "RegulatorRatio" -> regulatorRatio,
    "RegulatorWeight" -> regulatorWeight,
    "KinematicMeasure" -> kernel,
    "DimensionConvention" -> "D=D0-2 DimensionalRegulator",
    "PhysicalMappingResiduals" -> MapThread[
      Cancel[#1 - #2]&,
      {propagatorValues[[Lookup[physicalRecords, "Position"]]], physicalVariables}
    ]
  |>
];

LoopByLoopBaikovChart[
  family_Association,
  sector_List,
  specifications_List,
  numeratorPositions_List : {}
] := Module[
  {active, physical, required = {}, seedData, seedMatrix, seedRank, numeratorData,
   row, unused, extras, blocks = {}, counter = 0, order, parsed, unsupported,
   blockPairs, blockRecords, localData, referenceShift, differences, spectatorBasis,
   momenta, shifted, scalarCoordinates, remaining, completion, block, specByLoop},
  active = Flatten@Position[sector, 1];
  physical = (<|"ID" -> ("physical$" <> ToString[#]), "Role" -> "Physical",
      "Position" -> #, "Expression" -> family["Propagators"][[#]]|>&) /@ active;
  seedData = affineCoordinateData[family, Lookup[physical, "Expression"]];
  seedMatrix = seedData["Matrix"];
  seedRank = matrixRank[seedMatrix];
  Do[
    numeratorData = affineCoordinateData[family, {family["Propagators"][[position]]}];
    row = First[numeratorData["Matrix"]];
    If[matrixRank[Append[seedMatrix, row]] > seedRank,
      required = Append[required, <|
        "ID" -> ("numerator$" <> ToString[position]), "Role" -> "Extra",
        "Position" -> position, "Expression" -> family["Propagators"][[position]],
        "Origin" -> "CandidateNumerator"|>];
      seedMatrix = Append[seedMatrix, row];
      seedRank++
    ],
    {position, numeratorPositions}
  ];
  unused = Join[physical, required];
  extras = required;
  order = Lookup[specifications, "Momentum"];
  If[
    Length[order] =!= Length[family["LoopMomenta"]] ||
      !AllTrue[specifications, KeyExistsQ[#, "BaseDimension"]&] ||
      !DuplicateFreeQ[order] ||
      Complement[order, family["LoopMomenta"]] =!= {} ||
      Complement[family["LoopMomenta"], order] =!= {},
    Return[Failure["InvalidLoopSpecifications", <|
      "LoopMomenta" -> family["LoopMomenta"], "SuppliedOrder" -> order|>]]
  ];
  specByLoop = Association[(#["Momentum"] -> #)& /@ specifications];
  Do[
    parsed = {#, loopBlockPropagatorData[family, #["Expression"], currentLoop]}& /@ unused;
    unsupported = Select[parsed,
      Last[#] === $Failed && !FreeQ[expandVectorExpression[First[#]["Expression"],
        Join[family["LoopMomenta"], family["ExternalMomenta"]]], currentLoop]&];
    If[unsupported =!= {},
      Return[Failure["NonQuadraticLoopBlock", <|"Loop" -> currentLoop,
        "Records" -> First /@ unsupported|>]]
    ];
    blockPairs = Select[parsed, AssociationQ[Last[#]]&];
    If[blockPairs === {},
      Return[Failure["ScalelessLoopDirection", <|"Loop" -> currentLoop|>]]
    ];
    blockRecords = First /@ blockPairs;
    localData = Last /@ blockPairs;
    referenceShift = First[Lookup[localData, "Shift"]];
    differences = Rest[Lookup[localData, "Shift"]] -
      ConstantArray[referenceShift, Length[localData] - 1];
    spectatorBasis = Join[DeleteCases[family["LoopMomenta"], currentLoop],
      family["ExternalMomenta"]];
    momenta = independentVectorBasis[differences, spectatorBasis];
    If[Length[blockRecords] =!= Length[momenta] + 1,
      Return[Failure["NonTriangularLoopOrder", <|"Loop" -> currentLoop,
        "CoordinateCount" -> Length[blockRecords],
        "ExternalCount" -> Length[momenta]|>]]
    ];
    shifted = currentLoop + referenceShift;
    scalarCoordinates = Join[
      {expandedDot[shifted, shifted,
        Join[family["LoopMomenta"], family["ExternalMomenta"]]]},
      expandedDot[shifted, #,
        Join[family["LoopMomenta"], family["ExternalMomenta"]]]& /@ momenta
    ];
    remaining = Select[unused,
      !MemberQ[Lookup[blockRecords, "ID"], #["ID"]]&];
    completion = completeGramCoordinates[family, remaining, momenta, counter];
    If[FailureQ[completion], Return[completion]];
    unused = completion["RemainingRecords"];
    extras = Join[extras, completion["NewExtras"]];
    counter = completion["NextCounter"];
    block = <|
      "Loop" -> currentLoop,
      "BaseDimension" -> specByLoop[currentLoop]["BaseDimension"],
      "Records" -> blockRecords,
      "ReferenceShift" -> referenceShift,
      "ShiftedLoop" -> shifted,
      "ExternalMomenta" -> momenta,
      "ExternalCount" -> Length[momenta],
      "ScalarCoordinates" -> scalarCoordinates
    |>;
    blocks = Append[blocks, block],
    {currentLoop, order}
  ];
  If[unused =!= {}, Return[Failure["UnassignedLBLCoordinates", <|"Records" -> unused|>]]];
  finalizeLBLChart[family, sector, specifications, physical, extras, blocks]
];

MapDlogCandidates[chart_Association, candidates_List] := Module[
  {propagators, baseKernel, regulatorWeight},
  propagators = chart["FamilyPropagatorValues"];
  baseKernel = chart["BaseKinematicMeasure"];
  regulatorWeight = chart["RegulatorWeight"];
  Map[
    Function[candidate,
      Module[{indices, used},
        indices = candidate["IndexVector"];
        used = Flatten@Position[indices, Except[0]];
        If[
          MemberQ[propagators[[used]], $Failed],
          Join[candidate, <|
            "MappingStatus" -> "UnrepresentedCandidate",
            "BaseBaikovForm" -> Missing["UnrepresentedCandidate"],
            "BaikovForm" -> Missing["UnrepresentedCandidate"]|>],
          With[{baseForm = Cancel[baseKernel Times@@MapThread[
                If[#2 === 0, 1, Power[#1, -#2]]&,
                {propagators, indices}]]},
            Join[candidate, <|
              "MappingStatus" -> "Exact",
              "BaseBaikovForm" -> baseForm,
              "BaikovForm" -> baseForm regulatorWeight|>]
          ]
        ]
      ]
    ],
    candidates
  ]
];
