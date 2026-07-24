# DlogBasis candidate route

## Purpose

Produce one `SEARCH_CORE` result through the DlogBasis/4D leading-singularity route.

## Required interaction

The assigned agent reads the task `input.json`, invokes this directory's
`run.wls`, and returns its `result.json`. The input and output are exactly the
`SEARCH_CORE` contract in `../../INTERFACES.md`.

## Boundary

This card does not own workflow state, sector ordering, acceptance, retries, or
other providers. Scientific procedure and implementation are intentionally not
specified yet.
