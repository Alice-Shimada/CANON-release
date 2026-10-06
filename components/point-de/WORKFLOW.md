# Exact point samples

Read [README.md](README.md) for supported geometry and every request field.
Use this package only when the requested scope needs point samples.

1. Obtain the symbolic family, ordered masters and explicit candidate rows from
   the caller's accepted upstream work. Keep the declared variable/basis order.
2. Run `PREPARE_POINT` with an exact point and the final symbolic frame.
3. Configure the selected reducer for that same point and the returned union of
   targets. A discovery/initiate-only job is insufficient; supply reduction and
   export jobs. Retain the declared kinematics binding and preferred masters.
4. Run `BUILD_POINT_DE` on the supplied reduction. Resolve missing targets or
   rank failure before advancing. Record point-scoped epsilon checks separately
   from global canonical acceptance.
5. Repeat only for requested independent points. Run `COLLECT_DE_SAMPLES` with
   disjoint training and validation roles. Pass the resulting relative index to
   the chosen reconstruction component; keep validation points out of fitting.

Preserve the explicitly selected component manifests in every `run_step.py`
invocation. This package does not update research state or launch reductions.
