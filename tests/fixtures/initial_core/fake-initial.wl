(* Fake provider for protocol and exact algebra tests. No FiniteFlow algorithm. *)
BeginPackage["INITIAL`"];
TCalc::usage = "Fixture-only protocol return.";
basisChange::usage = "Fixture-only exact gauge computation.";
FFInvMatMul::usage = "Fixture-only inverse matrix multiplication.";
Begin["`Private`"];
Options[TCalc] = {"TakeRow" -> 1, "Silent" -> False, "NThreads" -> 1,
  "MaxIterations" -> 20, "MaxDegree" -> 1000, "MaxPrimes" -> 150};
TCalc::diagnostic = "Fixture harmless display warning.";
TCalc[a_, ansatz_, x_, eps_, OptionsPattern[]] := Module[{path, calls, mode},
  path = FileNameJoin[{Directory[], "tcalc-calls.wl"}];
  calls = If[FileExistsQ[path], Get[path], {}];
  AppendTo[calls, <|"A" -> a, "ansatz" -> ansatz, "variable" -> x, "regulator" -> eps,
    "take_row" -> OptionValue["TakeRow"], "threads" -> OptionValue["NThreads"],
    "max_iterations" -> OptionValue["MaxIterations"], "max_degree" -> OptionValue["MaxDegree"],
    "max_primes" -> OptionValue["MaxPrimes"]|>];
  Put[calls, path];
  Print["Calculating psi."]; Print["Calculating degrees."];
  mode = Environment["CANON_INITIAL_FAKE_MODE"];
  If[mode === "warning", Message[TCalc::diagnostic]];
  If[mode === "degree", Print["Degree check failed, the integral cannot be a UT integral."]; Return[$Failed]];
  If[mode === "timeout", Pause[10]];
  If[mode === "partial", Return[{{1}}]];
  Print["Calculating solution."]; Print["Calculating full phi-matrix."];
  Print["Calculating T-matrix."];
  If[mode === "identity", IdentityMatrix[2], {{1,0},{x,1}}]
];
Options[basisChange] = {"NThreads" -> 1, "MaxDegree" -> 1000, "MaxPrimes" -> 150};
basisChange[a_, t_, x_, OptionsPattern[]] := Map[Together, Inverse[t].(a.t-D[t,x]), {2}];
Options[FFInvMatMul] = {"InvertInput" -> 0, "NThreads" -> 1, "MaxDegree" -> 1000, "MaxPrimes" -> 150};
FFInvMatMul[t_, rows_, OptionsPattern[]] := Module[{full=Map[Together, Inverse[t].rows, {2}]},
  If[Environment["CANON_INITIAL_FAKE_MODE"] === "corrupt_lower", full[[1,1]] += 1]; full];
End[];
EndPackage[];
