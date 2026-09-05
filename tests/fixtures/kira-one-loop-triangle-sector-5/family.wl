<|
  "Family" -> DlogBasis`CreateDlogFamily[
    "Name" -> "MasslessOneLoopTriangle",
    "LoopMomenta" -> {CANON`DEData`k},
    "ExternalMomenta" -> {CANON`DEData`p1, CANON`DEData`p2},
    "Propagators" -> {
      CANON`DEData`k^2,
      (CANON`DEData`k - CANON`DEData`p1)^2,
      (CANON`DEData`k - CANON`DEData`p1 - CANON`DEData`p2)^2
    },
    "KinematicVariables" -> {CANON`DEData`s},
    "KinematicRules" -> {
      CANON`DEData`p1^2 -> 0,
      CANON`DEData`p2^2 -> 0,
      CANON`DEData`p1 CANON`DEData`p2 -> CANON`DEData`s/2
    }
  ]
|>
