#!/usr/bin/env wolframscript

repoRoot = DirectoryName[DirectoryName[$InputFileName]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "BaikovDerivative.wl"}]];
prepared = Get[FileNameJoin[{
  repoRoot, "tests", "fixtures", "kira-one-loop-box", "prepared-derivatives-v2.wl"
}]];
strategy = prepared["exact_strategy"];
z = strategy["baikov_variables"];
f = Expand[strategy["baikov_polynomial"] /. strategy["fixed_scale_substitutions"]];
tResult = CANON`BaikovDerivative`ChooseDerivativeOperator[prepared, t];
sResult = CANON`BaikovDerivative`ChooseDerivativeOperator[prepared, s];
generators = Append[
  MapIndexed[z[[First[#2]]] D[f, #1] &, z],
  f
];

report = TestReport[{
  VerificationTest[
    tResult["kind"] === "enhanced-baikov" &&
      Length[tResult["cofactors"]] === Length[z] &&
      Together[
        D[f, t] - Join[tResult["cofactors"], {tResult["f_cofactor"]}] . generators
      ] === 0,
    True,
    TestID -> "bounded-search-finds-exact-zero-growth-operator"
  ],
  VerificationTest[
    sResult === <|
      "kind" -> "affine-fallback",
      "operator" -> prepared["operators", s]
    |>,
    True,
    TestID -> "bounded-miss-falls-back-without-error"
  ],
  VerificationTest[
    CANON`BaikovDerivative`ChooseDerivativeOperator[prepared, u][[1]],
    "DERIVATIVE_OPERATOR_INVALID",
    TestID -> "missing-variable-is-the-only-input-error"
  ]
}];

Print[InputForm[<|
  "total" -> report["TestsSucceededCount"] + report["TestsFailedCount"],
  "succeeded" -> report["TestsSucceededCount"],
  "failed" -> report["TestsFailedCount"]
|>]];
If[report["TestsFailedCount"] =!= 0, Print[InputForm[report["TestsFailed"]]]];
Exit[If[report["TestsFailedCount"] === 0, 0, 1]];
