#!/usr/bin/env wolframscript
$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[repoRoot <> "/mma/lib/MethodCardCore.wl"];
ClearAll[x, y, z, w, eps];
variables = {x, y, z, w};
connection[letter_, vars_, residue_:1] :=
  ({{eps residue Together[D[letter, #]/letter]}} &) /@ vars;
check[matrices_, vars_, letters_] :=
  CanonMethodCard`DLogResidues[matrices, vars, eps, letters];

divisor = z - x - y;
severalZeros = Times @@ (x - # & /@ {2, 3, 5, 7});
rootLetter = x + Sqrt[x^2 + z - x - y];
oddLetter = (1 - Sqrt[1 - x])/(1 + Sqrt[1 - x]);
exhaustedLetter = Times @@ (x - # & /@ Prime[Range[24]]);
hiddenResidue = 1 + (x - 2) (x - 3) (x - 5);
residueMatrices = {{{2, 1}, {0, -1}}, {{-3, 0}, {4, 2}}};
shared = Table[eps Total[MapThread[#1 Together[D[#2, direction]/#2] &,
  {residueMatrices, {divisor, w}}]], {direction, variables}];

tests = {
  VerificationTest[check[connection[x, {x}], {x}, {x}], {{{1}}},
    TestID -> "regular-rational-residue"],
  VerificationTest[check[connection[divisor, variables], variables, {divisor}], {{{1}}},
    TestID -> "first-prime-point-on-divisor-is-skipped"],
  VerificationTest[check[connection[severalZeros, {x}], {x}, {severalZeros}], {{{1}}},
    TestID -> "several-consecutive-singular-samples-are-skipped"],
  VerificationTest[check[shared, variables, {divisor, w}], residueMatrices,
    TestID -> "shared-matrix-residues-in-all-four-directions"],
  VerificationTest[check[connection[oddLetter, {x}], {x}, {oddLetter}], {{{1}}},
    TestID -> "regular-quadratic-field-letter"],
  VerificationTest[check[connection[rootLetter, variables], variables, {rootLetter}], {{{1}}},
    TestID -> "singular-conjugate-field-inversion-is-skipped"],
  VerificationTest[check[connection[Sqrt[divisor], variables], variables,
    {Sqrt[divisor]}], {{{1}}}, TestID -> "zero-root-letter-point-is-skipped"],
  VerificationTest[check[connection[exhaustedLetter, {x}], {x}, {exhaustedLetter}],
    $Failed, TestID -> "bounded-sample-exhaustion-fails-closed"],
  VerificationTest[check[connection[x - 2, {x}], {x}, {x}], $Failed,
    TestID -> "connection-pole-outside-alphabet-fails-closed"],
  VerificationTest[check[connection[divisor, variables], variables, {x, y, z, w}],
    $Failed, TestID -> "wrong-alphabet-does-not-pass"],
  VerificationTest[check[{{{eps/x^2}}}, {x}, {x}], $Failed,
    TestID -> "higher-order-pole-is-not-dlog"],
  VerificationTest[check[{{{eps}}}, {x}, {x}], $Failed,
    TestID -> "kinematic-residue-is-not-constant"],
  VerificationTest[check[{{{eps hiddenResidue/x}}}, {x}, {x}], $Failed,
    TestID -> "sample-fit-is-not-an-exact-identity-proof"],
  VerificationTest[check[{{{eps/x}}, {{2 eps/y}}}, {x, y}, {x y}], $Failed,
    TestID -> "direction-dependent-residues-are-rejected"],
  VerificationTest[check[{{{eps/Sqrt[1 + x + x^3]}}}, {x}, {x}], $Failed,
    TestID -> "nonlogarithmic-algebraic-one-form-is-rejected"],
  VerificationTest[check[{{{eps/x}}}, {x}, {0}], $Failed,
    TestID -> "identically-zero-letter-fails-closed"],
  VerificationTest[check[{{{0}}}, {x}, {}], {},
    TestID -> "empty-zero-connection-remains-supported"],
  VerificationTest[check[{{{1/x}}}, {x}, {x}], $Failed,
    TestID -> "epsilon-factorization-remains-mandatory"]
};
report = TestReport[tests];
summary = <|"total" -> Length[tests], "succeeded" -> report["TestsSucceededCount"],
  "failed" -> report["TestsFailedCount"]|>;
Print[InputForm[summary]];
If[report["TestsFailedCount"] =!= 0, Print[InputForm[report["TestsFailed"]]]];
If[Length[Rest[$ScriptCommandLine]] > 0,
  Export[Last[$ScriptCommandLine], summary, "RawJSON"]];
Quit[If[report["TestsFailedCount"] === 0, 0, 1]];
