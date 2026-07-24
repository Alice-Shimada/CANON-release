(*
CANON_neu interface-only template: CHECK_CORE

Invocation:
  wolframscript -file CheckSectorCore.wls <input.json> <output_dir>

Input envelope:
  schema  = "canon-neu/script-input/v1"
  step    = "CHECK_CORE"
  sector  = <|"id" -> integer, "propagator_count" -> integer|>
  payload = <|
    "sector_basis" -> <artifact descriptor>,
    "sector_cut_de" -> <artifact descriptor>,
    "core_candidates" -> <artifact descriptor>
  |>

Required output:
  <output_dir>/result.json with schema "canon-neu/script-result/v1".
  PASS: code "CORE_PASS", artifact "core_transform".
  FAIL: code "CORE_FAIL"; an optional diagnostic artifact may be reported.

Scientific implementation is intentionally absent.
*)
