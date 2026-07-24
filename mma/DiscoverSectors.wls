(*
CANON_neu interface-only template: DISCOVER

Invocation:
  wolframscript -file DiscoverSectors.wls <input.json> <output_dir>

Input envelope:
  schema  = "canon-neu/script-input/v1"
  step    = "DISCOVER"
  sector  = Null
  payload = <|"prepared_family" -> <artifact descriptor>|>

Required output:
  <output_dir>/result.json with schema "canon-neu/script-result/v1".
  PASS code: "SECTORS_READY".
  PASS artifacts: "sector_manifest", "master_basis".
  PASS summary:
    <|"sectors" -> {<|"id" -> integer, "propagator_count" -> integer|>, ...}|>

The script reports sector metadata but does not sort it.
Scientific implementation is intentionally absent.
*)
