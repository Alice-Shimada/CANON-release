BeginPackage["CANON`SectorDE`"];

LoadPreparedDerivatives::usage = "LoadPreparedDerivatives[prepared, preparedPath, masterBasis, derivativePath:Automatic] binds the declared family and basis identities, loads the selected derivative file, applies the explicit symbol map once, and returns checked v2 derivatives and the input form. Automatic resolves the embedded reference from preparedPath; an explicit path is already resolved by the caller.";
NormalizePreparedDerivatives::usage = "NormalizePreparedDerivatives[value, variables, denominatorCount] validates v2 affine records or single-variable legacy records, preserving the prepared variable order. Returns derivatives and input_form, or Failure.";
DifferentialEquationFamily::usage = "DifferentialEquationFamily[prepared, normalized] returns the same checked affine family used by BuildOrderedMasterDE, for derivative-target declaration before the reduction audit.";
BuildOrderedMasterDE::usage = "BuildOrderedMasterDE[prepared, masterBasis, reduction, normalized] consumes checked derivatives from LoadPreparedDerivatives, builds the complete DE once, applies dimension_rule, and checks closure and exact rational entries once.";
ValidateOrderedMasterDE::usage = "ValidateOrderedMasterDE[ordered] checks an external ordered-master-de/v1 before slicing; internally built DEs already satisfy this contract.";
CurrentSectorRecord::usage = "CurrentSectorRecord[ordered, manifest, requestedSector] checks the external manifest binding and returns its complete requested sector record. No matrix validation or slicing is performed.";

Begin["`Private`"];

failure[code_, reason_] := Failure[code, <|"Message" -> reason|>];

validLinearTermQ[item_, count_] := AssociationQ[item] &&
  KeyExistsQ[item, "coefficient"] && KeyExistsQ[item, "denominator"] &&
  CanonMethodCard`ExactRationalExpressionQ[item["coefficient"]] &&
  IntegerQ[item["denominator"]] && 1 <= item["denominator"] <= count;

validRecordQ[record_, count_] := AssociationQ[record] &&
  KeyExistsQ[record, "constant"] && KeyExistsQ[record, "linear"] &&
  CanonMethodCard`ExactRationalExpressionQ[record["constant"]] &&
  ListQ[record["linear"]] && AllTrue[record["linear"], validLinearTermQ[#, count] &];

validRecordsQ[records_, count_] := ListQ[records] && Length[records] === count &&
  AllTrue[records, validRecordQ[#, count] &];

NormalizePreparedDerivatives[value_, variables_List, count_Integer] := Module[
  {operators, denominators, records, invalid},
  invalid = failure["INVALID_PREPARED_DERIVATIVES",
    "prepared derivatives do not satisfy the checked v2 or single-variable legacy contract"];
  If[!AssociationQ[value], Return[invalid]];
  If[KeyExistsQ[value, "denominator_count"] || KeyExistsQ[value, "operators"],
    operators = Lookup[value, "operators", None];
    If[Lookup[value, "schema", None] =!= "canon.prepared-derivatives/v2" ||
      Lookup[value, "denominator_count", None] =!= count ||
      !AssociationQ[operators] || Keys[operators] =!= variables ||
      !AllTrue[Values[operators], validRecordsQ[#, count] &], Return[invalid]];
    Return[<|"derivatives" -> Join[value, <|"variables" -> variables|>],
      "input_form" -> "v2"|>]
  ];
  denominators = Lookup[value, "denominators", None];
  records = Lookup[value, "records", None];
  If[Length[variables] =!= 1 || !ListQ[denominators] ||
    Length[denominators] =!= count || !validRecordsQ[records, count], Return[invalid]];
  <|"derivatives" -> <|"schema" -> "canon.prepared-derivatives/v2",
      "variables" -> variables, "denominator_count" -> count,
      "operators" -> Association[First[variables] -> records]|>,
    "input_form" -> "legacy-single-variable-records"|>
];

LoadPreparedDerivatives[prepared_, preparedPath_String, masterBasis_, derivativePath_ : Automatic] := Module[
  {variables, indexOrder, masters, symbolRules, descriptor, source, value, invalid},
  invalid = failure["INVALID_PREPARED_DERIVATIVES",
    "prepared family, master arity, or declared operator symbol map is invalid"];
  If[!AssociationQ[prepared] || !AssociationQ[masterBasis], Return[invalid]];
  If[!AllTrue[{"family_ref", "basis_ref"},
      StringQ[Lookup[prepared, #, None]] &&
        Lookup[prepared, #, None] === Lookup[masterBasis, #, None] &],
    Return[failure["SOURCE_BASIS_MISMATCH",
      "prepared family and master basis must declare matching family_ref and basis_ref strings"]]
  ];
  variables = Lookup[prepared, "variables", None];
  indexOrder = Lookup[prepared, "index_order", None];
  masters = Lookup[masterBasis, "masters", None];
  symbolRules = CanonMethodCard`ParseSymbolRules[Lookup[prepared, "operator_source_symbol_map", <||>]];
  If[!ListQ[variables] || variables === {} || !AllTrue[variables, MatchQ[#, _Symbol] &] ||
    !DuplicateFreeQ[variables] || !ListQ[indexOrder] || indexOrder === {} ||
    !ListQ[masters] || masters === {} ||
    !AllTrue[masters, Length[List @@ #] === Length[indexOrder] &] ||
    symbolRules === $Failed, Return[invalid]];
  source = derivativePath;
  If[source === Automatic,
    descriptor = Lookup[prepared, "prepared_derivatives", <||>];
    If[!AssociationQ[descriptor] || !StringQ[Lookup[descriptor, "path", None]], Return[invalid]];
    source = CanonMethodCard`ResolveArtifactPath[preparedPath, descriptor]
  ];
  If[FailureQ[source], Return[source]];
  If[!StringQ[source], Return[invalid]];
  value = Quiet @ Check[CanonMethodCard`ReadWLData[source] /. symbolRules, $Failed];
  (* ReplaceAll maps Association values; operator keys need the declared map too. *)
  If[AssociationQ[value] && AssociationQ[Lookup[value, "operators", None]],
    value["operators"] = AssociationThread[
      Keys[value["operators"]] /. symbolRules, Values[value["operators"]]]
  ];
  NormalizePreparedDerivatives[value, variables, Length[indexOrder]]
];

operatorRow[record_, count_] := Prepend[Table[
  Total @ Cases[record["linear"],
    item_ /; item["denominator"] === denominator :> item["coefficient"]],
  {denominator, count}], record["constant"]];

affineOperators[derivatives_] := AssociationMap[Function[variable,
  operatorRow[#, derivatives["denominator_count"]] & /@
    derivatives["operators", variable]], derivatives["variables"]];

DifferentialEquationFamily[prepared_, normalized_] := <|
  "parameters" -> prepared["parameters"],
  "operators" -> affineOperators[normalized["derivatives"]]|>;

(* Exact rational functions are closed under sums and products. Check their
   pieces before asking Together to combine a complete, potentially large entry.
   The original checker remains the fallback when cancellation is required. *)
exactRationalFallback[entry_] := CanonMethodCard`ExactRationalExpressionQ[entry];

exactRationalEntryQ[_Integer | _Rational] := True;
exactRationalEntryQ[entry_Symbol] /; Context[entry] =!= "System`" := True;
exactRationalEntryQ[Power[base_Symbol, exponent_Integer]] /;
  exponent >= 0 && Context[base] =!= "System`" := True;

exactRationalEntryQ[entry_] :=
  (MemberQ[{Plus, Times}, Head[entry]] &&
    AllTrue[List @@ entry, exactRationalEntryQ]) ||
  exactRationalFallback[entry];

validMatricesQ[matrices_, variables_, size_] := Module[{cache = <||>},
  Block[{exactRationalFallback},
    exactRationalFallback[entry_] := With[{key = HoldComplete[entry]},
      If[KeyExistsQ[cache, key], cache[key],
        cache[key] = CanonMethodCard`ExactRationalExpressionQ[entry]]
    ];
    ListQ[matrices] && Length[matrices] === Length[variables] && AllTrue[matrices,
      MatrixQ[#] && Dimensions[#] === {size, size} &&
        And @@ (exactRationalEntryQ /@ Flatten[#]) &]
  ]
];

BuildOrderedMasterDE[prepared_, masterBasis_, reduction_, normalized_] := Module[
  {masters, variables, dimensionRule, rules, coefficientRows, fullDE, matrices, invalid},
  invalid = failure["INVALID_DIFFERENTIAL_EQUATION",
    "built differential equation is malformed or contains non-rational entries"];
  masters = masterBasis["masters"]; variables = prepared["variables"];
  If[!MatchQ[Lookup[prepared, "regulator", None], _Symbol], Return[invalid]];
  dimensionRule = Lookup[prepared, "dimension_rule", None];
  If[!MatchQ[dimensionRule, _Rule | _RuleDelayed],
    Return[failure["INVALID_DIFFERENTIAL_EQUATION", "dimension_rule is invalid"]]];
  If[!AssociationQ[reduction], Return[invalid]];
  rules = Lookup[reduction, "rules", None];
  If[!DuplicateFreeQ[masters] || !ListQ[rules] ||
    !AllTrue[rules, MatchQ[#, _Rule | _RuleDelayed] &] ||
    Lookup[reduction, "masters", masters] =!= masters || !DuplicateFreeQ[First /@ rules] ||
    AnyTrue[{"family_ref", "basis_ref"}, KeyExistsQ[reduction, #] && reduction[#] =!= prepared[#] &],
    Return[invalid]];
  (* Check raw integral linearity before unit-vector substitution can collapse
     products or broadcast a scalar offset into apparently valid coefficients. *)
  coefficientRows = CanonMethodCard`IntegralCoefficientRows[Last /@ rules, masters, Head[First[masters]]];
  If[MemberQ[coefficientRows, $Failed] ||
    !AllTrue[Select[rules, MemberQ[masters, First[#]] &],
      CanonMethodCard`ZeroMatrixQ[CanonMethodCard`IntegralCoefficientRows[
        {Last[#] - First[#]}, masters, Head[First[masters]]]] &], Return[invalid]];
  fullDE = Quiet @ Check[CANON`DEBuilder`BuildDifferentialEquations[
    DifferentialEquationFamily[prepared, normalized], masters, rules, coefficientRows], $Failed];
  matrices = If[AssociationQ[fullDE] && AssociationQ[Lookup[fullDE, "matrices", None]],
    Lookup[fullDE["matrices"], variables, $Failed] /. dimensionRule, $Failed];
  If[!validMatricesQ[matrices, variables, Length[masters]], Return[invalid]];
  <|"schema" -> "canon-neu/ordered-master-de/v1",
    "family_id" -> prepared["family_ref"], "basis_id" -> masterBasis["basis_ref"],
    "coefficient_domain" -> "exact-rational-functions", "basis" -> masters,
    "variables" -> variables, "regulator" -> prepared["regulator"],
    "matrices" -> matrices, "validity" -> fullDE["validity"]|>
];

ValidateOrderedMasterDE[ordered_] := Module[{basis, variables, invalid},
  invalid = failure["INVALID_DIFFERENTIAL_EQUATION", "ordered master DE is malformed or contains non-rational entries"];
  If[!AssociationQ[ordered] || Lookup[ordered, "schema", None] =!= "canon-neu/ordered-master-de/v1" ||
    Lookup[ordered, "coefficient_domain", None] =!= "exact-rational-functions" ||
    !StringQ[Lookup[ordered, "family_id", None]] || !StringQ[Lookup[ordered, "basis_id", None]] ||
    !MatchQ[Lookup[ordered, "regulator", None], _Symbol], Return[invalid]];
  basis = Lookup[ordered, "basis", None]; variables = Lookup[ordered, "variables", None];
  If[!ListQ[basis] || basis === {} || !ListQ[variables] || variables === {} ||
    !AllTrue[variables, MatchQ[#, _Symbol] &] || !DuplicateFreeQ[variables] ||
    !validMatricesQ[Lookup[ordered, "matrices", None], variables, Length[basis]], Return[invalid]];
  ordered
];

CurrentSectorRecord[ordered_, manifest_, requested_] := Module[
  {sectors, slots, count, current, invalid},
  invalid = failure["INVALID_DIFFERENTIAL_EQUATION", "sector manifest or requested sector does not bind the ordered master basis"];
  If[!AssociationQ[manifest] || !AssociationQ[requested] ||
    Lookup[manifest, "family_ref", None] =!= ordered["family_id"], Return[invalid]];
  count = Length[First[ordered["basis"]]];
  sectors = Lookup[manifest, "sectors", None]; slots = Lookup[manifest, "propagator_slots", None];
  If[!ListQ[slots] || !AllTrue[slots, IntegerQ[#] && 1 <= # <= count &] ||
    !ListQ[sectors] || !AllTrue[sectors, AssociationQ[#] &&
      IntegerQ[Lookup[#, "id", None]] && IntegerQ[Lookup[#, "propagator_count", None]] &&
      MatchQ[Lookup[#, "sector_bits", None], {(0 | 1) ..}] &&
      Length[#["sector_bits"]] === count &], Return[invalid]];
  current = SelectFirst[sectors, #["id"] === Lookup[requested, "id", None] &, None];
  If[current === None || KeyTake[current, {"id", "propagator_count"}] =!=
      KeyTake[requested, {"id", "propagator_count"}], Return[invalid]];
  current
];

End[];
EndPackage[];
