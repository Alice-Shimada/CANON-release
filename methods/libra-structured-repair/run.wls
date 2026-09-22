$HistoryLength = 0;

repoRoot = DirectoryName[DirectoryName[DirectoryName[ExpandFileName[$InputFileName]]]];
Get[FileNameJoin[{repoRoot, "mma", "lib", "MethodCardCore.wl"}]];

args = CanonMethodCard`ScriptArguments[];
If[Length[args] =!= 2, Print["Usage: run.wls <input.json> <fresh-output-dir>"]; Quit[2]];
{inputPath, outputDir} = ExpandFileName /@ args;
task = CanonMethodCard`ReadTask[inputPath, "REPAIR_WITH_LIBRA"];
If[FailureQ[task], Print[InputForm[task]]; Quit[2]];

writeFailure[status_String, code_String, reason_String, details_: <||>] := (
  CanonMethodCard`WriteProviderResult[
    task, outputDir, status, code, <||>,
    Join[
      <|
        "method_id" -> "libra-structured-repair-single-variable",
        "reason" -> reason,
        "fallback_invoked" -> False
      |>,
      details
    ]
  ];
  Quit[If[status === "ERROR", 1, 0]]
);

If[FileExistsQ[outputDir],
  Print["Structured repair requires a new output directory: ", outputDir];
  Quit[2]
];

prepared = CanonMethodCard`LoadArtifact[task, inputPath, "prepared_basis"];
route = CanonMethodCard`LoadArtifact[task, inputPath, "route_decision"];
request = CanonMethodCard`LoadArtifact[task, inputPath, "repair_request"];
If[FailureQ[prepared] || FailureQ[route] || FailureQ[request],
  writeFailure["ERROR", "INVALID_REPAIR_INPUT", "Cannot load one or more structured-repair artifacts"]
];

preparedCheck = CanonMethodCard`ValidatePreparedBasis[prepared];
If[FailureQ[preparedCheck],
  writeFailure["ERROR", "INVALID_REPAIR_INPUT", "The prepared-basis contract is invalid"]
];
If[
  Lookup[route, "schema", None] =!= "canon-neu/route-decision/v1" ||
    Lookup[route, "decision", None] =!= "REPAIR_WITH_LIBRA",
  writeFailure["ERROR", "INVALID_REPAIR_INPUT", "The route decision is not REPAIR_WITH_LIBRA"]
];

(* Determine scope without loading external packages. The authoritative validator still rejects nonflat exact multivariable systems. *)
If[
  AssociationQ[Lookup[request, "localized_target", None]] &&
    Lookup[request["localized_target"], "scope", None] =!= "LOCALIZED_BLOCK",
  writeFailure[
    "INCONCLUSIVE", "OUT_OF_SCOPE",
    "This repair scope supports only localized block defects"
  ]
];
requestVariables = Lookup[request, "variables", None];
If[ListQ[requestVariables] && Length[requestVariables] =!= 1,
  requestMatrices = Lookup[request, "original_matrices", None];
  requestBasis = Lookup[request, "basis", None];
  requestRegulator = Lookup[request, "regulator", None];
  requestParameters = Lookup[request, "parameters", None];
  requestDimension = If[ListQ[requestBasis], Length[requestBasis], 0];
  If[
    requestVariables =!= prepared["identity"]["variables"] ||
      requestRegulator =!= prepared["identity"]["regulator"] ||
      requestParameters =!= {} || requestDimension < 1,
    writeFailure["ERROR", "INVALID_REPAIR_INPUT", "The multivariable scope identity or declared parameters are invalid"]
  ];
  If[
    !ListQ[requestMatrices] || Length[requestMatrices] =!= Length[requestVariables] ||
      !And @@ (
        MatrixQ[#] && Dimensions[#] === {requestDimension, requestDimension} &&
          And @@ (CanonMethodCard`DeclaredCoefficientDomainQ[
            #, Join[requestVariables, {requestRegulator}, requestParameters]
          ] & /@ Flatten[#]) & /@ requestMatrices
      ),
    writeFailure["ERROR", "INVALID_DIFFERENTIAL_SYSTEM", "The multivariable differential system is invalid"]
  ];
  If[!CanonMethodCard`FlatConnectionQ[requestMatrices, requestVariables],
    writeFailure[
      "ERROR", "INVALID_DIFFERENTIAL_SYSTEM", "The multivariable differential connection is not flat",
      <|"field" -> "original_matrices.flatness"|>
    ]
  ];
  writeFailure[
    "INCONCLUSIVE", "OUT_OF_SCOPE",
    "v1 supports only one exact rational variable"
  ]
];
requestCheck = CanonMethodCard`ValidateStructuredRepairInput[prepared, route, request];
If[FailureQ[requestCheck],
  requestFailureField = Lookup[requestCheck[[2]], "Field", "repair_request"];
  writeFailure[
    "ERROR",
    If[StringStartsQ[requestFailureField, "original_matrices"],
      "INVALID_DIFFERENTIAL_SYSTEM", "INVALID_REPAIR_INPUT"
    ],
    Lookup[requestCheck[[2]], "Message", "The structured-repair contract is invalid"],
    <|"field" -> requestFailureField|>
  ]
];
If[
  Length[request["variables"]] =!= 1 ||
    Lookup[request["localized_target"], "scope", None] =!= "LOCALIZED_BLOCK",
  writeFailure[
    "INCONCLUSIVE", "OUT_OF_SCOPE",
    "This repair scope supports only one exact rational variable and one localized block"
  ]
];

package = CanonMethodCard`ResolveMethodPackage[task, inputPath, "Libra`"];
If[FailureQ[package],
  If[
    MatchQ[package, Failure["INVALID_METHOD_OPTIONS", _Association]],
    writeFailure["ERROR", "INVALID_OPTIONS", "method_options.package_entry must be a nonempty path string"],
    writeFailure["ERROR", "TOOL_UNAVAILABLE", "The declared Libra package entry is unavailable"]
  ]
];
entry = package["entry"];
entryHash = Quiet @ Check[FileHash[entry, "SHA256", "HexString"], $Failed];
If[!StringQ[entryHash] || !StringMatchQ[entryHash, RegularExpression["[0-9a-fA-F]{64}"]],
  writeFailure["ERROR", "TOOL_ERROR", "Cannot hash the Libra entry"]
];

loadSucceeded = TrueQ[Quiet @ Check[(Get[entry]; True), False]];
If[!loadSucceeded, writeFailure["ERROR", "TOOL_ERROR", "The Libra package failed to load"]];
requiredSymbols = {"NewDSystem", "Fuchsify", "Transform", "FactorOut", "OverallTransformation", "EFormQ"};
libraSymbolAvailableQ[name_String] := NameQ["Libra`" <> name] || NameQ["Global`" <> name];
If[!And @@ (libraSymbolAvailableQ /@ requiredSymbols),
  writeFailure["ERROR", "TOOL_ERROR", "Libra lacks required public API symbols"]
];
Libra`$LibraUseFermat = False;

variable = First[request["variables"]];
regulator = request["regulator"];
matrix = Map[Together, First[request["original_matrices"]], {2}];
If[!TrueQ[Quiet @ Check[NewDSystem[repairSystem, variable -> matrix, Print -> False]; True, False]],
  writeFailure["ERROR", "TOOL_ERROR", "Libra could not initialize the full-prefix system"]
];

fuchsTransformation = Quiet @ Check[
  Fuchsify[
    repairSystem, variable, Monitor -> False,
    Fermatica`UseFermat -> False
  ],
  $Failed
];
If[!MatrixQ[fuchsTransformation],
  writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "Libra Fuchsify produced no matrix transformation"]
];
If[!TrueQ[Quiet @ Check[
    Transform[
      repairSystem, fuchsTransformation, Print -> False,
      Fermatica`UseFermat -> False
    ]; True,
    False
  ]],
  writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "Libra could not apply its Fuchsify transformation"]
];

factorTransformation = Quiet @ Check[
  FactorOut[
    repairSystem, variable, regulator, 1/2,
    Fermatica`UseFermat -> False
  ] /. _C -> 1,
  $Failed
];
If[!MatrixQ[factorTransformation],
  writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "Libra FactorOut produced no matrix transformation"]
];
If[!TrueQ[Quiet @ Check[
    Transform[
      repairSystem, factorTransformation, Print -> False,
      Fermatica`UseFermat -> False
    ]; True,
    False
  ]],
  writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "Libra could not apply its FactorOut transformation"]
];

transformation = Quiet @ Check[
  OverallTransformation[
    repairSystem, Monitor -> False,
    Fermatica`UseFermat -> False
  ][Transform],
  $Failed
];
transformed = Quiet @ Check[repairSystem[variable], $Failed];
providerEFormQ = TrueQ @ Quiet @ Check[EFormQ[transformed, regulator], False];
If[!MatrixQ[transformation] || !MatrixQ[transformed],
  writeFailure["INCONCLUSIVE", "METHOD_EXHAUSTED", "The bounded Libra stages produced no matrix candidate"]
];

candidateArtifact = <|
  "schema" -> "canon-neu/libra-structured-repair-candidate/v1",
  "provider_status" -> "PROVISIONAL/CANDIDATE_TRANSFORMATION",
  "preparation_id" -> request["preparation_id"],
  "family_id" -> request["family_id"],
  "basis_id" -> request["basis_id"],
  "selected_candidate_id" -> request["selected_candidate_id"],
  "coefficient_domain" -> request["coefficient_domain"],
  "basis" -> request["basis"],
  "variables" -> request["variables"],
  "regulator" -> request["regulator"],
  "parameters" -> request["parameters"],
  "repair_scope" -> request["repair_scope"],
  "convention" -> request["convention"],
  "original_matrices" -> request["original_matrices"],
  "transformation" -> transformation,
  "transformed_matrices" -> {transformed},
  "frozen_prefix" -> request["frozen_prefix"],
  "localized_target" -> request["localized_target"],
  "alphabet" -> request["alphabet"],
  "method" -> <|
    "id" -> "libra-structured-repair-single-variable",
    "tool" -> "Libra",
    "tool_identity" -> Libra`$LibraVersion,
    "package_source" -> package["source"],
    "entry" -> entry,
    "entry_sha256" -> entryHash,
    "wolfram_version" -> $Version,
    "system_id" -> $SystemID,
    "options" -> <|"use_fermatica" -> False, "factor_out_mu" -> 1/2|>,
    "stages" -> {"NewDSystem", "Fuchsify", "Transform", "FactorOut", "Transform", "OverallTransformation", "EFormQ"}
  |>,
  "provider_evidence" -> <|
    "epsilon_form" -> providerEFormQ,
    "fuchs_transformation" -> fuchsTransformation,
    "factor_transformation" -> factorTransformation,
    "authority" -> "NON_AUTHORITATIVE"
  |>
|>;

providerCheck = CanonMethodCard`StructuredRepairPublicationGate[request, candidateArtifact];
If[!TrueQ[Lookup[providerCheck, "pass", False]],
  writeFailure[
    "INCONCLUSIVE", "METHOD_EXHAUSTED",
    "The Libra candidate failed the exact frozen-prefix publication gate",
    <|"rejection_signature" -> Lookup[providerCheck, "reasons", {}]|>
  ]
];

artifactPath = CanonMethodCard`WriteWLArtifact[
  candidateArtifact, outputDir, "repair-candidate.wl"
];
If[artifactPath === $Failed,
  writeFailure["ERROR", "OUTPUT_ERROR", "Cannot write the repair-candidate artifact"]
];
resultPath = CanonMethodCard`WriteProviderResult[
  task, outputDir, "PROVISIONAL", "CANDIDATE_TRANSFORMATION",
  <|
    "repair_candidate" -> <|
      "type" -> "mathematica-expression",
      "path" -> FileNameTake[artifactPath]
    |>
  |>,
  <|
    "method_id" -> "libra-structured-repair-single-variable",
    "tool" -> "Libra",
    "candidate_count" -> 1,
    "frozen_prefix_dimension" -> request["frozen_prefix"]["dimension"],
    "provider_gate" -> "exact-frozen-prefix-candidate-only",
    "fallback_invoked" -> False
  |>
];
If[resultPath === $Failed, Print["Failed to write result.json"]; Quit[1]];
Quit[0];
