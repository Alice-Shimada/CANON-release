#!/usr/bin/env wolframscript
$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{repoRoot, "methods", "libra", "Factorization.wl"}]];
Get[FileNameJoin[{repoRoot, "methods", "libra", "Multivariable.wl"}]];
options[n_] := CanonLibraFactorization`ReadOptions[<|
  "free_parameter_strategy" -> "bounded-rational-search", "free_parameter_max_trials" -> n|>];
select[template_, free_, n_, check_] :=
  CanonLibraFactorization`SelectFactor[template, free, options[n], check];
accept = Function[{factor, rules}, <||>];
coefficients[equations_, budget_:64] :=
  CanonLibraMultivariable`Private`coefficientEquations[equations, {x, y}, {a, b}, budget];
report = TestReport[{
  VerificationTest[
    {Length[DownValues[CanonLibraMultivariable`Propose]] > 0,
      Names["CanonLibraMultivariable`Run"]},
    {True, {}}, TestID -> "standalone-entry-avoids-system-run-collision"],
  VerificationTest[
    With[{r = coefficients[{2 (a + b), -6 (a + b), 3/5 (a + b)}]},
      {r["equation_count"], Length[r["original_equations"]], Length[r["equations"]],
        And @@ (MatchQ[Together[#/First[r["equations"]]], _Integer | _Rational] & /@
          r["original_equations"])}],
    {3, 3, 1, True}, TestID -> "numeric-proportions-share-one-equation"],
  VerificationTest[
    With[{r = coefficients[{6 (a + b), a - b, -2 (a + b)}]},
      r["equations"]], {a + b, a - b}, TestID -> "first-equation-order-is-preserved"],
  VerificationTest[
    With[{r = coefficients[{eps a, 2 eps a, a, (eps + 1) a}]},
      {Length[r["equations"]], Sort[Together[#/a] & /@ r["equations"]]}],
    {3, Sort[{eps, 1, eps + 1}]}, TestID -> "symbolic-regulator-factors-are-retained"],
  VerificationTest[
    With[{r = coefficients[{a (a + b), 2 a (a + b)}]},
      {Length[r["equations"]], Together[First[r["equations"]] - a (a + b)]}],
    {1, 0}, TestID -> "unknown-factor-is-not-divided-out"],
  VerificationTest[
    With[{r = coefficients[{0, 0}]},
      {r["equation_count"], r["original_equations"], r["equations"]}],
    {0, {}, {}}, TestID -> "empty-constraints-remain-empty"],
  VerificationTest[
    With[{r = coefficients[Range[5] a, 4]},
      {r["success"], r["limit_code"], r["equation_count"], KeyExistsQ[r, "equations"]}],
    {False, "EQUATION_BUDGET", 5, False}, TestID -> "raw-budget-precedes-proportional-dedup"],
  VerificationTest[
    coefficients[{1/a}]["limit_code"], "INVALID_LINEAR_EQUATIONS",
    TestID -> "unknown-denominator-stays-rejected"],
  VerificationTest[
    coefficients[{Sin[x] a}]["limit_code"], "NONPOLYNOMIAL_EQUATIONS",
    TestID -> "nonpolynomial-kinematics-stays-rejected"],
  VerificationTest[
    With[{r = select[IdentityMatrix[2], {}, 1, accept]},
      {r["success"], r["evidence", "free_parameter_trial_count"], r["rules"]}],
    {True, 1, {}}, TestID -> "no-free-parameters-needs-only-one-trial"],
  VerificationTest[
    With[{r = select[{{a}}, {a}, 1, accept]}, {r["success"], r["factor"]}],
    {True, {{1}}}, TestID -> "small-budget-allows-early-success"],
  VerificationTest[
    With[{r = select[{{a, b}, {b, a}}, {a, b}, 2, accept]},
      {r["success"], r["limit_code"], r["evidence", "free_parameter_trial_count"]}],
    {False, "FREE_PARAMETER_BUDGET", 2}, TestID -> "budget-stops-before-untried-unit-point"],
  VerificationTest[
    With[{r = select[{{a}}, {a}, 8, Function[{factor, rules}, <|"valid" -> False|>]]},
      {r["success"], r["evidence", "free_parameter_trial_count"]}],
    {False, 2}, TestID -> "one-parameter-policy-deduplicates-unit-point"],
  VerificationTest[
    With[{r = select[{{a, b}, {b, a}}, {a, b}, 3,
        Function[{factor, rules}, <|"equations_satisfied" -> True|>]]},
      {r["success"], r["index"], Together[Det[r["factor"]]]}],
    {True, 3, 1}, TestID -> "singular-first-point-does-not-exclude-invertible-factor"]
}];
Print[InputForm[<|"total" -> report["TestsSucceededCount"] + report["TestsFailedCount"],
  "succeeded" -> report["TestsSucceededCount"], "failed" -> report["TestsFailedCount"]|>]];
If[report["TestsFailedCount"] > 0, Print[InputForm[report["TestsFailed"]]]];
Exit[If[report["TestsFailedCount"] === 0, 0, 1]];
