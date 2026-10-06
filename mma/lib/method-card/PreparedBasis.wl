(* Prepared-basis validation and deterministic routing from checked quality and history.
   Loaded inside CanonMethodCard`Private` by MethodCardCore.wl. *)

preparedFailure[field_String, message_String] :=
  Failure["INVALID_PREPARED_BASIS", <|"Field" -> field, "Message" -> message|>];

nonEmptyStringQ[value_] := StringQ[value] && StringLength[value] > 0;
booleanQ[value_] := TrueQ[value === True || value === False];

(* Each helper owns one contract section. Cross-section consistency is checked last,
   preserving the public validator's deterministic first-failure order. *)
validatePreparedIdentity[value_Association] := Module[{identity, current, prefix},
  identity = Lookup[value, "identity", None];
  If[
    !AssociationQ[identity] ||
      !And @@ (nonEmptyStringQ[Lookup[identity, #, None]] & /@
        {"preparation_id", "family_id", "basis_id"}) ||
      !ListQ[Lookup[identity, "variables", None]] || Lookup[identity, "variables", {}] === {} ||
      !MatchQ[Lookup[identity, "regulator", None], _Symbol],
    Return[preparedFailure["identity", "identity must declare preparation, family, basis, variables, and regulator"]]
  ];

  current = Lookup[value, "current_basis", None];
  If[
    !AssociationQ[current] ||
      Lookup[current, "basis_id", None] =!= identity["basis_id"] ||
      !ListQ[Lookup[current, "basis", None]] || Lookup[current, "basis", {}] === {},
    Return[preparedFailure["current_basis", "current basis must be nonempty and match identity.basis_id"]]
  ];

  prefix = Lookup[value, "frozen_lower_prefix", None];
  If[
    !AssociationQ[prefix] || !booleanQ[Lookup[prefix, "present", None]] ||
      !booleanQ[Lookup[prefix, "accepted", None]] || !ListQ[Lookup[prefix, "basis", None]],
    Return[preparedFailure["frozen_lower_prefix", "frozen prefix shape is invalid"]]
  ];
  If[TrueQ[prefix["present"]],
    If[
      !TrueQ[prefix["accepted"]] || !nonEmptyStringQ[Lookup[prefix, "prefix_id", None]] ||
        prefix["basis"] === {},
      Return[preparedFailure["frozen_lower_prefix", "a present lower prefix must be accepted, identified, and nonempty"]]
    ],
    If[
      prefix["accepted"] =!= False || Lookup[prefix, "prefix_id", None] =!= Null || prefix["basis"] =!= {},
      Return[preparedFailure["frozen_lower_prefix", "an absent lower prefix must have accepted=False, prefix_id=Null, and an empty basis"]]
    ]
  ];

  True
];

validatePreparedCandidates[candidates_] := Module[{candidateIDs, ranks, selected},
  If[!ListQ[candidates] || candidates === {},
    Return[preparedFailure["candidates", "candidate definitions must be a nonempty list"]]
  ];
  If[!And @@ (AssociationQ /@ candidates),
    Return[preparedFailure["candidates", "every candidate must be an Association"]]
  ];
  If[
    !And @@ Table[
      nonEmptyStringQ[Lookup[candidate, "candidate_id", None]] &&
        AssociationQ[Lookup[candidate, "definition", None]] && Lookup[candidate, "definition", <||>] =!= <||> &&
        nonEmptyStringQ[Lookup[candidate, "normalization", None]] &&
        IntegerQ[Lookup[candidate, "rank", None]] && Lookup[candidate, "rank", 0] > 0 &&
        booleanQ[Lookup[candidate, "selected", None]] && booleanQ[Lookup[candidate, "suspicious", None]],
      {candidate, candidates}
    ],
    Return[preparedFailure["candidates", "each candidate needs a definition, normalization, positive rank, selected flag, and suspicious flag"]]
  ];
  candidateIDs = Lookup[candidates, "candidate_id"];
  ranks = Lookup[candidates, "rank"];
  If[DuplicateFreeQ[candidateIDs] =!= True,
    Return[preparedFailure["candidates.candidate_id", "candidate IDs must be unique"]]
  ];
  If[Sort[ranks] =!= Range[Length[candidates]],
    Return[preparedFailure["candidates.rank", "candidate ranks must be a unique contiguous ordering starting at one"]]
  ];
  selected = Select[candidates, TrueQ[Lookup[#, "selected", False]] &];
  If[Length[selected] =!= 1,
    Return[preparedFailure["candidates.selected", "exactly one current candidate must be selected"]]
  ];

  First[selected]
];

validatePreparedQuality[quality_] := Module[{defect},
  defect = If[AssociationQ[quality], Lookup[quality, "localized_defect", None], None];
  If[
    !AssociationQ[quality] ||
      !MemberQ[{"CANONICAL", "DEFECT", "UNKNOWN"}, Lookup[quality, "diagonal", None]] ||
      !MemberQ[{"CANONICAL", "DEFECT", "UNKNOWN"}, Lookup[quality, "off_diagonal", None]] ||
      !AssociationQ[defect] || !booleanQ[Lookup[defect, "present", None]] ||
      !AssociationQ[Lookup[defect, "signature", None]],
    Return[preparedFailure["quality", "quality must declare diagonal, off-diagonal, and localized-defect data"]]
  ];
  If[TrueQ[defect["present"]],
    If[!nonEmptyStringQ[Lookup[defect, "block", None]] || defect["signature"] === <||>,
      Return[preparedFailure["quality.localized_defect", "a present localized defect needs a block and nonempty signature"]]
    ],
    If[Lookup[defect, "block", None] =!= Null || defect["signature"] =!= <||>,
      Return[preparedFailure["quality.localized_defect", "an absent localized defect must have block=Null and an empty signature"]]
    ]
  ];

  True
];

validatePreparedEvidence[evidence_, candidateIDs_List] := Module[{},
  If[
    !ListQ[evidence] ||
      !And @@ Table[
        AssociationQ[reference] && nonEmptyStringQ[Lookup[reference, "reference_id", None]] &&
          nonEmptyStringQ[Lookup[reference, "provider", None]] &&
          MemberQ[candidateIDs, Lookup[reference, "candidate_id", None]] &&
          nonEmptyStringQ[Lookup[reference, "verification_status", None]],
        {reference, evidence}
      ],
    Return[preparedFailure["ut_evidence_references", "UT evidence references must identify a provider, candidate, and verification status"]]
  ];
  If[DuplicateFreeQ[Lookup[evidence, "reference_id", {}]] =!= True,
    Return[preparedFailure["ut_evidence_references.reference_id", "UT evidence reference IDs must be unique"]]
  ];

  True
];

validatePreparedHistory[history_, candidateIDs_List] := Module[{attempted, unattempted},
  If[
    !AssociationQ[history] || !booleanQ[Lookup[history, "plateau", None]] ||
      !booleanQ[Lookup[history, "pool_exhausted", None]] ||
      !IntegerQ[Lookup[history, "alternatives_remaining", None]] || history["alternatives_remaining"] < 0 ||
      !ListQ[Lookup[history, "attempted_candidate_ids", None]],
    Return[preparedFailure["search_history", "search history must declare plateau, pool exhaustion, alternatives, and attempted IDs"]]
  ];
  attempted = history["attempted_candidate_ids"];
  If[
    DuplicateFreeQ[attempted] =!= True ||
      !SubsetQ[candidateIDs, attempted],
    Return[preparedFailure["search_history.attempted_candidate_ids", "attempted IDs must be unique declared candidates"]]
  ];
  unattempted = Complement[candidateIDs, attempted];
  If[history["alternatives_remaining"] =!= Length[unattempted],
    Return[preparedFailure["search_history.alternatives_remaining", "alternatives_remaining must equal the number of declared unattempted candidates"]]
  ];
  If[TrueQ[history["pool_exhausted"]] && history["alternatives_remaining"] =!= 0,
    Return[preparedFailure["search_history", "pool_exhausted=True contradicts alternatives_remaining"]]
  ];

  True
];

validatePreparedConsistency[
  quality_Association, selected_Association, history_Association, remaining_
] := Module[{defect = quality["localized_defect"], classification, canonicalQ},
  classification = If[AssociationQ[remaining], Lookup[remaining, "classification", None], None];
  If[
    !AssociationQ[remaining] ||
      !MemberQ[
        {"NONE", "SUSPICIOUS_CANDIDATE", "LOCALIZED_RATIONAL_DEFECT", "GLOBAL_RATIONAL_DEFECT", "UNKNOWN_OR_NONRATIONAL"},
        classification
      ] ||
      !booleanQ[Lookup[remaining, "candidate_selection_complete", None]] ||
      !booleanQ[Lookup[remaining, "rational_transformation_expected", None]],
    Return[preparedFailure["remaining_problem", "remaining problem classification is invalid"]]
  ];
  If[TrueQ[remaining["candidate_selection_complete"]] && history["alternatives_remaining"] =!= 0,
    Return[preparedFailure["remaining_problem.candidate_selection_complete", "completed candidate selection contradicts remaining alternatives"]]
  ];

  If[
    TrueQ[selected["suspicious"]] &&
      !MemberQ[{"SUSPICIOUS_CANDIDATE", "LOCALIZED_RATIONAL_DEFECT"}, classification],
    Return[preparedFailure["candidates.selected", "selected candidate suspicion contradicts the remaining-problem classification"]]
  ];
  If[classification === "SUSPICIOUS_CANDIDATE" && !TrueQ[selected["suspicious"]],
    Return[preparedFailure["remaining_problem.classification", "suspicious-candidate classification requires the selected candidate to be marked suspicious"]]
  ];

  canonicalQ = quality["diagonal"] === "CANONICAL" && quality["off_diagonal"] === "CANONICAL";
  If[canonicalQ &&
      (TrueQ[selected["suspicious"]] || TrueQ[defect["present"]] ||
        classification =!= "NONE" || TrueQ[remaining["rational_transformation_expected"]]),
    Return[preparedFailure["quality", "canonical quality contradicts selected-candidate suspicion, a remaining defect, or an expected transformation"]]
  ];
  If[classification === "NONE" && !canonicalQ,
    Return[preparedFailure["remaining_problem.classification", "classification NONE requires canonical diagonal and off-diagonal quality"]]
  ];
  If[classification === "LOCALIZED_RATIONAL_DEFECT" && !TrueQ[defect["present"]],
    Return[preparedFailure["quality.localized_defect", "localized classification requires localized defect data"]]
  ];
  If[TrueQ[defect["present"]] &&
      !MemberQ[{quality["diagonal"], quality["off_diagonal"]}, "DEFECT"],
    Return[preparedFailure["quality.localized_defect", "localized defect data requires a DEFECT quality dimension"]]
  ];
  If[classification === "LOCALIZED_RATIONAL_DEFECT" &&
      !TrueQ[remaining["rational_transformation_expected"]],
    Return[preparedFailure["remaining_problem.rational_transformation_expected", "localized rational defect requires an expected rational transformation"]]
  ];
  If[TrueQ[defect["present"]] && MemberQ[{"NONE", "GLOBAL_RATIONAL_DEFECT"}, classification],
    Return[preparedFailure["remaining_problem.classification", "localized defect data contradicts the remaining-problem classification"]]
  ];
  If[classification === "GLOBAL_RATIONAL_DEFECT" &&
      (TrueQ[defect["present"]] || !TrueQ[remaining["rational_transformation_expected"]]),
    Return[preparedFailure["remaining_problem", "global rational defect requires no localized defect and an expected rational transformation"]]
  ];
  True
];

ValidatePreparedBasis[value_] := Module[{check, selected, candidateIDs},
  If[!AssociationQ[value], Return[preparedFailure["$", "artifact must be an Association"]]];
  If[Lookup[value, "schema", None] =!= "canon-neu/prepared-basis/v1",
    Return[preparedFailure["schema", "unexpected prepared-basis schema"]]
  ];
  check = validatePreparedIdentity[value];
  If[FailureQ[check], Return[check]];
  selected = validatePreparedCandidates[Lookup[value, "candidates", None]];
  If[FailureQ[selected], Return[selected]];
  candidateIDs = Lookup[value["candidates"], "candidate_id"];
  check = validatePreparedQuality[Lookup[value, "quality", None]];
  If[FailureQ[check], Return[check]];
  check = validatePreparedEvidence[Lookup[value, "ut_evidence_references", None], candidateIDs];
  If[FailureQ[check], Return[check]];
  check = validatePreparedHistory[Lookup[value, "search_history", None], candidateIDs];
  If[FailureQ[check], Return[check]];
  check = validatePreparedConsistency[value["quality"], selected, value["search_history"],
    Lookup[value, "remaining_problem", None]];
  If[FailureQ[check], Return[check]];
  value
];

PreparedBasisRoute[prepared_Association] := Module[
  {
    validated, identity, candidates, selected, quality, defect, history, remaining,
    canonicalQ, suspiciousQ, alternativesQ, localizedQ, decision, reason
  },
  validated = ValidatePreparedBasis[prepared];
  If[FailureQ[validated], Return[validated]];
  identity = prepared["identity"];
  candidates = prepared["candidates"];
  selected = First @ Select[candidates, TrueQ[Lookup[#, "selected", False]] &];
  quality = prepared["quality"];
  defect = quality["localized_defect"];
  history = prepared["search_history"];
  remaining = prepared["remaining_problem"];
  canonicalQ = quality["diagonal"] === "CANONICAL" && quality["off_diagonal"] === "CANONICAL";
  suspiciousQ = TrueQ[selected["suspicious"]] || remaining["classification"] === "SUSPICIOUS_CANDIDATE";
  alternativesQ = history["alternatives_remaining"] > 0 && !TrueQ[history["pool_exhausted"]];
  localizedQ = TrueQ[defect["present"]] || remaining["classification"] === "LOCALIZED_RATIONAL_DEFECT";
  {decision, reason} = Which[
    canonicalQ,
      {"VERIFY_CANONICAL_DE", "ALREADY_CANONICAL"},
    suspiciousQ && alternativesQ,
      {"REFINE_SECTOR_UT_CANDIDATES", "ALTERNATIVES_REMAIN"},
    localizedQ && quality["diagonal"] === "CANONICAL" &&
      defect["block"] === "lower-to-current",
      {"SOLVE_TAIL", "NONZERO_SUBSECTOR_COUPLING"},
    TrueQ[remaining["rational_transformation_expected"]],
      {"FIND_RATIONAL_CANONICAL_WITH_CANONICA", "GLOBAL_RATIONAL_DEFECT"},
    True,
      {"DIAGNOSE_OR_CHANGE_VARIABLES", "NO_BOUNDED_PROVIDER_ROUTE"}
  ];
  <|
    "schema" -> "canon-neu/route-decision/v1",
    "preparation_id" -> identity["preparation_id"],
    "family_id" -> identity["family_id"],
    "basis_id" -> identity["basis_id"],
    "selected_candidate_id" -> selected["candidate_id"],
    "decision" -> decision,
    "reason" -> reason,
    "ut_evidence_controls_route" -> False,
    "ut_evidence_reference_count" -> Length[prepared["ut_evidence_references"]]
  |>
];
