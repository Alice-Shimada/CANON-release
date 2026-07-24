(*
CANON_neu interface-only template: SOLVE_TAIL

Invocation:
  wolframscript -file SolveTail.wls <input.json> <output_dir>

Input envelope:
  schema  = "canon-neu/script-input/v1"
  step    = "SOLVE_TAIL"
  sector  = <|"id" -> integer, "propagator_count" -> integer|>
  payload = <|
    "full_sector_de" -> <artifact descriptor>,
    "core_transform" -> <artifact descriptor>,
    "accepted_prefix" -> Null or <artifact descriptor>,
    "tail_options" -> <opaque options object>
  |>

Required output:
  <output_dir>/result.json with schema "canon-neu/script-result/v1".
  PASS: code "TAIL_READY", artifact "sector_transform".
  FAIL: code "TAIL_UNSOLVED"; an optional diagnostic artifact may be reported.

Scientific implementation is intentionally absent.
*)
