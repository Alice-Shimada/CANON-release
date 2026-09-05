#!/usr/bin/env wolframscript

$HistoryLength = 0;

testDirectory = DirectoryName[$InputFileName];
Get[FileNameJoin[{testDirectory, "..", "mma", "lib", "DEBuilder.wl"}]];

ClearAll[f, d, x, y, z, a, b];

masters = {f[0], f[1], f[2]};
rules = {f[3] -> d f[0] + d f[1] + f[2]};
twoVariableResult = BuildDifferentialEquations[
  <|
    "parameters" -> {d, x, y},
    "operators" -> <|x -> {{1, 0}}, y -> {{2, 0}}|>
  |>,
  masters,
  rules
];
expectedX = {{0, 0, 0}, {0, 0, -1}, {-2 d, -2 d, -2}};
expectedY = 2 expectedX;
oneVariableResult = BuildDifferentialEquations[
  <|"parameters" -> {x}, "operators" -> <|x -> {{0, 0}}|>|>, {f[1]}, {}];

fiveVariableResult = BuildDifferentialEquations[
  <|
    "parameters" -> {x, y, z, a, b},
    "operators" -> <|
      x -> {{0, 0}}, y -> {{0, 0}}, z -> {{0, 0}},
      a -> {{0, 0}}, b -> {{0, 0}}
    |>
  |>,
  {f[1]},
  {}
];

manyVariables = {x, y, z, a, b, c, h};
manyVariableResult = BuildDifferentialEquations[
  <|"parameters" -> Prepend[manyVariables, d],
    "operators" -> AssociationMap[{{0, 1/#}} &, manyVariables]|>, {f[1]}, {}];

tests = {
  VerificationTest[Values[manyVariableResult["matrices"]] === ({{-1/#}} & /@ manyVariables) &&
    TrueQ[manyVariableResult["validity", "flat"]] &&
    Length[manyVariableResult["validity", "pairs"]] === 21,
    True, TestID -> "seven-kinematic-directions-have-no-six-parameter-cap"],
  VerificationTest[
    Keys[twoVariableResult] === {"matrices", "validity"} &&
      Keys[twoVariableResult["matrices"]] === {x, y},
    True,
    TestID -> "minimal-result-and-variable-order"
  ],
  VerificationTest[
    twoVariableResult["matrices", x] === expectedX &&
      twoVariableResult["matrices", y] === expectedY,
    True,
    TestID -> "one-vectorization-assembles-exact-ordered-derivative-rows"
  ],
  VerificationTest[
    twoVariableResult["validity"] === <|
      "scope" -> "exact-point-samples",
      "flat" -> True,
      "pairs" -> {
        <|"variables" -> {x, y}, "assignments" -> {d -> 2/3, x -> 3/5, y -> 5/7}, "zero" -> True|>
      }
    |>,
    True,
    TestID -> "two-commuting-nonzero-matrices-have-exact-zero-curvature"
  ],
  VerificationTest[
    oneVariableResult["validity"] ===
      <|"scope" -> "exact-point-samples", "flat" -> True, "pairs" -> {}|>,
    True,
    TestID -> "one-variable-flatness-is-the-empty-curvature-conjunction"
  ],
  VerificationTest[
    Keys[fiveVariableResult["matrices"]] === {x, y, z, a, b} &&
      Values[fiveVariableResult["matrices"]] === ConstantArray[{{0}}, 5] &&
      fiveVariableResult["validity", "scope"] === "exact-point-samples" &&
      fiveVariableResult["validity", "flat"] === True &&
      Length[fiveVariableResult["validity", "pairs"]] === 10 &&
      fiveVariableResult["validity", "pairs"][[1]] === <|
        "variables" -> {x, y},
        "assignments" -> {x -> 2/3, y -> 3/5, z -> 5/7, a -> 7/11, b -> 11/13},
        "zero" -> True
      |>,
    True,
    TestID -> "five-variable-slices-use-one-explicit-exact-spectator-point"
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
