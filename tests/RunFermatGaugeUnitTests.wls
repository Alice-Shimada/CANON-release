#!/usr/bin/env wolframscript
$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[repoRoot <> "/mma/lib/MethodCardCore.wl"];
Get[First[CanonMethodCard`ScriptArguments[]]];
Fermatica`$FermatCMD = Environment["FERMATPATH"];
ClearAll[x, y, eps];
t = {{Sqrt[x], x/Sqrt[y]}, {0, Sqrt[y]}};
b = {eps IdentityMatrix[2]/x, eps IdentityMatrix[2]/y};
a = MapThread[Map[Together, (D[t, #2] + t.#1).Inverse[t], {2}] &, {b, {x, y}}];
gauge[args___] := Quiet[CanonMethodCard`FermatGaugeIdentityQ[args], FrontEndObject::notavail];
tests = {
  VerificationTest[gauge[a, {x, y}, t, b], True,
    TestID -> "exact-gauge-in-two-algebraic-generators"],
  VerificationTest[gauge[a, {x, y}, t,
    {b[[1]], b[[2]] + {{eps/y, 0}, {0, 0}}}], False,
    TestID -> "an-incorrect-canonical-witness-is-rejected"],
  VerificationTest[gauge[
    {{{eps/x}}}, {x}, {{1}}, {{{eps/x}}}], True,
    TestID -> "rational-gauge-with-no-algebraic-generators"]
};
report = TestReport[tests];
Print[InputForm[<|"total" -> Length[tests], "succeeded" -> report["TestsSucceededCount"],
  "failed" -> report["TestsFailedCount"]|>]];
If[report["TestsFailedCount"] > 0, Print[InputForm[report["TestsFailed"]]]];
Quit[If[report["TestsFailedCount"] === 0, 0, 1]];
