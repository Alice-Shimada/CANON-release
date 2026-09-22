# Release preparation

Scope agreed on 2026-09-20: prepare a small research-software release for general
agents and models, reuse successful examples, and keep the existing scientific
implementation. Do not rerun the examples or their scientific checks.

## Deliverables

- A science-first README, minimal installation instructions, a separate Codex
  host guide, and a host-neutral coordinator guide.
- A concrete typed family specification and PREPARE request using existing
  one-loop inputs; clear ownership of missing scientific preparation.
- Saved one-loop, 2l5p, and unpublished 40-master examples with original result
  scope, portable input references, readable outputs, and compact source records.
- MIT licensing for CANON-owned material, alphabetically ordered author metadata,
  contribution instructions, and release notes.
- Documentation and packaging checks only: links, JSON/YAML, selected file
  integrity, and review of changes. No IBP, DE, canonical checker, or benchmark run.

## Implementation boundaries

Use the existing Mathematica interfaces, method cards, and statemng protocol.
Separate generic scientific decisions from host integration. Do not add a new
state machine, compatibility layer, retry engine, provider, or universal family
compiler. Preserve unrelated working-tree changes and research history.

Historical examples describe the software and checks used for their original
results; including them does not certify a fresh run of the release version.
The 40-master example may retain its original export schema and have a short
reader instead of being converted into a new scientific artifact.

## Preparation receipt

The release draft contains the three selected saved examples, the prepared
triangle input, general agent/installation/result guides, a separate Codex guide,
MIT licensing, and the seven-author citation in family-name order. Historical
architecture pages are retained under `docs/history/`.

Static review resolved 128 local documentation links, parsed example JSON/YAML,
checked copied-file hashes, and validated the public skill. The two existing
documentation/skill tests passed. The scientific examples and their checkers were
not run. No new scientific algorithm or runtime safety layer was introduced.

The local Codex launcher was repaired after its checkout check failed. This does
not establish MCP access in the existing session; persistent research resumes
only in a fresh Local session. No research-state operation was used during this
preparation. The source archive is a preview from a working tree, not a tagged
release or a new scientific validation record.
