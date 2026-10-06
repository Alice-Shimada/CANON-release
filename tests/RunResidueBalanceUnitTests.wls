#!/usr/bin/env wolframscript
$HistoryLength = 0;
repoRoot = DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "ResidueBalance.wl"}]];
{outputDir} = ExpandFileName /@ CanonMethodCard`ScriptArguments[];
CreateDirectory[outputDir, CreateIntermediateDirectories -> True];
facts = <||>;
record[name_, value_] := (facts[name] = TrueQ[value]);
makeCut[matrices_, variables_] := <|"schema" -> "canon-neu/sector-cut-de/v1",
  "sector" -> <|"id" -> 3, "propagator_count" -> 2|>, "family_id" -> "test",
  "basis_id" -> "test/source", "basis" -> Array[F, Length[First[matrices]]],
  "variables" -> variables, "regulator" -> eps,
  "coefficient_domain" -> "exact-rational-functions", "matrices" -> matrices|>;
checked[cut_, proposal_] := AssociationQ[proposal] && TrueQ[
  CanonMethodCard`CheckCoreCandidate[
    Join[proposal, <|"candidate_id" -> "unit", "construction_rejection" -> None|>],
    cut["matrices"], cut["variables"], cut["regulator"], 1]["pass"]];
limit[cut_, code_, options_ : <||>] := With[{value = CANON`ResidueBalance`ProposeCore[cut, options]},
  FailureQ[value] && value[[1]] === code && value[[2]]["nonexistence_proved"] === False];

nilpotent = {{0, 1, 0}, {0, 0, 1}, {0, 0, 0}};
toy = makeCut[{nilpotent/x}, {x}];
p = CANON`ResidueBalance`ProposeCore[toy];
record["nilpotent_index_three_has_exact_epsilon_form", checked[toy, p]];
record["nilpotent_specialization_is_nonzero", MatrixPower[nilpotent, 2] =!= ConstantArray[0, {3, 3}]];
record["epsilon_singular_gauge_is_retained", !FreeQ[Factor[Det[p["transformation"]]], eps]];
diagnosis = CANON`ResidueBalance`AnalyzeCore[toy];
record["diagnosis_never_claims_nonexistence", diagnosis["nonexistence_proved"] === False &&
  diagnosis["admissible_transformations"]["regulator_poles_allowed"] === True];
shifted = makeCut[{{{(eps - 2)/x - eps/(x - 1)}}}, {x}];
p = CANON`ResidueBalance`ProposeCore[shifted];
record["finite_infinity_integer_balances", checked[shifted, p] && Length[p["balances"]] === 2];
record["balance_bound_is_inconclusive", limit[shifted, "METHOD_EXHAUSTED", <|"max_balance_steps" -> 1|>]];
zeroFrame = makeCut[{{{-2/x}}}, {x}];
record["vanishing_normalized_connection", checked[zeroFrame, CANON`ResidueBalance`ProposeCore[zeroFrame]]];
multiple = {{1, 0, 0, 0}, {-1, 0, 0, 1}};
record["nonsingular_free_parameter_selection", Det[Total[Partition[#, 2] & /@ multiple]] === 0 &&
  Det[CANON`ResidueBalance`Private`invertibleMember[multiple, 2]] =!= 0];

fixtureDir = FileNameJoin[{repoRoot, "tests", "fixtures", "residue-balance"}];
g = CanonMethodCard`ReadWLData[FileNameJoin[{fixtureDir, "g3382-cut.wl"}]];
p = CANON`ResidueBalance`ProposeCore[g];
record["g3382_original_s_and_u_exact_check", checked[g, p]];
record["g3382_three_balances_and_nontrivial_shear", Length[p["balances"]] === 3 &&
  Length[p["shears"]] > 0];
record["pole_reference_is_skipped", p["regulator_factorization"]["reference_trials"][[1]]["reason"] === "pole"];
record["g3382_no_balance_budget_is_not_no_go", limit[g, "METHOD_EXHAUSTED", <|"max_balance_steps" -> 0|>]];
record["g3382_no_shear_budget_is_not_no_go", limit[g, "METHOD_EXHAUSTED", <|"max_shear_power" -> 0|>]];
renamed = g /. Thread[Append[g["variables"], g["regulator"]] -> {q, z, eta}];
renamed["variables"] = Reverse[renamed["variables"]];
renamed["matrices"] = Reverse[renamed["matrices"]];
record["symbol_and_variable_order_independent", checked[renamed, CANON`ResidueBalance`ProposeCore[renamed]]];
bad = Join[g, <|"matrices" -> ReplacePart[g["matrices"], {1, 1, 1} -> g["matrices"][[1, 1, 1]] + unknown]|>];
record["undeclared_coefficient_is_error", limit[bad, "INVALID_INPUT"]];
bad = makeCut[{ConstantArray[0, {3, 3}], x nilpotent}, {x, y}];
record["nonflat_input_is_error", limit[bad, "INVALID_INPUT"]];
nonseparable = makeCut[{y nilpotent, x nilpotent}, {x, y}];
record["flat_nonseparable_is_out_of_scope", CanonMethodCard`FlatConnectionQ[nonseparable["matrices"], {x, y}] &&
  limit[nonseparable, "OUT_OF_SCOPE"]];
record["fractional_spectrum_is_out_of_scope", limit[makeCut[{{{(1/2 + eps)/x}}}, {x}], "OUT_OF_SCOPE"]];
record["regulator_dependent_pole_is_out_of_scope", limit[makeCut[{{{1/(x - eps)}}}, {x}], "OUT_OF_SCOPE"]];
record["nonlinear_poles_are_out_of_scope", limit[makeCut[{{{1/(1 + x^2)}}}, {x}], "OUT_OF_SCOPE"]];
record["irregular_diagonal_is_scoped_exhaustion", limit[makeCut[{{{1/x^2}}}, {x}], "METHOD_EXHAUSTED"]];
record["dimension_bound_is_out_of_scope", limit[toy, "OUT_OF_SCOPE", <|"max_dimension" -> 2|>]];
record["invalid_option_is_error", limit[toy, "INVALID_OPTIONS", <|"reference_regulators" -> {0}|>]];
already = makeCut[{{{eps y}}, {{eps x}}}, {x, y}];
record["already_epsilon_multivariable_identity", checked[already, CANON`ResidueBalance`ProposeCore[already]] &&
  AssociationQ[CANON`ResidueBalance`AnalyzeCore[already]]];
tampered = Join[p, <|"transformed_matrices" -> (p["transformed_matrices"] + {IdentityMatrix[3], IdentityMatrix[3]})|>];
record["independent_checker_rejects_tampered_candidate", !checked[g, tampered]];

CanonMethodCard`WriteWLArtifact[toy, outputDir, "nilpotent-cut.wl"];
CanonMethodCard`WriteWLArtifact[Join[KeyTake[toy, {"sector", "family_id", "basis_id", "basis"}],
  <|"schema" -> "canon-neu/sector-basis/v1"|>], outputDir, "nilpotent-basis.wl"];
Export[FileNameJoin[{outputDir, "facts.json"}], facts, "RawJSON"];
Print[InputForm[facts]];
Quit[If[And @@ Values[facts], 0, 1]];
