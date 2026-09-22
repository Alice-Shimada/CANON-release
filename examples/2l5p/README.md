# Massless planar two-loop five-point pentabox

The saved result contains all **61 masters in 46 sectors**, with variables
`{s12,s23,s34,s45,s51}` and `d = 4 - 2 eps`. Its canonical DE has 24 active
letters, including one algebraic square-root generator.

## Input and method

The physical family is specified by the repository's
[Kira propagators](../../tests/fixtures/kira-massless-two-loop-five-point-pentabox/config/integralfamilies.yaml)
and [kinematics](../../tests/fixtures/kira-massless-two-loop-five-point-pentabox/config/kinematics.yaml).
Slots 1–8 are propagators and 9–11 are numerator coordinates. The
[fixture description](../../tests/fixtures/kira-massless-two-loop-five-point-pentabox/README.md)
identifies the published family and the supplied derivative/Kira inputs.
The full five-variable scale is retained in exported rules and DEs.

The 2026-09-05 calculation combined integral/DE proposals, bounded epsilon-zero
core searches, and lower-sector repair, including affine-epsilon primitives and
full-prefix epsilon normalization. It used an explicitly supplied pentagon
alphabet. The result therefore does not demonstrate complete discovery of an
unknown algebraic alphabet.

## Read the saved result

In a fresh Wolfram session, from the checkout root:

```wl
basis = Get["examples/2l5p/canonical-basis.wl"];
de = Get["examples/2l5p/canonical-de.wl"];
masters = basis["source_basis"];
canonicalIntegrals = basis["basis"];
T = basis["transformation"];
letters = de["alphabet"];
residues = de["residue_matrices"];
```

The convention is `I = T . J`, with `I` ordered as `masters` and `J` as
`canonicalIntegrals`. The matrices include epsilon; residues do not. See
[reading results](../../docs/results.md) for the derivative convention.

## Original evidence

[result.json](result.json) records `PASS/ALL_PASS`, 61 masters, 46 sectors, and
24 letters. The original result established full gauge identities, epsilon
separation, resident coverage, and shared constant residues in all five variable
directions. Its **flatness check was at a deterministic exact rational point**;
it is not described here as a new symbolic-flatness pass. A separate original
Mathematica gauge record is included in [historical-evidence](historical-evidence).

The source report is summarized in the dated
[research log](../../docs/research-log.md) and
[scientific audit](../../docs/scientific-audit-20260908.md).
[source-record.json](source-record.json) identifies the original files and run.
The complete basis and DE are preserved without algebraic modification. Historical
Fermat paths inside the DE identify the original backend; reading the result does
not load those programs.

No scientific checks, including the current `FINAL_CHECK`, were rerun during
release preparation. The large raw-DE cache, reduction workspaces, and failed
trial runs are not needed to use these saved mathematical outputs and are not
included in this example.
