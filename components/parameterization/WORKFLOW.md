# Choose the chart separately from the backend

1. Read [README.md](README.md) and prepare the declared symbolic chart and
   optional exact point. Keep routing, masses, integral notation and variable
   order explicit.
2. Run this package's `PREPARE` with the selected manifest. It generates physical
   affine derivatives from the symbolic geometry before point substitution.
   Pass the neutral output to the separately selected discovery/reduction adapter.
3. Bind the returned `prepared_derivatives` explicitly in target preparation,
   candidate bridges and `BUILD_CUT_DE`. For an existing family, invoke
   `PREPARE_DERIVATIVES`; agents do not write derivative records. A selected
   point-DE provider follows its own preparation and acceptance scope. Candidate
   bridges using these affine records set
   `payload.derivative_operator_selection` to `"prepared-affine"`.
4. Preserve the exact input identities and per-step component selections in
   downstream calls. The selected mathematical checker determines acceptance.

An existing accepted result does not need replay merely because these component
choices are now independent.
