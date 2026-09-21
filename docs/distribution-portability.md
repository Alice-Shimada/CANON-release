# Distribution portability checks (2026-09-07)

The scope covers CANON source, interface examples, tests, the README, skills,
worker prompts, and external source stored separately by package. Research state
and run outputs were not included in the distribution.

## Files and interfaces

After scanning the original 179 Git files individually, two obsolete LS archives
were removed. The remaining 177 files were checked for path and machine
assumptions across runtime entry points, interfaces, tests, documentation, and
configuration. Changes focused on these areas:

- `MethodCardCore.wl` consistently resolves relative paths from the declaring
  file. PREPARE resources are relative to the family spec; project, output, and
  explicit executable paths for IBP and the candidate bridge are relative to the
  request JSON.
- INITIAL's entry, FiniteFlow files and native library, and reference directory
  are declared separately through parameters. Thread count is configurable and
  defaults to 1. Fixed requirements for macOS ARM64, Mathematica 14, and personal
  tool directories were removed.
- DlogBasis resolves FiniteFlow/Singular paths from the request. Its version comes
  from the caller's declaration and is `null` when omitted; the entry SHA-256 is
  computed from the actual file. The outer repository HEAD is no longer read.
- Test fixtures use synthetic tool files within the repository and actual runtime
  information. The README, skills, worker prompts, and interface examples explain
  consistent path configuration. Historical result documents retain their original
  dates, versions, hashes, and conclusions.

The fixed ladder diagram, seeds, alphabet, and reference identity within the
mathematical scope remain part of the method-card definition, not installation
configuration. Nonexistent paths, Windows path examples, and the generic
`/usr/bin/env` shebang in tests also retain their respective purposes.

## External source

Eight programs contain 11,147 original repository files totaling 120,344,872 bytes;
source commits and tree IDs are in [external/sources.json](../external/sources.json).
File-by-file comparison with the source commits found only the two DlogBasis-refine
portability changes listed in the manifest. There are no nested `.git` directories,
locally compiled outputs, or additional foundation libraries. Examples, images,
test inputs, and embedded source supplied by the original repositories are preserved.

Other personal-path matches in the external-source scan belong to historical
notebook output, documentation/generator comments, example data, and Singular's
old openmath/python development demo scripts and example Makefiles. These upstream
files retain their original committed contents; running old demos separately still
requires configuring their own paths. Platform help settings and Applications
paths under `$UserBaseDirectory` are native upstream configuration. These files
are not sources for CANON installation paths. Fermat source was not obtained;
acquisition instructions are listed separately in
[Fermat/README.md](../external/Fermat/README.md).

## Validation results

| Check | Result and scope |
| --- | --- |
| State management, Codex adapter, and prompt contracts | 44 passed in 7.622 seconds; only temporary test directories were modified |
| INITIAL, structural-repair checker, package resolution, and candidate interfaces | 12 focused tests ultimately passed; after fixing an outdated candidate example, only the failed test was rerun |
| Actual DlogBasis-refine provider | Sector 148/182 regressions and parameter-rejection branches ran in a directory containing spaces and no `.git`; 1 passed in 23.120 seconds; the existing local FiniteFlow native library was reused |
| PREPARE/DISCOVER portability | 2 passed; JSON, spec, and Kira project were in separate directories containing spaces, with a different calling working directory |
| Kira adapter portability | 1 passed; relative project/output paths, with a stub reducer checking ordered masters and rules |
| DlogBasis source loading | `RelocationSmoke.wls` passed, with two expected candidates and no new Global symbols |
| Candidate IBP bridge path propagation | A stub reducer checked relative executable/project/output paths and a result file in another directory |

These are regression checks of installation configuration, path propagation, and
existing interfaces. They did not perform fresh builds of all eight external
programs on a new machine or rerun actual INITIAL `TCalc`. Native Windows persistent
research remains unsupported. Absolute runtime paths in existing research artifacts
are not automatically rewritten when the source moves.
