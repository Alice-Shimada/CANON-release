(*
CANON_neu interface-only template: FINAL_CHECK

Invocation:
  wolframscript -file CheckFullSystem.wls <input.json> <output_dir>

Input envelope:
  schema  = "canon-neu/script-input/v1"
  step    = "FINAL_CHECK"
  sector  = Null
  payload = <|
    "prepared_family" -> <artifact descriptor>,
    "master_basis" -> <artifact descriptor>,
    "sector_manifest" -> <artifact descriptor>,
    "accepted_prefix" -> <artifact descriptor>
  |>

Required output:
  <output_dir>/result.json with schema "canon-neu/script-result/v1".
  PASS code: "ALL_PASS".
  PASS artifacts: "canonical_basis", "canonical_de".

Scientific implementation is intentionally absent.
*)
