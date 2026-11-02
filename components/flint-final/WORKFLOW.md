# Exact FLINT final check

Preserve the caller's complete ordered component selection and append this
component to select its `FINAL_CHECK` provider. Read `--describe` and the entry
instructions before invocation. Prepare the request through `PREPARE_REQUEST`,
binding the original complete ordered master DE and the accepted complete
prefix. Set `method_options.gauge_backend` to `flint` and provide the installed
native executable and its source/helper bindings as described in `README.md`.
The separate basis check can also select `basis_backend: "flint"`.

Run the public `FINAL_CHECK` and retain its receipt, canonical basis and DE,
runtime identities and resource measurements. All fourteen acceptance gates
remain required. A matching `PASS/ALL_PASS` ends scientific work for that scope:
register, submit, review, accept and deliver. Do not replay accepted preceding
sectors solely to switch the final arithmetic backend.

The focused engineering regression is documented in
`../../tests/construction-arithmetic/FINAL-FLINT.md`. Its small fixtures establish
the implementation's checked behavior; they do not establish a physical-family
result.
