(*
CANON_neu interface-only template: BUILD_FULL_DE
Corresponding agent skill:
  ../skills/canon-build-full-de/SKILL.md

Invocation:
  wolframscript -file BuildFullSectorDE.wls <input.json> <output_dir>

Input envelope:
  schema  = "canon-neu/script-input/v1"
  step    = "BUILD_FULL_DE"
  sector  = <|"id" -> integer, "propagator_count" -> integer|>
  payload = <|
    "prepared_family" -> <artifact descriptor>,
    "master_basis" -> <artifact descriptor>,
    "sector_manifest" -> <artifact descriptor>,
    "core_transform" -> <artifact descriptor>,
    "accepted_prefix" -> Null or <artifact descriptor>
  |>

Required output:
  <output_dir>/result.json with schema "canon-neu/script-result/v1".
  PASS code: "OK".
  PASS artifact: "full_sector_de".

Scientific implementation is intentionally absent.
*)
