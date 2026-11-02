# Streaming FullForm regression fixtures

These public fixtures test coefficient-at-a-time FullForm export and FINAL
preparation timings. They preserve the supported coefficient domain, native
arithmetic, strict result parser and all fourteen FINAL acceptance gates.

Use `components.json` after the complete caller-selected component sequence.
Supply `WORK/test-config.json`, `runtime.json`, `runtime-frozen.json`,
`fixture-bank.json` and `accepted-fixture-bindings.json` with the installed
kernel/helper/native/converter paths and hashes, component order, CPU/thread/RSS
limits and execution budgets. Rebuild runtime source guards for the installation;
do not retain guards from a prior staging directory. The fixture bank references
accepted inputs and expected results in place.

`PREPARE_STREAM_FIXTURE` creates the fixed synthetic matrix through `run_step.py`.
Then `prepare_cases.py --work WORK` binds the selected accepted cases, and
`test_streaming.py --work WORK` runs their public preparation, normalization,
construction and FINAL calls. The test component also exposes
`VERIFY_FAST_SERIALIZER` for independent result checks. No installed binary or
unchanged dependency source is distributed here.

The writer uses UTF-8 and a fixed symbol context, formatting one coefficient at
a time. Formatting storage depends on the largest coefficient and the frame;
the input matrix remains resident. Write failures stop before conversion or
arithmetic. The tests check silent and message-producing write failures, failed
close cleanup, abort, and normal output-stream lifetime. Test injection saves
and restores primitive definitions and records the full before/after stream
lists. It is never enabled in production.

The recorded audit passed 26 cases and 405 checks. Both tiny FINAL systems passed
all fourteen gates; bad gauge and bad basis cases failed their distinct gates.
An initial test injection error and a sampler exception were retained, corrected,
and repeated only where they affected evidence. Their original closure metadata
and unavailable resource totals are not treated as valid results.

A single 16 by 8 synthetic comparison produced identical 54,516,360-byte postfix
input and 512-byte nonzero native output. Old/new public wall times were
155.784/155.818 seconds. Sampled whole-process-group RSS was
3,657,269,248/732,385,280 bytes; export-associated RSS was
3,657,269,248/664,391,680 bytes. The 20 ms samples include resident inputs and
measure inclusive process RSS, not isolated export allocation. These are
engineering measurements, not a physical-family speedup or a FINAL completion
claim. Large temporary inputs and dumps are not distributed.
