(*
CANON_neu interface-only template: COMMIT_SECTOR

Invocation:
  wolframscript -file CommitSector.wls <input.json> <output_dir>

Input envelope:
  schema  = "canon-neu/script-input/v1"
  step    = "COMMIT_SECTOR"
  sector  = <|"id" -> integer, "propagator_count" -> integer|>
  payload = <|
    "previous_accepted_prefix" -> Null or <artifact descriptor>,
    "sector_basis" -> <artifact descriptor>,
    "sector_transform" -> <artifact descriptor>,
    "canonical_sector_de" -> <artifact descriptor>
  |>

Required output:
  <output_dir>/result.json with schema "canon-neu/script-result/v1".
  PASS code: "OK".
  PASS artifact: "accepted_prefix".

Scientific implementation is intentionally absent.
*)
