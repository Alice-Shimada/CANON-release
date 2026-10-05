(* Test provider: records public calls and can emit individual package failures.
   The tutorial gauge is independently checked by CHECK_CORE in the tests. *)
BeginPackage["CANONICA`"];
eps;
$ComputeParallel = False;
VerbosityLevel; TDeltaNumeratorDegree; TDeltaDenominatorDegree; DDeltaNumeratorDegree;
TransformDiagonalBlock::nonrationalinv = "Synthetic nonrational transformation `1`.";
TransformDiagonalBlock::noepsform = "Synthetic necessary trace condition failed.";
TransformDiagonalBlock::finiteansatzfailed = "Synthetic finite T ansatz exhausted.";
TransformDlogToEpsForm::epsnormalization = "Synthetic epsilon normalization exhausted.";

Options[RecursivelyTransformSectors] = {VerbosityLevel -> 1,
  TDeltaNumeratorDegree -> 0, TDeltaDenominatorDegree -> 0, DDeltaNumeratorDegree -> 0};
Options[TransformNextDiagonalBlock] = {VerbosityLevel -> 1,
  TDeltaNumeratorDegree -> 0, TDeltaDenominatorDegree -> 0};
Options[TransformOffDiagonalBlock] = {VerbosityLevel -> 1, DDeltaNumeratorDegree -> 0};
Options[TransformDlogToEpsForm] = {VerbosityLevel -> 1};

Begin["`Private`"];
record[stage_, terms_, options_] := Module[{stream},
  stream = OpenAppend[Environment["CANON_TEST_CAPTURE"]];
  WriteString[stream, ToString[<|"stage" -> stage, "terms" -> terms, "options" -> options|>, InputForm], "\n"];
  Close[stream];
];
attempt[a_, vars_] := Module[{t, mode = Environment["CANON_TEST_CANONICA_MODE"]},
  Switch[mode,
    "nonrationalinv", Message[TransformDiagonalBlock::nonrationalinv, "Sqrt[x]"]; Return[{False, {{}, {{}}}}],
    "trace", Message[TransformDiagonalBlock::noepsform]; Return[{False, {{}, {{}}}}],
    "finiteansatzfailed", Message[TransformDiagonalBlock::finiteansatzfailed]; Return[{False, {{}, {{}}}}],
    "slow", Pause[2],
    "silent", Return[{False, {{}, {{}}}}],
    "malformed", Return["not-a-provider-pair"]
  ];
  t = If[Length[First[a]] === 2, {{1, First[vars]}, {0, 1}}, IdentityMatrix[Length[First[a]]]];
  If[mode === "wrong-source-gauge", Return[{IdentityMatrix[Length[First[a]]],
    MapThread[Together[Inverse[t].(#1.t - D[t, #2])] &, {a, vars}]}]];
  If[mode === "undeclared-coefficient", t[[1, 2]] = Global`y];
  fixtureTransformation = t;
  {t, MapThread[Together[Inverse[t].(#1.t - D[t, #2])] &, {a, vars}]}
];
installSlowInverse[] := With[{t = fixtureTransformation, inverse = Inverse[fixtureTransformation]},
  (* Install only after provider calculations, and only for its concrete gauge. *)
  Unprotect[Inverse];
  Inverse[t] := (Pause[2]; inverse);
  Protect[Inverse];
];
End[];

SectorBoundariesFromDE[a_] := {{1, Length[First[a]]}};
RecursivelyTransformSectors[a_, vars_, bounds_, range_, OptionsPattern[]] := (
  CANONICA`Private`record["RecursivelyTransformSectors", {},
    {OptionValue[TDeltaNumeratorDegree], OptionValue[TDeltaDenominatorDegree], OptionValue[DDeltaNumeratorDegree]}];
  CANONICA`Private`attempt[a, vars]
);
TransformNextDiagonalBlock[a_, vars_, bounds_, prev_, previous_, terms_, OptionsPattern[]] := (
  CANONICA`Private`record["TransformNextDiagonalBlock", terms,
    {OptionValue[TDeltaNumeratorDegree], OptionValue[TDeltaDenominatorDegree]}];
  CANONICA`Private`attempt[a, vars]
);
TransformOffDiagonalBlock[vars_, bounds_, t_, a_, OptionsPattern[]] := (
  CANONICA`Private`record["TransformOffDiagonalBlock", {}, {OptionValue[DDeltaNumeratorDegree]}]; {t, a}
);
TransformDlogToEpsForm[vars_, bounds_, t_, a_, OptionsPattern[]] := (
  CANONICA`Private`record["TransformDlogToEpsForm", {}, {}];
  If[Environment["CANON_TEST_CANONICA_MODE"] === "epsnormalization",
    Message[TransformDlogToEpsForm::epsnormalization]; {False, {t, a}}, {t, a}]
);
ExtractIrreducibles[___] := {Global`x, 1 - Global`x, 1 + Global`x};
CheckEpsForm[___] := (
  If[Environment["CANON_TEST_CANONICA_MODE"] === "slow-inverse",
    CANONICA`Private`installSlowInverse[]];
  True
);
EndPackage[];
