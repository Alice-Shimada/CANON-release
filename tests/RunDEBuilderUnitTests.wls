#!/usr/bin/env wolframscript

testDirectory = DirectoryName[$InputFileName];
Get[FileNameJoin[{testDirectory, "..", "mma", "lib", "DEBuilder.wl"}]];

ClearAll[f, g, x, y, z, a, b, q];

failureTag[expression_] := If[FailureQ[expression], expression[[1]], Missing["NotFailure"]];

linearFamily = <|
  "parameters" -> {x, a, b},
  "operators" -> <|x -> {{1, 0}}|>
|>;
linearMasters = {f[1], f[2]};
linearRules = {f[3] -> a f[1] + b f[2]};
linearResult = BuildDifferentialEquations[linearFamily, linearMasters, linearRules];

scalelessResult = BuildDifferentialEquations[
  <|"parameters" -> {x}, "operators" -> <|x -> {{1, 0}}|>|>,
  {f[1]},
  {f[2] -> 0}
];

globalFamily = <|
  "parameters" -> {x, y},
  "operators" -> <|x -> {{0, -1/x}}, y -> {{0, 0}}|>
|>;
globalResult = BuildDifferentialEquations[globalFamily, {f[1]}, {}];

spectatorValue[pairIndex_Integer, attempt_Integer] := BlockRandom[
  SeedRandom[20260811 + 1000003 pairIndex + 1009 attempt];
  RandomChoice[{-1, 1}] RandomInteger[{2, 101}]/RandomInteger[{2, 101}]
];
firstPole = spectatorValue[1, 1];
secondAssignment = spectatorValue[1, 2];
sliceFamily = <|
  "parameters" -> {x, y, z},
  "operators" -> <|
    x -> {{0, -1/(z - firstPole)}},
    y -> {{0, 0}},
    z -> {{0, x/(z - firstPole)^2}}
  |>
|>;
sliceResult = BuildDifferentialEquations[sliceFamily, {f[1]}, {}];

poleValues = spectatorValue[1, #] & /@ Range[32];
polePolynomial = Times @@ (z - # & /@ poleValues);
allPoleFamily = <|
  "parameters" -> {x, y, z},
  "operators" -> <|
    x -> {{0, -1/polePolynomial}},
    y -> {{0, 0}},
    z -> {{0, x D[polePolynomial, z]/polePolynomial^2}}
  |>
|>;

fiveVariableFamily = <|
  "parameters" -> {x, y, z, a, b},
  "operators" -> <|
    x -> {{0, 0}}, y -> {{0, 0}}, z -> {{0, 0}}, a -> {{0, 0}}, b -> {{0, 0}}
  |>
|>;
fiveVariableResult = BuildDifferentialEquations[fiveVariableFamily, {f[1]}, {}];

tests = {
  VerificationTest[
    Keys[linearResult],
    {"matrices", "validity"},
    TestID -> "success-result-has-only-minimal-keys"
  ],
  VerificationTest[
    linearResult["matrices", x],
    {{0, -1}, {-2 a, -2 b}},
    TestID -> "affine-operator-rule-vectorization-and-row-assembly"
  ],
  VerificationTest[
    Keys[linearResult["matrices"]] === {x} &&
      linearResult["validity", "scope"] === "global-exact",
    True,
    TestID -> "ordered-variables-masters-and-validity-are-preserved"
  ],
  VerificationTest[
    scalelessResult["matrices"] === <|x -> {{0}}|> &&
      scalelessResult["validity", "scope"] === "global-exact",
    True,
    TestID -> "scaleless-zero-rule-closes-to-zero-matrix"
  ],
  VerificationTest[
    globalResult["matrices"] === <|x -> {{1/x}}, y -> {{0}}|> &&
      globalResult["validity", "scope"] === "global-exact" &&
      globalResult["validity", "pairs"] === {
        <|"variables" -> {x, y}, "assignments" -> {}|>
      },
    True,
    TestID -> "two-variable-curvature-is-global-and-exact"
  ],
  VerificationTest[
    sliceResult["validity", "scope"] === "exact-bivariate-slices" &&
      Length[sliceResult["validity", "pairs"]] === 3 &&
      sliceResult["validity", "pairs"][[1, "assignments"]] === {
        z -> secondAssignment
      },
    True,
    TestID -> "spectator-pole-retries-and-records-only-accepted-exact-assignment"
  ],
  VerificationTest[
    Keys[fiveVariableResult["matrices"]] === {x, y, z, a, b} &&
      Length[fiveVariableResult["matrices"]] === 5 &&
      Values[fiveVariableResult["matrices"]] === ConstantArray[{{0}}, 5] &&
      fiveVariableResult["validity", "scope"] === "exact-bivariate-slices" &&
      Length[fiveVariableResult["validity", "pairs"]] === 10,
    True,
    TestID -> "five-declared-operator-variables-produce-five-ordered-matrices"
  ],
  VerificationTest[
    failureTag @ BuildDifferentialEquations[
      Append[linearFamily, "head" -> f], linearMasters, linearRules
    ],
    "DE_INPUT_INVALID",
    TestID -> "rejects-redundant-family-field"
  ],
  VerificationTest[
    failureTag /@ {
      BuildDifferentialEquations[linearFamily, {}, {}],
      BuildDifferentialEquations[linearFamily, {f[1], f[1]}, {}]
    },
    {"DE_INPUT_INVALID", "DE_INPUT_INVALID"},
    TestID -> "rejects-empty-or-duplicate-master-order"
  ],
  VerificationTest[
    failureTag @ BuildDifferentialEquations[
      <|"parameters" -> {x}, "operators" -> <|x -> {{1, 0}}|>|>,
      {f[1/2]},
      {}
    ],
    "DE_SHAPE_INVALID",
    TestID -> "rejects-noninteger-master-index"
  ],
  VerificationTest[
    failureTag /@ {
      BuildDifferentialEquations[
        <|"parameters" -> {x, x}, "operators" -> <|x -> {{1, 0}}|>|>,
        {f[1]},
        {}
      ],
      BuildDifferentialEquations[
        <|"parameters" -> {x}, "operators" -> <|y -> {{1, 0}}|>|>,
        {f[1]},
        {}
      ]
    },
    {"DE_INPUT_INVALID", "DE_INPUT_INVALID"},
    TestID -> "rejects-duplicate-parameters-or-undeclared-operator-variable"
  ],
  VerificationTest[
    failureTag @ BuildDifferentialEquations[
      <|"parameters" -> {x}, "operators" -> <|x -> {{1, 0, 0}}|>|>,
      {f[1]},
      {}
    ],
    "DE_SHAPE_INVALID",
    TestID -> "rejects-operator-shape-not-inferred-master-arity"
  ],
  VerificationTest[
    failureTag @ BuildDifferentialEquations[
      <|"parameters" -> {x}, "operators" -> <|x -> {{0, 1.}}|>|>,
      {f[1]},
      {}
    ],
    "DE_COEFFICIENT_INVALID",
    TestID -> "rejects-inexact-operator-coefficient"
  ],
  VerificationTest[
    failureTag @ BuildDifferentialEquations[
      <|"parameters" -> {x}, "operators" -> <|x -> {{0, q}}|>|>,
      {f[1]},
      {}
    ],
    "DE_COEFFICIENT_INVALID",
    TestID -> "rejects-undeclared-operator-symbol"
  ],
  VerificationTest[
    failureTag @ BuildDifferentialEquations[
      <|"parameters" -> {x}, "operators" -> <|x -> {{0, Sqrt[2]}}|>|>,
      {f[1]},
      {}
    ],
    "DE_COEFFICIENT_INVALID",
    TestID -> "rejects-algebraic-number-outside-q-parameters"
  ],
  VerificationTest[
    failureTag @ BuildDifferentialEquations[linearFamily, linearMasters, {}],
    "DE_RESIDUAL_INTEGRALS",
    TestID -> "rejects-missing-reduction-rule"
  ],
  VerificationTest[
    failureTag @ BuildDifferentialEquations[
      linearFamily, linearMasters, {f[3] -> f[4]}
    ],
    "DE_RESIDUAL_INTEGRALS",
    TestID -> "rejects-residual-family-integral-in-rule-rhs"
  ],
  VerificationTest[
    failureTag /@ {
      BuildDifferentialEquations[
        linearFamily, linearMasters, {f[3] == f[1]}
      ],
      BuildDifferentialEquations[
        linearFamily,
        linearMasters,
        {f[3] -> f[1], f[3] -> f[2]}
      ]
    },
    {"DE_INPUT_INVALID", "DE_INPUT_INVALID"},
    TestID -> "rejects-nonrule-or-duplicate-rule-left-hand-side"
  ],
  VerificationTest[
    failureTag @ BuildDifferentialEquations[
      linearFamily, linearMasters, {f[3] -> a}
    ],
    "DE_RESIDUAL_INTEGRALS",
    TestID -> "rejects-rule-rhs-that-is-not-a-master-vector"
  ],
  VerificationTest[
    failureTag @ BuildDifferentialEquations[
      linearFamily, linearMasters, {f[3] -> 1. f[1]}
    ],
    "DE_COEFFICIENT_INVALID",
    TestID -> "rejects-inexact-rule-coefficient"
  ],
  VerificationTest[
    failureTag @ BuildDifferentialEquations[
      linearFamily, linearMasters, {f[1] -> f[2]}
    ],
    "DE_INPUT_INVALID",
    TestID -> "rejects-rule-that-overrides-ordered-master"
  ],
  VerificationTest[
    failureTag @ BuildDifferentialEquations[
      globalFamily, {f[1], g[2]}, {}
    ],
    "DE_SHAPE_INVALID",
    TestID -> "rejects-mixed-master-heads"
  ],
  VerificationTest[
    failureTag @ BuildDifferentialEquations[
      <|
        "parameters" -> {x, y},
        "operators" -> <|x -> {{0, -y}}, y -> {{0, 0}}|>
      |>,
      {f[1]},
      {}
    ],
    "DE_CURVATURE_NONZERO",
    TestID -> "rejects-nonzero-global-curvature"
  ],
  VerificationTest[
    failureTag @ BuildDifferentialEquations[
      <|
        "parameters" -> {x, y, z},
        "operators" -> <|x -> {{0, -y}}, y -> {{0, 0}}, z -> {{0, 0}}|>
      |>,
      {f[1]},
      {}
    ],
    "DE_CURVATURE_NONZERO",
    TestID -> "rejects-nonzero-exact-spectator-slice"
  ],
  VerificationTest[
    failureTag @ BuildDifferentialEquations[allPoleFamily, {f[1]}, {}],
    "DE_CURVATURE_INVALID",
    TestID -> "bounded-spectator-retry-rejects-all-pole-assignments"
  ],
  VerificationTest[
    failureTag @ BuildDifferentialEquations[linearFamily, linearMasters],
    "DE_INPUT_INVALID",
    TestID -> "rejects-non-three-argument-call"
  ]
};

report = TestReport[tests];
Print[InputForm[<|
  "total" -> report["TestsSucceededCount"] + report["TestsFailedCount"],
  "succeeded" -> report["TestsSucceededCount"],
  "failed" -> report["TestsFailedCount"]
|>]];
If[report["TestsFailedCount"] =!= 0, Print[InputForm[report["TestsFailed"]]]];
Exit[If[report["TestsFailedCount"] === 0, 0, 1]];
