# Epsilon-zero polynomial core candidates

Use this bounded DE proposal for an exact rational core DE, regular at epsilon
zero, with homogeneous polynomial rows after algebraic normalization.
It is independent of the integral family and sector number.

Run `run.wls <input.json> <output-dir>` with step `SEARCH_CORE` and payload
`sector_cut_de`. An optional `declared_alphabet` supplies algebraic generators;
the trace connection supplies determinant normalization and pole prefactors.
`method_options.prime` chooses the reconstruction prime (default 2147483647).

The method solves `dR + R A(0) = 0` in a homogeneous polynomial ansatz. It uses
modular equations to propose coefficients and substitutes every reconstructed
row into every original differential direction exactly. Prefactors are drawn
from the trace poles and the declared algebraic generators. This is a finite
ansatz, not a completeness claim.

For a two-dimensional core with only one horizontal row, the method fixes the
determinant of a complementary frame from the trace, integrates its leading
off-diagonal coefficient, and tries the epsilon profile read from the opposite
entry. No topology or regulator polynomial is hard-coded.

The output is `core_candidates` with status `PROVISIONAL`. Run `CHECK_CORE`,
`BUILD_FULL_DE`, `SOLVE_TAIL`, and `CHECK_CANONICAL` before accepting it. A core
candidate has no claimed subsector completion. `METHOD_EXHAUSTED` only exhausts
this ansatz.
