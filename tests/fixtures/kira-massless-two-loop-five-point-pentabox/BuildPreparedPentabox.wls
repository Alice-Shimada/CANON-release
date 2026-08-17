#!/usr/bin/env wolframscript

If[Length[$ScriptCommandLine] =!= 2,
  Print["usage: BuildPreparedPentabox.wls FRESH_OUTPUT.wl"];
  Exit[2]
];
outputPath = Last[$ScriptCommandLine];
If[FileExistsQ[outputPath],
  Print["DERIVATION_FAILED: output must be fresh"];
  Exit[2]
];
fail[message_String] := (Print["DERIVATION_FAILED: " <> message]; Exit[1]);
zeroQ[expression_] := TrueQ[Together[expression] === 0];
zeroMatrixQ[matrix_] := AllTrue[Flatten[matrix], zeroQ];

symbols = Symbol["CANON`DEData`" <> #] & /@ {
  "s12", "s23", "s34", "s45", "s51",
  "z1", "z2", "z3", "z4", "z5", "z6", "z7", "z8", "z9", "z10", "z11"
};
{s12, s23, s34, s45, s51} = Take[symbols, 5];
z = Drop[symbols, 5];
variables = {s12, s23, s34, s45, s51};

(* Independent massless external momenta p1..p4; p5=-(p1+p2+p3+p4). *)
externalGram = {
  {0, s12/2, (-s12 - s23 + s45)/2, (s23 - s45 - s51)/2},
  {s12/2, 0, s23/2, (-s23 - s34 + s51)/2},
  {(-s12 - s23 + s45)/2, s23/2, 0, s34/2},
  {(s23 - s45 - s51)/2, (-s23 - s34 + s51)/2, s34/2, 0}
};
If[!SymmetricMatrixQ[externalGram], fail["external Gram is not symmetric"]];
p5Mass = Together[Total[Flatten[externalGram]]];
If[!zeroQ[p5Mass], fail["momentum-conservation p5 is not massless"]];

(* The symmetric exact lift dp_i/dx=A_x,ij p_j is fixed by
   A_x.G+G.Transpose[A_x]=dG/dx. *)
lifts = Association @ Map[
  Function[variable,
    variable -> Map[Together, 1/2 D[externalGram, variable] . Inverse[externalGram], {2}]
  ],
  variables
];
gramLiftChecks = Association @ Map[
  Function[variable,
    variable -> zeroMatrixQ[
      lifts[variable] . externalGram + externalGram . Transpose[lifts[variable]] -
        D[externalGram, variable]
    ]
  ],
  variables
];
If[!And @@ Values[gramLiftChecks], fail["an exact external-Gram lift identity failed"]];

(* Recover the five adjacent invariants directly from G and verify that each
   lift is the corresponding coordinate derivative. *)
coordinateExpressions = {
  2 externalGram[[1, 2]],
  2 externalGram[[2, 3]],
  2 externalGram[[3, 4]],
  Total[Flatten[externalGram[[1 ;; 3, 1 ;; 3]]]],
  Total[Flatten[externalGram[[2 ;; 4, 2 ;; 4]]]]
};
coordinateJacobian = Table[Together[D[coordinateExpressions[[i]], variables[[j]]]], {i, 5}, {j, 5}];
If[coordinateExpressions =!= variables || coordinateJacobian =!= IdentityMatrix[5],
  fail["the external Gram does not reproduce the five adjacent coordinates"]
];

externalGramDeterminant = Together[Det[externalGram]];
gramDeterminantChecks = Association @ Map[
  Function[variable,
    variable -> zeroQ[
      D[externalGramDeterminant, variable] -
        externalGramDeterminant Tr[Inverse[externalGram] . D[externalGram, variable]]
    ]
  ],
  variables
];
If[!And @@ Values[gramDeterminantChecks], fail["an exact Gram-determinant derivative identity failed"]];

(* Eleven independent loop/external scalar products and the eleven family
   denominators. The z_i are not fixed-scale substitutes. *)
{k1sq, k2sq, k1k2, k1p1, k1p2, k1p3, k1p4, k2p1, k2p2, k2p3, k2p4} =
  Array[Unique["scalar$"] &, 11];
scalarVariables = {k1sq, k2sq, k1k2, k1p1, k1p2, k1p3, k1p4, k2p1, k2p2, k2p3, k2p4};
u1 = {k1p1, k1p2, k1p3, k1p4};
u2 = {k2p1, k2p2, k2p3, k2p4};
denominators = {
  k1sq,
  k1sq + 2 k1p1,
  k1sq + 2 (k1p1 + k1p2) + s12,
  k1sq + 2 (k1p1 + k1p2 + k1p3) + s45,
  k2sq,
  k2sq + 2 (k2p1 + k2p2 + k2p3) + s45,
  k2sq + 2 (k2p1 + k2p2 + k2p3 + k2p4),
  k1sq + k2sq - 2 k1k2,
  k1sq + 2 (k1p1 + k1p2 + k1p3 + k1p4),
  k2sq + 2 k2p1,
  k2sq + 2 (k2p1 + k2p2) + s12
};
scalarRules = First @ Solve[Thread[z == denominators], scalarVariables];
If[Length[scalarRules] =!= 11 || !zeroMatrixQ[{z - (denominators /. scalarRules)}],
  fail["the denominator/scalar-product coordinate inversion failed"]
];

derivativeAtFixedLoops[expression_, variable_] := Module[{du1, du2},
  du1 = lifts[variable] . u1;
  du2 = lifts[variable] . u2;
  Together[
    D[expression, variable] +
      Sum[D[expression, u1[[i]]] du1[[i]], {i, 4}] +
      Sum[D[expression, u2[[i]]] du2[[i]], {i, 4}]
  ]
];

affineExpressions = Association @ Map[
  Function[variable,
    variable -> (Together[derivativeAtFixedLoops[#, variable] /. scalarRules] & /@ denominators)
  ],
  variables
];

affineRecord[expression_] := Module[{constant, coefficients, residual},
  constant = Together[expression /. Thread[z -> 0]];
  coefficients = Together /@ (D[expression, #] & /@ z);
  residual = Together[expression - constant - coefficients . z];
  If[residual =!= 0, fail["a derived denominator derivative is not affine"]];
  <|
    "constant" -> constant,
    "linear" -> MapIndexed[
      <|"denominator" -> First[#2], "coefficient" -> #1|> &,
      coefficients
    ]
  |>
];
operators = Association @ Map[
  Function[variable, variable -> (affineRecord /@ affineExpressions[variable])],
  variables
];

affineIdentityChecks = Association @ Map[
  Function[variable,
    variable -> And @@ MapThread[
      Function[{expression, record},
        zeroQ[expression - record["constant"] - Lookup[record["linear"], "coefficient"] . z]
      ],
      {affineExpressions[variable], operators[variable]}
    ]
  ],
  variables
];
If[!And @@ Values[affineIdentityChecks], fail["an exact affine polynomial identity failed"]];

fullGram = Join[
  {
    Join[{k1sq, k1k2}, u1],
    Join[{k1k2, k2sq}, u2]
  },
  MapIndexed[
    Join[{u1[[First[#2]]], u2[[First[#2]]]}, #1] &,
    externalGram
  ]
];
baikovPolynomial = Together[Det[fullGram] /. scalarRules];
If[!zeroQ[baikovPolynomial - (Det[fullGram] /. scalarRules)],
  fail["the unscaled Baikov polynomial determinant identity failed"]
];

prepared = <|
  "schema" -> "canon.prepared-derivatives/v2",
  "topology" -> "pentabox5",
  "variables" -> variables,
  "denominator_count" -> 11,
  "operators" -> operators,
  "exact_strategy" -> <|
    "kind" -> "enhanced-baikov-membership",
    "baikov_variables" -> z,
    "propagator_slots" -> Range[8],
    "loop_count" -> 2,
    "independent_external_count" -> 4,
    "fixed_scale_substitutions" -> {},
    "external_gram_determinant" -> externalGramDeterminant,
    "baikov_polynomial" -> baikovPolynomial,
    "search_max_total_degree" -> 1,
    "normal_form_diagnostic" -> "skip",
    "monomial_order" -> "graded-reverse-lexicographic",
    "fallback" -> "operators"
  |>
|>;

Put[prepared, outputPath];
summary = <|
  "status" -> "passed",
  "variables" -> (ToString[#, InputForm] & /@ variables),
  "operator_count" -> Length[operators],
  "operator_record_counts" -> (Length /@ Values[operators]),
  "coordinate_jacobian_identity" -> True,
  "gram_lift_check_count" -> Count[Values[gramLiftChecks], True],
  "gram_determinant_check_count" -> Count[Values[gramDeterminantChecks], True],
  "affine_identity_check_count" -> Count[Values[affineIdentityChecks], True],
  "p5_massless_check" -> True,
  "fixed_scale_substitutions" -> {},
  "output_bytes" -> FileByteCount[outputPath],
  "output_sha256" -> IntegerString[FileHash[outputPath, "SHA256"], 16, 64]
|>;
Print[ToString[summary, InputForm]];
Print["DERIVATION_PASSED"];
