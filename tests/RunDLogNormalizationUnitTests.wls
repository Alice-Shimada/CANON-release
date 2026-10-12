#!/usr/bin/env wolframscript
$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[repoRoot <> "/mma/lib/MethodCardCore.wl"];
Get[repoRoot <> "/mma/lib/TailCompletion.wl"];
ClearAll[x, y, z, eps];

(* Noncommuting residues distinguish the two-sided equation from
   (mu R(eps) - eps R(mu)).S, including a gauge singular at eps=0. *)
known = DiagonalMatrix[{1/eps, 1 + eps, 1}];
constants = {{{1,2,0},{0,3,4},{5,0,6}}, {{2,0,1},{0,1,0},{0,0,4}}};
residues = Map[Together, known.(eps #).Inverse[known], {2}] & /@ constants;
sampled = residues /. eps -> 1;
kernel = CanonTailCompletion`Private`dlogSparseKernel[residues, sampled, eps, 1];
dense = Join @@ MapThread[
  KroneckerProduct[#1, IdentityMatrix[3]] - eps KroneckerProduct[IdentityMatrix[3], Transpose[#2]] &,
  {residues, sampled}];
normalization = CanonTailCompletion`Private`dlogIntertwiner[residues, eps];
change = normalization["transformation"];
singularFirst = CanonTailCompletion`Private`dlogIntertwiner[{eps IdentityMatrix[2]}, eps];
meromorphic = CanonTailCompletion`Private`dlogIntertwiner[{{{0,1},{eps^2,0}}}, eps];
zeroResidues = CanonTailCompletion`Private`dlogIntertwiner[{ConstantArray[0,{3,3}]}, eps];
poleGauge = DiagonalMatrix[{1/(eps-1),1}];
poleResidues = Map[Together,poleGauge.(eps #).Inverse[poleGauge],{2}] & /@
  {{{0,1},{0,0}},{{0,0},{1,0}}};
poleReference = CanonTailCompletion`Private`dlogIntertwiner[poleResidues,eps];
noIntertwiner = CanonTailCompletion`Private`dlogIntertwiner[{{{1}}},eps];

(* Two independent roots prevent the old single-root primitive ansatz from
   solving this case. Row 1 is outside the current dependency closure but has
   an incoming coupling to row 2: lower normalization must include it. *)
letters = {(x + Sqrt[x^2+y])/(x - Sqrt[x^2+y]),
  (x + Sqrt[x^2+z])/(x - Sqrt[x^2+z])};
constantResidues = Normal /@ {SparseArray[{{1,2}->1,{4,2}->1},{4,4}],
  SparseArray[{{4,3}->1},{4,4}]};
oracle = DiagonalMatrix[{1/(1+eps),1/(1+eps),1/(1+2 eps),1}];
canonical = Table[eps Total[MapThread[#1 Together[D[#2,v]/#2] &,
  {constantResidues, letters}]], {v,{x,y,z}}];
raw = Map[Together, oracle.#.Inverse[oracle], {2}] & /@ canonical;
selected = <|"full_transformation"->IdentityMatrix[4], "transformed_matrices"->raw|>;
full = <|"source_basis"->{j1,j2,j3,j4}, "source_matrices"->raw,
  "variables"->{x,y,z},"regulator"->eps,"alphabet"->{},
  "block_boundaries"-><|"lower_dimension"->3,"current_dimension"->1|>|>;
completed = Quiet[CanonTailCompletion`CompleteAlgebraicTail[full,selected], Solve::svars];
bounded = CanonTailCompletion`Private`completeDLogEpsilon[full,
  {{IdentityMatrix[4],raw}}, {}, 0.001];
tooLarge = Join[full,<|"source_basis"->Range[65]|>];
dimensionBound = CanonTailCompletion`Private`completeDLogEpsilon[tooLarge,{}, {}, 1];
systemBound = CanonTailCompletion`Private`completeDLogEpsilon[full,
  {{IdentityMatrix[4],raw}}, Table[x+i,{i,129}], 10];
fieldFull = <|"source_basis"->{j1},"source_matrices"->{{{0}}},"variables"->{x},"regulator"->eps|>;
fieldBound = CanonTailCompletion`Private`completeDLogEpsilon[fieldFull,
  {{{{1}},{{{0}}}}},Table[Sqrt[x+i],{i,9}],10];
badRaw = {{{0,0},{eps/Sqrt[1+x+x^3],0}}};
badFull = <|"source_basis"->{j1,j2},"source_matrices"->badRaw,
  "variables"->{x},"regulator"->eps,"alphabet"->{},
  "block_boundaries"-><|"lower_dimension"->1,"current_dimension"->1|>|>;
bad = CanonTailCompletion`Private`completeDLogEpsilon[badFull,
  {{IdentityMatrix[2],badRaw}}, {}, 10];

tests = {
  VerificationTest[Length[kernel["basis"]], Length[NullSpace[dense]],
    TestID->"sparse-nullity-agrees-with-independent-dense-oracle"],
  VerificationTest[And @@ (CanonTailCompletion`Private`dlogMatrixZeroQ[dense.#] & /@ kernel["basis"]), True,
    TestID->"every-sparse-basis-vector-solves-the-complete-system"],
  VerificationTest[And @@ MapThread[CanonMethodCard`ZeroMatrixQ[#1.change-eps change.#2] &,
    {residues,sampled}], True, TestID->"noncommuting-two-sided-equation"],
  VerificationTest[CanonMethodCard`ZeroMatrixQ[(First[residues]-eps First[sampled]).change], False,
    TestID->"wrong-one-sided-equation-would-reject-valid-gauge"],
  VerificationTest[MatrixRank[singularFirst["transformation"]],2,
    TestID->"singular-all-ones-candidate-is-rejected-before-another-pattern"],
  VerificationTest[CanonMethodCard`ExactRationalExpressionQ[
    Together[Det[meromorphic["transformation"]]]],True,
    TestID->"meromorphic-gauge-remains-exact-rational"],
  VerificationTest[Quiet[FreeQ[meromorphic["transformation"] /. eps->0, _DirectedInfinity | Indeterminate]],False,
    TestID->"epsilon-zero-regularity-is-not-an-extra-constraint"],
  VerificationTest[zeroResidues["transformation"],IdentityMatrix[3],
    TestID->"all-zero-residues-return-identity"],
  VerificationTest[poleReference["diagnostics","reference"],"-1",
    TestID->"singular-exact-reference-is-skipped"],
  VerificationTest[noIntertwiner["transformation"],$Failed,
    TestID->"trivial-nullspace-does-not-produce-an-invertible-map"],
  VerificationTest[CanonMethodCard`DLogFormResidues[{{{(1+eps)/x}}},{x},eps,{x}],{{{1+eps}}},
    TestID->"raw-dlog-fit-allows-only-regulator-dependent-residues"],
  VerificationTest[CanonMethodCard`DLogResidues[{{{(1+eps)/x}}},{x},eps,{x}],$Failed,
    TestID->"independent-checker-still-requires-epsilon-form"],
  VerificationTest[CanonMethodCard`DLogFormResidues[{{{(1+eps x)/x}}},{x},eps,{x}],$Failed,
    TestID->"kinematic-residues-do-not-pass-by-sampling"],
  VerificationTest[completed["method"],"algebraic-dlog-epsilon-normalization",
    TestID->"ordinary-tail-selects-new-internal-completion"],
  VerificationTest[completed["solved"],True,TestID->"algebraic-full-prefix-is-solved"],
  VerificationTest[CanonMethodCard`DLogConnectionQ[completed["matrices"],{x,y,z},eps,completed["alphabet"]],True,
    TestID->"completed-connection-has-shared-exact-residues-in-all-directions"],
  VerificationTest[CanonTailCompletion`ActivePositions[raw,3],{2,3,4},
    TestID->"fixture-has-an-inactive-incoming-coupling"],
  VerificationTest[And @@ MapThread[CanonMethodCard`ZeroMatrixQ[
      #1.completed["transformation"]-completed["transformation"].#2] &,
    {raw,completed["matrices"]}], True,TestID->"entire-prefix-gauge-includes-inactive-incoming-coupling"],
  VerificationTest[bounded["diagnostics","stage"],"wall_budget",TestID->"wall-bound-is-retained-as-incomplete"],
  VerificationTest[dimensionBound["diagnostics","stage"],"dimension_bound",TestID->"dimension-bound-is-explicit"],
  VerificationTest[systemBound["diagnostics","stage"],"system_bound",TestID->"alphabet-and-equation-bound-precedes-fitting"],
  VerificationTest[fieldBound["diagnostics","stage"],"field_bound",TestID->"algebraic-field-bound-precedes-enumeration"],
  VerificationTest[bad["solved"],False,TestID->"nonlogarithmic-algebraic-form-is-not-promoted"],
  VerificationTest[bad["diagnostics","stage"],"not_dlog",TestID->"unsupported-form-retains-specific-stage"]
};
report = TestReport[tests];
summary = <|"total"->Length[tests],"succeeded"->report["TestsSucceededCount"],"failed"->report["TestsFailedCount"]|>;
Print[InputForm[summary]];
If[report["TestsFailedCount"]>0, Print[InputForm[report["TestsFailed"]]]];
If[CanonMethodCard`ScriptArguments[] =!= {}, Export[Last[CanonMethodCard`ScriptArguments[]], summary,"RawJSON"]];
Quit[If[report["TestsFailedCount"]===0,0,1]];
