# Workflow

1. Read README.md and preserve the caller's complete ordered component selection,
   appending this package's manifest.
2. Bind the unchanged ordered DE and its sector manifest through PREPARE_REQUEST.
3. Run SLICE_CUT_DE_BATCH once within the caller's declared allocation.
4. Retain the original input references and each direct index entry. Register
   new cuts/bases/index separately; do not copy historical DEs or workspaces.
5. Feed the relevant standard pair into the existing independent core/full/tail/
   canonical/commit gates. Batch slicing does not accept those later results.
6. If the family data or manifest changes, run a new batch on the changed inputs.
   There is no trusted-cache option or validation bypass.
