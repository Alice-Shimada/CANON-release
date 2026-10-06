# Kira phase selection

1. Obtain `reducer_family` from the chosen parameterization producer. Keep native
   executable/options/jobs in a separate backend JSON file.
2. Select this package's `DISCOVER` when Kira should initiate masters. A passing
   discovery returns the standard source basis and sector manifest.
3. Supply the full neutral target list and ordered source masters for
   `REDUCE_IBP`. Bind exact numeric points consistently. Discovery alone supplies
   no reduction rules. Default to FireFly: automatic jobs use
   `reduction_engine: "firefly"` (also the omitted-field default), with
   `run_initiate: true` and `run_firefly: true`. Caller-supplied jobs must select
   that route themselves. Choose symbolic Fermat only explicitly with
   `reduction_engine: "fermat"`; do not silently fall back after a failure.
   Set `--parallel=N` from the assigned IBP budget.
4. Select the backend for each later phase independently. This Kira package can
   reduce the target list, while another selected package may instead provide
   `REDUCE_IBP` or a direct `BUILD_CUT_DE`.
5. On `IBP_REDUCED`, pass the normalized rules, retained source order and exact
   kinematic binding into the selected scientific consumer. For a different
   native master basis, supply an explicit conversion before continuing.
6. Treat process exits, cancellation and missing exports according to the result
   code. Neither a launch nor an initiation-only job completes reduction. Keep
   the usual scientific checkers and coordinator acceptance boundary.

The adapter never updates research state and has no parameterization entry.
