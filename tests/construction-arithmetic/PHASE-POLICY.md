# Installing the focused policy regression

Place only the new VerifyPhaseFixtures.wls and test_phase_policy.py under the
existing tests/construction-arithmetic directory. Merge the one additional
VERIFY_PHASE_FIXTURES entry from portable-verifier-component.json into its
relative components manifest. Retain its existing fixture builder, exact legacy
verifier, native exec launcher and block parser sources unchanged.

The new driver takes --work CALLER_DIRECTORY. That directory supplies
test-config.json, cases.json and the bound input template files. All interpreter,
checkout, component, fixture-bank, runtime, native and resource paths are caller
configuration; the driver has no R010 or installation path constants. Templates
declare ordinary artifact path/SHA256 bindings. Use the existing public
PREPARE_FFT_FIXTURES to prepare the same rational/quadratic expected data in the
caller directory when no retained bank is supplied. No expected target changes.

The tested case specification lists ten cases. Rebase its template/runtime paths
to caller-owned data, preserving backend maps, expected outcomes and targets.
After helper integration, select the current-root two-argument BUILD_FULL_DE
already supplied by the installed relative test manifest. Configure a native
wolframscript or compatible host adapter through the caller environment. Auxiliary
verification uses the existing three-argument run.py and current library_root.
Keep the caller's full original component selection.

The workspace frozen provider and physical manifest are separate source-bound
test configuration. They legitimately reference the accepted launcher in place;
their R010 paths are not part of the portable test source. The portable verifier
entry resolves only {package}/run.py and {package}/VerifyPhaseFixtures.wls.
Packaging adds no new mathematical target or execution owner and requires no
replay of the passing ten-case matrix.
