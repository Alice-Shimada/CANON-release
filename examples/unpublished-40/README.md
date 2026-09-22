# Unpublished three-loop family: 40 masters

This user-supplied family has **40 masters in 28 sectors**, with physical variables
`{s,u}`, `u` dimensionless, and `d = 4 - 2 eps`. The top Kira sector is 3513.
Its eight physical slots are `{1,4,5,6,8,9,11,12}` in the original twelve-index
order; the other four slots are auxiliary quadratic coordinates.

The original calculation completed in the earlier resident CANON workflow using
DlogBasisNext-first proposals, exact reductions, and full-prefix repair. The
release keeps that provenance and the original export schema. DlogBasisNext is
not a newly introduced dependency of the current workflow.

## Input and result

- [family.yaml](family.yaml): literal inverse propagators, kinematics, index order,
  measure, dimension, and backend-to-physical map `s = sh`, `u = uh/sh`.
- [algebra.yaml](algebra.yaml): original rational coefficient-domain contract.
- [final-canonical-system.m](final-canonical-system.m): complete basis, raw-master
  order, transformation, connection, and original final report.
- [dlog-decomposition.m](dlog-decomposition.m): the three constant residue matrices.
- [accepted-prefix-checkpoint-final.m](accepted-prefix-checkpoint-final.m): original
  accepted checkpoint, retained as evidence; the reader does not load a session.

The YAML files describe the historical family. They are not inputs to the current
`PrepareFamily.wls`; use the [current typed template](../../interfaces/family-spec.example.wl)
when preparing a new calculation.

The exported equation is

```text
dF = eps [-3 IdentityMatrix[40] dlog(s)
          + R_u dlog(u) + R_(1-u) dlog(1-u)] F.
```

Here `dlog(1-u) = du/(u-1)`. The alphabet is `{s,u,1-u}`.

## Read the saved result

The original symbols are in the export's own `SymbolRegistry`. The following
snippet only reads the files and renames symbols; it performs no scientific check.
Use a fresh Wolfram session with the checkout as the working directory:

```wl
saved = Get["examples/unpublished-40/final-canonical-system.m"];
dlog = Get["examples/unpublished-40/dlog-decomposition.m"];
registry = saved["SymbolRegistry"];
names = {"eps", "d", "sh", "uh", "s", "u", "threeLoopParametric3513"};
rename = Thread[Lookup[registry, names] -> {eps, d, sh, uh, s, u, G}];
physical = {sh -> s, uh -> s u};
rawMasters = saved["MasterExpressions"] /. rename;
canonicalIntegrals = saved["CanonicalBasis"] /. rename /. physical;
R = saved["BasisTransformation"] /. rename /. physical;
matrices = saved["CanonicalConnection"]["Matrices"] /. rename /. physical;
residues = dlog["ResidueMatrices"];
```

**This legacy transformation uses `F = R . M`**, where `M = rawMasters`.
It is the reverse direction of the current export's `I = T . J` convention.
The connection keys `"s"` and `"u"` already label physical derivative directions;
the replacement of backend symbols does not require a second Jacobian transform.

## Original evidence

[FINAL-RESULT.md](FINAL-RESULT.md) records `ALL_SECTORS_ACCEPTED`, final
`UT_PREFIX_PASS` with claim class `DLOG`, zero failures, and certification of all
1600 positions. [DLOG-DECOMPOSITION.md](DLOG-DECOMPOSITION.md) describes the saved
constant residues and independent flatness evidence. That later dlog check
certifies the exported matrices; it does not recompute the gauge identity from
the historical raw connection. No stronger claim is added here.

The reports contain references to detailed scratch certificates and candidate
files in the original run. Those are historical references, not dependencies of
this reader. The seven included files are listed in
[source-record.json](source-record.json), with their original bytes and hashes.
No Wolfram computation, reduction, or scientific check was repeated when packaging
this unpublished example.
