# Reading results

## Release examples

The [three article examples](../examples/README.md) contain plain Wolfram
expressions. Reading them requires only Wolfram Language. No agent host, native
reducer or external algebra package is needed.

Use a fresh session, with the checkout as the working directory:

```wl
exampleDirectory = "examples/three-loop";
basis = Get[FileNameJoin[{exampleDirectory, "canonical-basis.wl"}]];
alphabet = Get[FileNameJoin[{exampleDirectory, "alphabet.wl"}]];
Atilde = Get[FileNameJoin[{exampleDirectory, "Atilde.wl"}]];

{Length[basis], Length[alphabet], Dimensions[Atilde]}
(* {40, 3, {40, 40}} *)

(* Replace the letter labels by their exact expressions. *)
letterRules = Table[W[a] -> alphabet[[a]], {a, Length[alphabet]}];
AtildePhysical = Atilde /. letterRules;
First[basis]
alphabet
```

The equation is `d basis = eps d Atilde . basis`. The matrix contains `Log[W[a]]`
with exact rational coefficients and no overall epsilon. Its row and column
indices follow `basis` exactly. `alphabet[[a]]` defines the same letter in every
entry; the files contain no implicit matrix-order conversion.

For example, directional DE matrices can be read from the logarithmic form:

```wl
variables = {s, u}; (* the three-loop example *)
matrices = Table[eps D[AtildePhysical, x], {x, variables}];
```

This differentiates the supplied logarithmic representation; it is not an IBP
calculation or a new global-gauge check. The [example guide](../examples/README.md)
gives the other families' variable orders and integral definitions. Local
branches and additive log constants do not change the differential equation;
the export does not prescribe physical boundary constants.

## Full workflow artifacts

A new successful workflow writes two Associations, `canonical-basis.wl` and
`canonical-de.wl`, containing the cumulative transformation and verification
metadata as well as the mathematical outputs. This is the full artifact format;
the expression-only files in `examples/` deliberately contain fewer objects.

To read a full output pair from a completed calculation:

```wl
basisData = Get[FileNameJoin[{resultDirectory, "canonical-basis.wl"}]];
deData = Get[FileNameJoin[{resultDirectory, "canonical-de.wl"}]];
sourceBasis = basisData["source_basis"];
canonicalBasis = basisData["basis"];
transformation = basisData["transformation"];
variables = deData["variables"];
regulator = deData["regulator"];
matrices = deData["matrices"];
letters = deData["alphabet"];
residues = deData["residue_matrices"];
```

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

The full workflow writer is [CheckFullSystem.wls](../mma/CheckFullSystem.wls). It emits
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
matrices; its Fermat and optional FLINT backends check the exact gauge identity
against the supplied matrices in their documented arithmetic domains. Inspect the saved `check_scope`, `gauge_backend`, and example README for
the result you are reading rather than assigning current checks to an older file.

An epsilon-form DE alone does not establish boundary values, branch prescriptions,
uniform weight of a chosen integral normalization, master completeness, or
completeness of the canonical-basis search.
