(*
CANON_neu interface-only template: CHECK_CANONICAL
Corresponding agent skill:
  ../skills/canon-check-canonical/SKILL.md

Invocation:
  wolframscript -file CheckCanonical.wls <input.json> <output_dir>

Input envelope:
  schema  = "canon-neu/script-input/v1"
  step    = "CHECK_CANONICAL"
  sector  = <|"id" -> integer, "propagator_count" -> integer|>
  payload = <|
    "full_sector_de" -> <artifact descriptor>,
    "sector_transform" -> <artifact descriptor>,
    "accepted_prefix" -> Null or <artifact descriptor>
  |>

Required output:
  <output_dir>/result.json with schema "canon-neu/script-result/v1".
  PASS: code "CANONICAL_PASS", artifact "canonical_sector_de".
  FAIL: code "CORE_FAIL" or "TAIL_FAIL"; a diagnostic artifact is optional.

The script, not Python, decides whether a failure belongs to core or tail.
Scientific implementation is intentionally absent.
*)
