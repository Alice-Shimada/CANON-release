(* Exact coefficient domain, native master lists and supplied basis maps. *)
zero[q_] := TrueQ[Together[q] === 0];
allowedCoefficients[f_] := DeleteDuplicates @ Join[f["variables"], {f["regulator"], f["dimension"]},
  If[KeyExistsQ[f, "parameters"], wl /@ f["parameters"], wl[#["name"]] & /@ Lookup[f, "invariants", {}]]];
coefficientQ[q_, f_] := Module[{allowed = allowedCoefficients[f], symbols, mapped},
  symbols = Table[Unique["coefficient$"], {Length[allowed]}]; mapped = q /. Thread[allowed -> symbols];
  CanonMethodCard`DeclaredCoefficientDomainQ[mapped, symbols]
];
linear[q_, masters_, f_] := Module[{variables, p, coefficients},
  variables = Table[Unique["master$"], {Length[masters]}]; p = Expand[q /. Thread[masters -> variables]];
  coefficients = Coefficient[p, #] & /@ variables;
  need[zero[p - coefficients . variables] && AllTrue[coefficients, coefficientQ[#, f] &], "UNRESOLVED_NATIVE_RULES", "A rule is nonlinear, contains undeclared coefficients, or is not reduced to the declared native masters."];
  coefficients
];
nativeMasters[raw_, format_, e_, f_] := Module[{m = raw},
  need[ListQ[m] && m =!= {}, "INVALID_NATIVE_MASTERS", "Expected a nonempty native master list."];
  If[format === "family-index-pairs", m = (need[MatchQ[#, {_, {__Integer}}], "INVALID_NATIVE_MASTERS", "Invalid FIRE master pair."]; e["head"] @@ #) & /@ m];
  m = decode[#, e, f] & /@ m;
  need[DuplicateFreeQ[m], "DUPLICATE_NATIVE_MASTERS", "Native master list contains duplicates."]; m
];
basisMap[task_, input_, native_, preferred_, f_] := Module[{conversion, path, matrix},
  If[Sort[native] === Sort[preferred], Return[<|"matrix" -> SparseArray[Table[{i, First@FirstPosition[preferred, native[[i]]]} -> 1, {i, Length[native]}], {Length[native], Length[preferred]}], "kind" -> "permutation"|>]];
  need[KeyExistsQ[task["payload"], "basis_conversion"], "NATIVE_BASIS_MISMATCH", "A different native basis requires an explicit basis_conversion artifact."];
  {conversion, path} = load[task, input, "basis_conversion"];
  need[Lookup[conversion, "schema", None] === "canon-neu/master-basis-conversion/v1" && conversion["family_ref"] === f["family_ref"] &&
    conversion["basis_ref"] === f["basis_ref"] && conversion["native_masters"] === native && conversion["masters"] === preferred &&
    conversion["convention"] === "native_masters = matrix . masters", "BASIS_CONVERSION_MISMATCH", "Conversion identity/order/convention differs from the two bases."];
  matrix = conversion["matrix"];
  need[Length[native] === Length[preferred] && MatrixQ[matrix] && Dimensions[matrix] === {Length[native], Length[preferred]} &&
    AllTrue[Flatten[Normal[matrix]], coefficientQ[#, f] &] && !zero[Det[matrix]], "INVALID_BASIS_CONVERSION", "Supply an invertible exact rational change of basis."];
  <|"matrix" -> matrix, "kind" -> "explicit-conversion", "source" -> path|>
];
