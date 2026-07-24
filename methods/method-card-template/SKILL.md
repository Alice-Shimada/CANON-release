# MethodCard template

## Purpose

Define one bounded alternative for producing a `SEARCH_CORE` candidate.

## Required interaction

The assigned agent reads the task `input.json`, invokes this directory's
`run.wls`, and returns its `result.json`. The input and output are exactly the
`SEARCH_CORE` contract in `../../INTERFACES.md`.

## Boundary

Fill in the scientific method only when this MethodCard is instantiated. Do not
add workflow state, sector scheduling, acceptance, retries, or provider
selection here.
