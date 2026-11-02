# Exact zero-block assembly

The default BUILD_FULL_DE may use a block assembly when every raw lower-to-current coefficient is literal integer zero and the validated, projected candidate rows have literal integer zero lower coefficients. Machine zero is not an exact-zero witness. Nonzero blocks and candidates use the existing general gauge route; invalid row shape or nonexact coefficients retain the public input rejection.

For `old=T.new`, with accepted lower transformation L and current row map Q, this case has `T0=diag(L,I)` and `U=diag(I,Q)`. The exact current-to-lower block is `Q Araw_current,lower L`. Combining and normalizing the small current rows before applying L can reduce intermediate expression growth. The current diagonal block is `(D[Q,x]+Q Araw_current,current) Inverse[Q]`.

The full-prefix artifact keeps the same schema, basis identities, source order and mixed-source matrices. Exact source matrices need not be in Together-normal form. They remain available to independent scientific checks; capability fixtures and a bounded diagnostic timing do not certify a family canonical result.

The public regression `tests/test_full_block_assembly.py --canon ROOT --work OUT --components ...` exercises variable-dependent and quadratic-root Q, epsilon-meromorphic inverses, nonzero upper/lower blocks, no lower prefix, and input rejection. Supply the selected component stack and installed Wolfram runtime through the caller's environment.

## Optional Fermatica arithmetic

Set `payload.method_options.block_backend` to `"fermat"` and provide the installed Fermatica `package_entry`; its path is resolved relative to the declaring request. `FERMATPATH` selects the installed native Fermat executable. The default `"wolfram"` route is unchanged. The initial Fermatica scope is one selected passing core, a lower prefix, literal-zero raw upper blocks and literal-zero projected candidate lower coefficients. Explicitly selecting another scope returns `UNSUPPORTED_FERMAT_BLOCK_SCOPE`.

Exact rational functions and one explicit nonnested quadratic generator are supported. Half-integer powers are represented by a formal root r with r^2 equal to its exact rational base, native products/sums are quotient-reduced with FQuolyMod, then the same square-root expression is restored. No PowerExpand, Abs, floating-point specialization, implicit backend fallback or new alphabet is used. Cubic, nested or multiple independent roots return `UNSUPPORTED_FERMAT_BLOCK_DOMAIN` in this initial implementation.

The backend forms J=Q Araw_tail L natively and publishes the exact compact mixed source C=Q^-1 J. Its current block includes DQ and preserves the old=T.new sign convention. The existing full-prefix schema and all independent scientific gates remain. Actual package/executable hashes and versions are recorded in block_arithmetic. Fermatica scratch files stay inside the output directory; source snippets are read in place. Headless Monitor messages do not erase a valid native matrix; CheckAbort and typed result validation distinguish an aborted operation from a completed return.

`tests/test_fermat_block_arithmetic.py --canon ROOT --work OUT --package-entry ENTRY --components ...` runs known-answer nonzero commuting tails with rational/quadratic arithmetic, exact source/gauge identities, binomial cancellation, scoped rejection and default no-prefix compatibility. Supply the runtime and resource configuration externally. Capability tests or a bounded first-variable profile do not certify a complete family canonical result.

The optional native route publishes `block-arithmetic-trace.jsonl` in the output directory. It records start/end, variable, elapsed seconds and operation seconds for each tail product, source recovery and current block. The public result lists this trace as an operational artifact; it does not change scientific acceptance.
