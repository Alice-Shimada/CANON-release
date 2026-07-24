(*
CANON_neu interface-only template: PREPARE

Invocation:
  wolframscript -file PrepareFamily.wls <input.json> <output_dir>

Input envelope:
  schema  = "canon-neu/script-input/v1"
  step    = "PREPARE"
  sector  = Null
  payload = <|"family_spec" -> <artifact descriptor>|>

Required output:
  <output_dir>/result.json with schema "canon-neu/script-result/v1".
  PASS code: "OK".
  PASS artifact: "prepared_family" -> <path to an opaque prepared-family file>.

Scientific implementation is intentionally absent.
*)
