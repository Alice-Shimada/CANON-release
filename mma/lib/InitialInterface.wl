(* INITIAL roles describe result scope; they do not select scientific methods. *)
BeginPackage["CanonInitialInterface`"];
CoreContract::usage = "CoreContract[] identifies the active seeded-core provider contract.";
OfficialContract::usage = "OfficialContract[] identifies fixed-reference validation and its compatibility lifecycle.";
Begin["`Private`"];
CoreContract[] := <|
  "role" -> "core-candidate-provider", "lifecycle" -> "active",
  "entry" -> "methods/initial/run.wls", "step" -> "SEARCH_CORE",
  "next_gate" -> "CHECK_CORE", "normalization" -> "explicit-established-seed-premise",
  "reference_equality_required" -> False|>;
OfficialContract[] := <|
  "role" -> "official-reference-validation", "lifecycle" -> "compatibility",
  "core_selection_eligible" -> False, "workflow_action" -> "none",
  "verification_scope" -> "fixed-official-normalized-ladder-reference",
  "reference_equality_required" -> True,
  "preferred_core_entry" -> "methods/initial/run.wls",
  "preferred_core_step" -> "SEARCH_CORE"|>;
End[];
EndPackage[];
