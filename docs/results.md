# Reading results

The current mathematical output is a pair of Wolfram Language Associations:
`canonical-basis.wl` and `canonical-de.wl`. Read these saved files directly in
Mathematica; this does not require an agent host, Kira, or the candidate-generation
packages.

The example directories are:

| Example | Result directory |
| --- | --- |
| One-loop example | [examples/one-loop](../examples/one-loop/) |
| Two-loop five-point example | [examples/2l5p](../examples/2l5p/) |
| Unpublished 40-master example (legacy output format) | [examples/unpublished-40](../examples/unpublished-40/) |

Each example's README records its input, conventions, and the scope of the saved
evidence. Historical results describe the calculation that produced them; they
are not a claim that the current checkout has rerun that calculation.

The one-loop and two-loop five-point examples use the current result pair. The
40-master example preserves its original `final-canonical-system.m` and
`dlog-decomposition.m`; use that example's README to load its legacy fields and
letter registry. The reader and field reference below apply to the current pair.

## Open the files

In a fresh Wolfram session, set `exampleDirectory` to the example you want:

```wl
exampleDirectory = "/absolute/path/to/CANON/examples/one-loop";
basisData = Get[FileNameJoin[{exampleDirectory, "canonical-basis.wl"}]];
deData = Get[FileNameJoin[{exampleDirectory, "canonical-de.wl"}]];

sourceBasis = basisData["source_basis"];
canonicalBasis = basisData["basis"];
transformation = basisData["transformation"];
variables = deData["variables"];
regulator = deData["regulator"];
matrices = deData["matrices"];
letters = deData["alphabet"];
residues = deData["residue_matrices"];

<|"masters" -> Length[canonicalBasis],
  "variables" -> variables,
  "matrix_dimensions" -> (Dimensions /@ matrices),
  "letters" -> Length[letters]|>

First[canonicalBasis]
letters
Lookup[deData, {"check_scope", "checks"}, Missing["NotRecorded"]]
```

This code only loads and displays the saved data. It does not construct or check
differential equations. In Mathematica, `I` is the imaginary unit, so the code
uses `sourceBasis` instead of the mathematical symbol $I$ below.

## Transformation and DE conventions

Let $I$ be the ordered original master vector, $J$ the canonical vector, and
$T$ the saved `transformation`. The direction is

$$
I=TJ,\qquad J=T^{-1}I.
$$

`source_basis` contains $I$; `basis` contains the expressions for $J$. The
transformation includes the accumulated changes of lower sectors and their
normalizations. Rows and columns must retain the order in those vectors.

For `variables = {x1, ..., xn}`, `matrices[[i]]` is $B_i$ in

$$
\partial_{x_i}J=B_iJ,
\qquad
B_i=\epsilon\sum_a R_a\,\partial_{x_i}\log W_a.
$$

Here `regulator` is the actual symbol used for $\epsilon$, `alphabet[[a]]` is $W_a$,
and `residue_matrices[[a]]` is $R_a$. The matrices already contain the regulator
factor. The same constant residue matrix accompanies a letter in every variable
direction. Letters may be exact algebraic expressions, including square roots.

## Current output fields

The current writer is [CheckFullSystem.wls](../mma/CheckFullSystem.wls). It emits
the two files only with `PASS / ALL_PASS`; its `result.json` links them through
`canonical_basis` and `canonical_de` artifact descriptors.

Both files contain `schema`, `family_id`, `basis_id`, and `coefficient_domain`.
The current schemas are `canon-neu/canonical-basis/v1` and
`canon-neu/canonical-de/v1`, with coefficient domain
`exact-algebraic-functions`. The shared `basis_id` identifies the accepted prefix
from which the pair was written.

| File | Fields |
| --- | --- |
| `canonical-basis.wl` | `source_basis`, `basis`, `transformation`, and `convention`; `sector_trace` and `candidate_trace` record the accepted sector order and candidate/method identities |
| `canonical-de.wl` | `variables`, `regulator`, `matrices`, `alphabet`, `residue_matrices`, and `convention`; `check_scope`, `gauge_backend`, and `checks` record the final check's scope, backend, and outcomes |

The final writer retains only letters whose solved residue matrices are nonzero.
The reported alphabet is a representation in the declared letter span; it is not
a uniqueness or minimality claim.

The current final check covers input identity and basis/sector order, completion
of the sector trace, cumulative-transformation invertibility, the exact global
gauge identity, symbolic flatness, regulator factorization, and constant residues
shared across all variables. Its Wolfram backend recomputes the transformed
matrices; its Fermat backend checks the exact gauge identity against the supplied
matrices. Inspect the saved `check_scope`, `gauge_backend`, and example README for
the result you are reading rather than assigning current checks to an older file.

An epsilon-form DE alone does not establish boundary values, branch prescriptions,
uniform weight of a chosen integral normalization, master completeness, or
completeness of the canonical-basis search.
