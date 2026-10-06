BeginPackage["CanonCANONICAControl`"];

CaptureStage::usage = "CaptureStage[expr, stage, block, seconds, attemptedAnsatz:<||>] evaluates one bounded public CANONICA stage and returns result and diagnostics. Messages remain visible to the caller's log.";
ClassifyMessages::usage = "ClassifyMessages[messageTags, stage] classifies CANONICA message names without treating finite ansatz failure as a family obstruction.";
LoadFiniteAnsatz::usage = "LoadFiniteAnsatz[task, inputPath, payloadKey, expected, maxTerms] validates a hashed finite rational ansatz artifact. expected contains kind, identity, scope, variables; returns terms/provenance or Failure.";

Begin["`Private`"];

failure[reason_String, field_String] := Failure["INVALID_ANSATZ", <|"reason" -> reason, "field" -> field|>];
sameAssociationQ[left_, right_] := AssociationQ[left] && AssociationQ[right] &&
  Sort[Keys[left]] === Sort[Keys[right]] && And @@ (SameQ[left[#], right[#]] & /@ Keys[right]);

(* Reject non-rational syntax and undeclared symbols before algebraic reduction.
   In particular, no approximate number, symbolic power, root or special function
   becomes admissible merely because a simplifier happens to cancel it. *)
rationalSyntaxQ[expr_, variables_List] := Which[
  IntegerQ[expr] || Head[expr] === Rational, True,
  MatchQ[expr, _Symbol], MemberQ[variables, expr],
  Head[expr] === Plus || Head[expr] === Times,
    AllTrue[List @@ expr, rationalSyntaxQ[#, variables] &],
  Head[expr] === Power,
    IntegerQ[Last[expr]] && rationalSyntaxQ[First[expr], variables],
  True, False
];
rationalTermQ[expr_, variables_List] := Module[{value},
  If[!rationalSyntaxQ[expr, variables], Return[False]];
  value = Quiet @ Check[Together[expr], $Failed];
  value =!= $Failed && rationalSyntaxQ[value, variables] &&
    PolynomialQ[Numerator[value], variables] && PolynomialQ[Denominator[value], variables] &&
    Denominator[value] =!= 0
];

LoadFiniteAnsatz[task_Association, inputPath_String, payloadKey_String,
    expected_Association, maxTerms_Integer] := Module[
  {descriptor, requestedPath, path, hash, declaredHash, artifact, terms, variables},
  If[maxTerms <= 0, Return[failure["maxTerms must be a positive integer", "max_ansatz_terms"]]];
  descriptor = Lookup[Lookup[task, "payload", <||>], payloadKey, None];
  If[!AssociationQ[descriptor] || Lookup[descriptor, "type", None] =!= "mathematica-expression",
    Return[failure["ansatz descriptor must be a mathematica-expression artifact", payloadKey]]];
  requestedPath = Lookup[descriptor, "path", None];
  declaredHash = Lookup[descriptor, "sha256", None];
  If[!StringQ[requestedPath] || requestedPath === "",
    Return[failure["ansatz path must be a nonempty string", payloadKey <> ".path"]]];
  If[!StringQ[declaredHash] || !StringMatchQ[declaredHash, RegularExpression["[0-9a-fA-F]{64}"]],
    Return[failure["ansatz descriptor requires its SHA-256", payloadKey <> ".sha256"]]];
  path = ExpandFileName[If[StringStartsQ[requestedPath, "/"] ||
      StringMatchQ[requestedPath, RegularExpression["^[A-Za-z]:[\\\\/].*"]], requestedPath,
    FileNameJoin[{DirectoryName[ExpandFileName[inputPath]], requestedPath}]]];
  If[FileType[path] =!= File, Return[failure["ansatz path is not a file", payloadKey <> ".path"]]];
  hash = Quiet @ Check[FileHash[path, "SHA256", "HexString"], $Failed];
  If[!StringQ[hash] || ToLowerCase[declaredHash] =!= ToLowerCase[hash],
    Return[failure["ansatz SHA-256 differs from the declared artifact", payloadKey <> ".sha256"]]];
  artifact = Quiet @ Check[CanonMethodCard`ReadWLData[path], $Failed];
  If[!AssociationQ[artifact] || Lookup[artifact, "schema", None] =!= "canon-neu/canonica-rational-ansatz/v1",
    Return[failure["unexpected finite rational ansatz schema", "schema"]]];
  If[Lookup[artifact, "kind", None] =!= Lookup[expected, "kind", Missing["kind"]],
    Return[failure["ansatz kind differs from the requested operation", "kind"]]];
  If[!sameAssociationQ[Lookup[artifact, "identity", None], Lookup[expected, "identity", None]],
    Return[failure["ansatz identity differs from the exact source gauge and basis", "identity"]]];
  If[!sameAssociationQ[Lookup[artifact, "scope", None], Lookup[expected, "scope", None]],
    Return[failure["ansatz scope differs from the requested block", "scope"]]];
  variables = Lookup[expected, "variables", None];
  If[!ListQ[variables] || variables === {} || !AllTrue[variables, MatchQ[#, _Symbol] &] ||
      DeleteDuplicates[variables] =!= variables || Lookup[artifact, "variables", None] =!= variables,
    Return[failure["ansatz variables must match the declared ordered kinematic variables", "variables"]]];
  terms = Lookup[artifact, "terms", None];
  If[!ListQ[terms] || terms === {} || Length[terms] > maxTerms,
    Return[failure["ansatz terms must be a nonempty list within max_ansatz_terms", "terms"]]];
  If[!AllTrue[terms, rationalTermQ[#, variables] &],
    Return[failure["ansatz terms must be exact rational functions of declared kinematic variables only", "terms"]]];
  <|"terms" -> terms, "provenance" -> <|"path" -> path, "sha256" -> ToLowerCase[hash],
    "kind" -> artifact["kind"], "identity" -> artifact["identity"],
    "scope" -> artifact["scope"], "term_count" -> Length[terms], "max_terms" -> maxTerms|>|>
];

ClassifyMessages[tags_List, stage_String] := Module[{lower = ToLowerCase /@ tags, classes = {}},
  If[AnyTrue[lower, StringContainsQ[#, "nonrationalinv" | "nonrationaltr"] &],
    AppendTo[classes, "rational_transformation_obstruction"]];
  If[AnyTrue[lower, StringContainsQ[#, "noepsform" | "ndlogtr" | "::trace"] &],
    AppendTo[classes, "trace_necessary_condition_failed"]];
  If[AnyTrue[lower, StringContainsQ[#, "finiteansatzfailed" | "::nosol"] &],
    AppendTo[classes, "finite_ansatz_exhausted"]];
  If[AnyTrue[lower, StringContainsQ[#, "invansatz"] &], AppendTo[classes, "invalid_ansatz"]];
  If[AnyTrue[lower, StringContainsQ[#, "epsnormalization" | "normalizationfailed"] &],
    AppendTo[classes, "epsilon_normalization_failed"]];
  If[AnyTrue[lower, StringContainsQ[#, "notdlog" | "incalphabet"] &],
    AppendTo[classes, "dlog_form_failed"]];
  If[AnyTrue[lower, StringContainsQ[#, "nonrational" | "baddims" | "badbounds" | "notsquare" |
      "fewvars" | "varnumber" | "diffdims" | "falsebounds"] &] &&
      !MemberQ[classes, "rational_transformation_obstruction"], AppendTo[classes, "invalid_differential_system"]];
  DeleteDuplicates[classes]
];

messageStage[tags_List, requested_String] := Which[
  AnyTrue[tags, StringContainsQ[#, "TransformDiagonalBlock" | "FindAnsatzT"] &], "diagonal_block",
  AnyTrue[tags, StringContainsQ[#, "CalculateNextSubsectorD" | "TransformOffDiagonalBlock" | "FindD"] &], "off_diagonal_block",
  AnyTrue[ToLowerCase /@ tags, StringContainsQ[#, "transformdlogtoepsform" | "epsnormalization"] &], "epsilon_normalization",
  True, requested
];

SetAttributes[CaptureStage, HoldFirst];
CaptureStage[expr_, stage_String, block_, seconds_?NumericQ, attemptedAnsatz_Association:<||>] := Module[
  {result, messages, tags, classes, elapsed, timedOut = False, aborted = False, failed},
  If[!TrueQ[seconds > 0], Return[<|"result" -> $Aborted, "diagnostics" ->
    <|"requested_stage" -> stage, "failed_stage" -> stage, "failed_block" -> block,
      "message_tags" -> {}, "diagnostic_classes" -> {"time_budget_exhausted"},
      "elapsed_seconds" -> 0, "time_limit_seconds" -> seconds, "timed_out" -> True,
      "aborted" -> False, "attempted_ansatz" -> attemptedAnsatz|>|>]];
  {elapsed, {result, messages}} = AbsoluteTiming[Block[{$MessageList = {}},
    result = CheckAbort[TimeConstrained[expr, Max[0.001, seconds],
      (timedOut = True; $Aborted)], (aborted = True; $Aborted)];
    {result, $MessageList}
  ]];
  tags = DeleteDuplicates[ToString[#, InputForm] & /@ messages];
  (* Preserve the original package messages; the labels below describe the
     bounded operation, never the existence of a canonical basis for a family. *)
  classes = ClassifyMessages[tags, stage];
  failed = result === False || result === $Failed || result === $Aborted ||
    result === Null || MatchQ[result, {False, ___}];
  If[timedOut, AppendTo[classes, "time_budget_exhausted"]];
  If[aborted, AppendTo[classes, "aborted"]];
  If[failed && classes === {}, AppendTo[classes,
    Switch[stage, "provider_epsilon_check", "provider_epsilon_check_failed",
      "source_gauge_check", "provider_source_gauge_failed",
      "epsilon_normalization", "epsilon_normalization_failed", _, "finite_ansatz_exhausted"]]];
  <|"result" -> result, "diagnostics" -> <|"requested_stage" -> stage,
    "failed_stage" -> If[failed, messageStage[tags, stage], Null],
    "failed_block" -> If[failed, block, Null], "message_tags" -> tags,
    "diagnostic_classes" -> DeleteDuplicates[classes], "elapsed_seconds" -> elapsed,
    "time_limit_seconds" -> seconds, "timed_out" -> timedOut, "aborted" -> aborted,
    "attempted_ansatz" -> attemptedAnsatz|>|>
];

End[];
EndPackage[];
