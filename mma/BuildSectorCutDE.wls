#!/usr/bin/env wolframscript

$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "DEBuilder.wl"}]];

{inputPath, outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
task = CanonMethodCard`ReadTask[inputPath, "BUILD_CUT_DE"];
prepared = CanonMethodCard`LoadArtifact[task, inputPath, "prepared_family"];
masterBasis = CanonMethodCard`LoadArtifact[task, inputPath, "master_basis"];
sectorManifest = CanonMethodCard`LoadArtifact[task, inputPath, "sector_manifest"];
reduction = CanonMethodCard`LoadArtifact[task, inputPath, "ibp_reduction"];

failClosed[code_String, reason_String] := (
  CanonMethodCard`WriteResult[
    task, outputDir, "ERROR", code, <||>, <|"reason" -> reason|>
  ];
  Exit[1]
);

symbolFromName[name_String] := Module[{held},
  held = Quiet @ Check[ToExpression[name, InputForm, HoldComplete], $Failed];
  If[MatchQ[held, HoldComplete[_Symbol]], First[held], $Failed]
];

declaredSymbolRules[value_Association] := Module[{mapping, rules},
  mapping = Lookup[value, "operator_source_symbol_map", <||>];
  If[!AssociationQ[mapping], Return[$Failed]];
  rules = KeyValueMap[
    Function[{source, target}, Module[{from, to},
      If[!StringQ[source] || !StringQ[target], Return[$Failed, Module]];
      from = symbolFromName[source];
      to = symbolFromName[target];
      If[from === $Failed || to === $Failed, $Failed, from -> to]
    ]],
    mapping
  ];
  If[MemberQ[rules, $Failed], $Failed, rules]
];

validLinearTermQ[item_, denominatorCount_Integer] :=
  AssociationQ[item] &&
    KeyExistsQ[item, "coefficient"] &&
    KeyExistsQ[item, "denominator"] &&
    CanonMethodCard`ExactRationalExpressionQ[item["coefficient"]] &&
    IntegerQ[item["denominator"]] &&
    1 <= item["denominator"] <= denominatorCount;

validRecordQ[record_, denominatorCount_Integer] :=
  AssociationQ[record] &&
    KeyExistsQ[record, "constant"] &&
    KeyExistsQ[record, "linear"] &&
    CanonMethodCard`ExactRationalExpressionQ[record["constant"]] &&
    ListQ[record["linear"]] &&
    AllTrue[record["linear"], validLinearTermQ[#, denominatorCount] &];

validRecordListQ[records_, denominatorCount_Integer] :=
  ListQ[records] && Length[records] === denominatorCount &&
    AllTrue[records, validRecordQ[#, denominatorCount] &];

normalizePreparedDerivatives[value_, variables_List, expectedCount_Integer] :=
 Module[{denominatorCount, denominators, operators, records},
  If[!AssociationQ[value], Return[$Failed]];
  If[KeyExistsQ[value, "denominator_count"] || KeyExistsQ[value, "operators"],
    If[Lookup[value, "schema", None] =!= "canon.prepared-derivatives/v2",
      Return[$Failed]
    ];
    denominatorCount = Lookup[value, "denominator_count", None];
    operators = Lookup[value, "operators", None];
    If[
      !IntegerQ[denominatorCount] || denominatorCount =!= expectedCount ||
        !AssociationQ[operators] || Keys[operators] =!= variables ||
        !AllTrue[
          Lookup[operators, variables],
          validRecordListQ[#, denominatorCount] &
        ],
      Return[$Failed]
    ];
    Return[<|"derivatives" -> value, "input_form" -> "v2"|>]
  ];
  denominators = Lookup[value, "denominators", None];
  records = Lookup[value, "records", None];
  If[
    Length[variables] =!= 1 || !ListQ[denominators] ||
      Length[denominators] =!= expectedCount ||
      !validRecordListQ[records, expectedCount],
    Return[$Failed]
  ];
  <|
    "derivatives" -> <|
      "schema" -> "canon.prepared-derivatives/v2",
      "variables" -> variables,
      "denominator_count" -> expectedCount,
      "operators" -> Association[First[variables] -> records]
    |>,
    "input_form" -> "legacy-single-variable-records"
  |>
];

validMatrixSetQ[matrices_, variables_List, size_Integer] := Module[{values},
  If[!AssociationQ[matrices], Return[False]];
  values = Lookup[matrices, variables, $Failed];
  ListQ[values] && Length[values] === Length[variables] &&
    FreeQ[values, $Failed | _Missing] &&
    AllTrue[
      values,
      MatrixQ[#] && Dimensions[#] === {size, size} &&
        And @@ (CanonMethodCard`ExactRationalExpressionQ /@ Flatten[#]) &
    ]
];

variables = Lookup[prepared, "variables", None];
indexOrder = Lookup[prepared, "index_order", None];
masters = Lookup[masterBasis, "masters", None];
symbolRules = declaredSymbolRules[prepared];
If[
  !ListQ[variables] || variables === {} ||
    !AllTrue[variables, MatchQ[#, _Symbol] &] ||
    DuplicateFreeQ[variables] =!= True ||
    !ListQ[indexOrder] || indexOrder === {} ||
    !ListQ[masters] || masters === {} ||
    !AllTrue[masters, Length[List @@ #] === Length[indexOrder] &] ||
    symbolRules === $Failed,
  failClosed[
    "INVALID_PREPARED_DERIVATIVES",
    "prepared family, master arity, or declared operator symbol map is invalid"
  ]
];
preparedDerivatives = Quiet @ Check[
  Get[prepared["prepared_derivatives", "path"]] /. symbolRules,
  $Failed
];
normalizedDerivatives = normalizePreparedDerivatives[
  preparedDerivatives, variables, Length[indexOrder]
];
If[normalizedDerivatives === $Failed,
  failClosed[
    "INVALID_PREPARED_DERIVATIVES",
    "prepared derivatives do not satisfy the checked v2 or single-variable legacy contract"
  ]
];
preparedDerivatives = normalizedDerivatives["derivatives"];
derivativeInputForm = normalizedDerivatives["input_form"];

operatorRow[record_, denominatorCount_] := Prepend[
  Table[
    Total @ Cases[
      record["linear"],
      item_ /; item["denominator"] === denominator :> item["coefficient"]
    ],
    {denominator, denominatorCount}
  ],
  record["constant"]
];
affineOperators = AssociationMap[
  Function[variable,
    operatorRow[#, preparedDerivatives["denominator_count"]] & /@
      preparedDerivatives["operators", variable]
  ],
  variables
];
dimensionRule = Lookup[prepared, "dimension_rule", None];
If[!MatchQ[dimensionRule, _Rule | _RuleDelayed],
  failClosed["INVALID_DIFFERENTIAL_EQUATION", "dimension_rule is invalid"]
];
fullDE = Quiet @ Check[
  CANON`DEBuilder`BuildDifferentialEquations[
    <|"parameters" -> prepared["parameters"], "operators" -> affineOperators|>,
    masters,
    reduction["rules"]
  ],
  $Failed
];
fullMatrices = If[
  AssociationQ[fullDE] && AssociationQ[Lookup[fullDE, "matrices", None]],
  fullDE["matrices"] /. dimensionRule,
  $Failed
];
If[
  fullMatrices === $Failed ||
    !AssociationQ[Lookup[fullDE, "validity", None]] ||
    !StringQ[Lookup[fullDE["validity"], "scope", None]] ||
    !MemberQ[{True, False}, Lookup[fullDE["validity"], "flat", None]] ||
    !ListQ[Lookup[fullDE["validity"], "pairs", None]] ||
    !validMatrixSetQ[fullMatrices, variables, Length[masters]],
  failClosed[
    "INVALID_DIFFERENTIAL_EQUATION",
    "built differential equation is malformed or contains non-rational entries"
  ]
];
orderedMasterDE = <|
  "schema" -> "canon-neu/ordered-master-de/v1",
  "family_id" -> prepared["family_ref"],
  "basis_id" -> masterBasis["basis_ref"],
  "coefficient_domain" -> "exact-rational-functions",
  "basis" -> masters,
  "variables" -> variables,
  "regulator" -> prepared["regulator"],
  "matrices" -> Lookup[fullMatrices, variables],
  "validity" -> fullDE["validity"]
|>;

currentSector = SelectFirst[
  sectorManifest["sectors"], #1["id"] === task["sector", "id"] &
];
currentBits = currentSector["sector_bits"];
masterBits = (CanonMethodCard`SectorBits[#, sectorManifest["propagator_slots"]] &) /@
  masters;
positions = Flatten @ Position[masterBits, currentBits];
basis = masters[[positions]];
lowerSectors = Select[
  sectorManifest["sectors"],
  #1["sector_bits"] =!= currentBits &&
    And @@ MapThread[LessEqual, {#1["sector_bits"], currentBits}] &
];
sector = KeyTake[currentSector, {"id", "propagator_count"}];
basisID = masterBasis["basis_ref"] <> "/sector-" <> ToString[sector["id"]];

sectorBasis = <|
  "schema" -> "canon-neu/sector-basis/v1",
  "sector" -> sector,
  "family_id" -> prepared["family_ref"],
  "basis_id" -> basisID,
  "basis" -> basis
|>;
sectorCutDE = <|
  "schema" -> "canon-neu/sector-cut-de/v1",
  "sector" -> sector,
  "family_id" -> prepared["family_ref"],
  "basis_id" -> basisID,
  "coefficient_domain" -> "exact-rational-functions",
  "basis" -> basis,
  "variables" -> variables,
  "regulator" -> prepared["regulator"],
  "matrices" -> (#[[positions, positions]] & /@
    Lookup[fullMatrices, variables]),
  "sector_boundaries" -> {{1, Length[basis]}},
  "proper_subsectors" ->
    (KeyTake[#, {"id", "propagator_count"}] & /@ lowerSectors)
|>;

publicationChecks = <|
  "sector_basis" -> CanonMethodCard`ValidSectorBasisQ[sectorBasis],
  "sector_cut_de" -> CanonMethodCard`ValidCutDEQ[sectorCutDE],
  "ordered_master_de" -> validMatrixSetQ[
      AssociationThread[variables, orderedMasterDE["matrices"]],
      variables,
      Length[masters]
    ]
|>;
If[
  !And @@ Values[publicationChecks],
  failClosed[
    "INVALID_DIFFERENTIAL_EQUATION",
    "constructed output artifacts failed the exact-rational publication gate: " <>
      ToString[publicationChecks, InputForm]
  ]
];

basisPath = CanonMethodCard`WriteWLArtifact[
  sectorBasis, outputDir, "sector-basis.wl"
];
cutPath = CanonMethodCard`WriteWLArtifact[
  sectorCutDE, outputDir, "sector-cut-de.wl"
];
orderedPath = CanonMethodCard`WriteWLArtifact[
  orderedMasterDE, outputDir, "ordered-master-de.wl"
];
If[!And @@ (StringQ /@ {basisPath, cutPath, orderedPath}),
  failClosed["ARTIFACT_WRITE_FAILED", "could not write complete BUILD_CUT_DE artifacts"]
];
CanonMethodCard`WriteResult[
  task, outputDir, "PASS", "OK",
  <|
    "sector_basis" -> <|
      "type" -> "mathematica-expression", "path" -> FileNameTake[basisPath]
    |>,
    "sector_cut_de" -> <|
      "type" -> "mathematica-expression", "path" -> FileNameTake[cutPath]
    |>,
    "ordered_master_de" -> <|
      "type" -> "mathematica-expression", "path" -> FileNameTake[orderedPath]
    |>
  |>,
  <|
    "basis_size" -> Length[basis],
    "full_master_count" -> Length[masters],
    "resident_positions" -> positions,
    "de_validity_scope" -> fullDE["validity", "scope"],
    "de_flat" -> fullDE["validity", "flat"],
    "prepared_derivative_input" -> derivativeInputForm,
    "prepared_derivative_denominator_count" ->
      preparedDerivatives["denominator_count"]
  |>
];
