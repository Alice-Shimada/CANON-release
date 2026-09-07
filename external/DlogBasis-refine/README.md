# DlogBasis-refine

This package is a minimal modular implementation of the scientific core used to propose
canonical-basis candidates from loop-by-loop (LBL) Baikov representations.
Its Wolfram Language context and public loader remain ``DlogBasis``` and
`DlogBasis.wl`.

The implementation is split into six Wolfram Language modules:

- `FamilyAndCandidates.wl`: explicit family objects and the complete bounded
  exact-sector lattice, including numerator powers and propagator dots;
- `LBLBaikov.wl`: a supplied-order LBL Baikov chart whose base dimensions are
  bound to named loop momenta and automatically continued to `D0-2 epsilon`;
- `ResidueSignature.wl`: FiniteFlow graphs for ordered-cut and finite-divisor
  Laurent rows, certified-square multivariate recursion, and aligned
  univariate algebraic higher-pole and finite-root rows;
- `ImplicitAlgebraicResidue.wl`: opt-in experimental quotient-algebra
  principal parts and finite divisor pairs on one implicit algebraic cover;
- `SingularModule.wl`: normal forms and module lift over the rational function
  field `Q(kinematics, epsilon)`, with terminal residues restricted to rational
  constants;
- `Interface.wl`: the single `DlogBasisSearch` dataflow.

Load the package with

```wl
Get["/path/to/DlogBasis-refine/DlogBasis.wl"]
```

and construct a family without defining package state in `Global``:

```wl
family = CreateDlogFamily[
  "LoopMomenta" -> {k1, k2},
  "ExternalMomenta" -> {p1, p2, p3, p4},
  "Propagators" -> propagators,
  "KinematicVariables" -> {s12, s23, s34, s45, s51},
  "KinematicRules" -> scalarProductRules
];

result = DlogBasisSearch[
  family,
  {1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0},
  "LoopSpecifications" -> {
    <|"Momentum" -> k1, "BaseDimension" -> 2|>,
    <|"Momentum" -> k2, "BaseDimension" -> 6|>
  },
  "NumeratorDegreeBound" -> 2,
  "DotDegreeBound" -> 1,
  "FiniteFlowPackageFile" -> "/path/to/FiniteFlow.m"
];
```

The experimental residual backend leaves a variable-dependent quadratic cover
as one generator satisfying its polynomial relation.  For two remaining
variables it scans every supported finite simple-divisor pair, factors the
variable part of the cover square class in the terminal quotient algebra, and
only then splits the purely kinematic sheets.  Dotted finite pairs and pairs
without a coordinate divisor remain outside this experimental backend.  The
default residual backend is unchanged.

```wl
DlogBasisSearch[
  family, sector,
  "ResidualBackend" -> "ImplicitAlgebraicExperimental"
]
```

`BaseDimension` denotes the integer reference dimension `D0`, not the final
integration dimension.  For a common `D0`, the chart constructs the physical
variable-dependent measure at `D = D0 - 2 epsilon`, with
``DlogBasis`DimensionalRegulator`` as `epsilon`.  Mixed base dimensions instead
give the formal proposal `D_i = D0_i - 2 epsilon` and are not identified with
one common-dimensional Feynman family.  `KinematicMeasure` and every
mapped `BaikovForm` contain the common regulator weight, while
`BaseKinematicMeasure`, `BaseBaikovForm`, and `RegulatorRatio` expose the exact
factorization

```text
K(D0 - 2 epsilon) = K(D0) RegulatorRatio^epsilon.
```

Dimension-only angular and Gamma-function normalization is common within one
chart and remains omitted; the package does not claim an absolute epsilon
normalization from the reduced Baikov form alone.

## Scientific scope

The ordered propagator cut is evaluated on the dimensionally regulated form
`RegulatorRatio^epsilon phi`.  At each variable in the stated cut order it
factors `RegulatorRatio = z^nu R0 U`, with `U=1` at that one divisor, expands
`U^epsilon`, takes the local residue, and propagates every coefficient form to
the next variable.  This sequential construction remains valid when `U` has
poles in later cut variables.  For each candidate it retains the first nonzero
epsilon order; earlier higher-pole coefficients are not imposed as zero rows.
All successfully cut candidates are then sent together to the existing
finite-divisor engine, so module lift may cancel poles with algebraic
prefactors.  No Mathematica `Series` backend is used.

This first-nonzero prescription is a candidate-generation convention, not an
exact-dlog or UT certificate.  Unresolved generalized cuts are recorded under
`CandidateResidualFailures`; their search-space exclusions are kept separate
from the mathematical `HigherPoleRows`, and `CandidateResidualCompleteQ` is
false.  Exactly vanishing cuts are listed separately under
`CutNullCandidatePositions` and do not make the coverage incomplete.  Higher
poles of the remaining ISP differential forms are still strict module
constraints.
The coefficient field for module lift remains `Q(kinematics, epsilon)`; the old
integer-`D0` search is not used by `DlogBasisSearch`.
If a cut record has nonzero `TwistValuation`, its factor
`x^(valuation epsilon)` remains in the multivalued twist.  The reported row is
the coefficient in that local twisted-cocycle trivialization, not an ordinary
contour residue at the branch point; branch transitions remain unchecked.

The remaining finite-pole engine certifies rational meromorphic LBL forms whose
finite divisors are recursively linear with a leading coefficient in the kinematic
field. It extracts every negative Laurent coefficient, so a dotted candidate
with zero residue still contributes its higher-pole obstruction. A simple
residue on a positive-dimensional cut is retained as a child differential form;
only a closed zero-dimensional flag enters the constant-residue target.

After an ordered maximal cut, exact square-factor identities reduce finite
linear and quadratic divisor residues.  Independent square classes over the
base kinematic field generate one finite multiquadratic basis (including
`Sqrt[-1]` for exact complex constants); all field components are expanded into
one rational block system for Singular.  FiniteFlow computes a local Laurent
principal part only when these square classes are independent of the expansion
variable.  Candidate rows without one common algebraic cut factor, and quadratic
towers whose radicands already contain exact complex coefficients, remain
unresolved.  A
positive-dimensional algebraic cut that becomes rational after certified
square reduction uses the rational divisor tree recursively, retaining every
dotted higher-pole row.  The regulated candidate backend keeps the surviving
first-nonzero cuts in one aligned algebraic system.
Infinity, branch
transitions, and chart transitions are marked as unchecked. A multivariate
algebraic cover with a genuine variable-dependent square class, higher-degree
finite divisor, ramified ordered cut, or root that still depends on the final
integration variable remains unresolved.
Mixed loop dimensions are labelled
`MixedDimensionProposal`; they are not silently identified with a
common-dimensional Feynman family.

For a positive numerator bound, `DlogBasisSearch` scans the reduced chart and
each missing numerator position in a separate LBL chart, returning the chart
with the most candidate combinations.  This deliberately leaves multivariate
algebraic charts unresolved and is reported as `SingletonNumeratorCharts` under
`CandidateGenerationMode`.  `NumeratorPositions` selects one explicit chart
instead.  `NumeratorChartScan` retains the candidate combinations and parities
from every scanned chart.  The selected chart coverage is reported by
`CandidateChartCompleteQ`; an unrepresented atom is not silently counted as a
failed constant-LS candidate.

Candidate combinations are returned under `CandidateCombinations`; the
regulated residue data are under `LeadingSingularitySignature`, together with
`CandidateResidualCompleteQ`. `AffineFiniteConstantResiduesVerifiedQ` can be
true only when that coverage and the affine divisor atlas are complete. The global
`ConstantLeadingSingularityCertifiedQ` remains false because infinity and a
projective atlas are not checked. The result is not by itself a proof of
uniform transcendentality or of a canonical differential-equation basis.

## Tests

```bash
wolframscript -file Tests/RunTests.wls /path/to/FiniteFlow.m
```

The suite includes exact LBL-chart tests for the massless 2l5p pentabox and the
collaborator's 3l5p PBP top sectors, dot cancellation, positive-dimensional
residue flags, Series-free FiniteFlow reconstruction, Singular module lift, and
a complete two-dimensional rational end-to-end example. For the massless 2l5p top sector
with `D0=4`, the reduced reverse LBL chart is tested end-to-end to return one even
and one odd constant-LS candidate from the scalar and represented ISP
numerator. Three single-pinched sectors are also tested with exact constant-LS
residuals; unsupported multivariate covers remain explicitly unresolved.

The reproducible 46-sector scan of the planar massless 2l5p family is in
`Studies/ScanMassless2L5PSectors.wls`; its compact machine-readable result and
interpretive report are `Studies/Massless2L5PSectorScanResults.wl` and
`Studies/Massless2L5PSectorScan.md`.
The corresponding family loader and literature sector manifest are under
`Resources/Pentabox2L5P`.
Agent-facing usage instructions are in `skills/dlogbasis-refine/SKILL.md`.

The original DlogBasis algorithm is described in
[arXiv:2002.09492](https://arxiv.org/abs/2002.09492). The generalized LBL
Baikov setting follows [arXiv:2202.08127](https://arxiv.org/abs/2202.08127), and
the finite-field graph backend follows
[arXiv:1905.08019](https://arxiv.org/abs/1905.08019).
