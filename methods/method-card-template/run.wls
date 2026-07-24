(*
CANON_neu interface-only provider template: SEARCH_CORE / MethodCard route

Invocation:
  wolframscript -file run.wls <input.json> <output_dir>

Input envelope:
  schema  = "canon-neu/script-input/v1"
  step    = "SEARCH_CORE"
  sector  = <|"id" -> integer, "propagator_count" -> integer|>
  payload = <|
    "prepared_family" -> <artifact descriptor>,
    "sector_basis" -> <artifact descriptor>,
    "sector_cut_de" -> <artifact descriptor>,
    "method_options" -> <opaque options object>
  |>

Required output:
  <output_dir>/result.json with schema "canon-neu/script-result/v1".
  PASS: code "CANDIDATE_READY", artifact "core_candidates".
  FAIL: code "NO_CANDIDATE"; method evidence is optional.

Replace this directory to add one bounded MethodCard.
Scientific implementation is intentionally absent.
*)
