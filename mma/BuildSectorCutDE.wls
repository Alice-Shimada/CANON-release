(*
CANON_neu interface-only template: BUILD_CUT_DE
Corresponding agent skill:
  ../skills/canon-build-cut-de/SKILL.md

Invocation:
  wolframscript -file BuildSectorCutDE.wls <input.json> <output_dir>

Input envelope:
  schema  = "canon-neu/script-input/v1"
  step    = "BUILD_CUT_DE"
  sector  = <|"id" -> integer, "propagator_count" -> integer|>
  payload = <|
    "prepared_family" -> <artifact descriptor>,
    "master_basis" -> <artifact descriptor>,
    "sector_manifest" -> <artifact descriptor>
  |>

Required output:
  <output_dir>/result.json with schema "canon-neu/script-result/v1".
  PASS code: "OK".
  PASS artifacts: "sector_basis", "sector_cut_de".

Scientific implementation is intentionally absent.
*)
