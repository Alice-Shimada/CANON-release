(* Massless two-loop five-point pentabox: eight denominators and three ISPs. *)

Begin["DlogBasisTests`Massless2L5P`"];

family = DlogBasis`CreateDlogFamily[
  "Name" -> "Massless2L5PPentabox",
  "LoopMomenta" -> {k1, k2},
  "ExternalMomenta" -> {p1, p2, p3, p4},
  "Propagators" -> {
    k1^2,
    (k1 + p1)^2,
    (k1 + p1 + p2)^2,
    (k1 + p1 + p2 + p3)^2,
    k2^2,
    (k2 + p1 + p2 + p3)^2,
    (k2 + p1 + p2 + p3 + p4)^2,
    (k1 - k2)^2,
    (k1 + p1 + p2 + p3 + p4)^2,
    (k2 + p1)^2,
    (k2 + p1 + p2)^2
  },
  "KinematicVariables" -> {s12, s23, s34, s45, s51},
  "KinematicRules" -> {
    p1^2 -> 0, p2^2 -> 0, p3^2 -> 0, p4^2 -> 0,
    p1 p2 -> s12/2,
    p2 p3 -> s23/2,
    p3 p4 -> s34/2,
    p1 p4 -> (s23 - s45 - s51)/2,
    p1 p3 -> (-s12 - s23 + s45)/2,
    p2 p4 -> (-s23 - s34 + s51)/2
  }
];

fixture = <|
  "Family" -> family,
  "Sector" -> Join[ConstantArray[1, 8], ConstantArray[0, 3]],
  "NumeratorPositions" -> {9, 10, 11},
  "Common4DOrder" -> {
    <|"Momentum" -> k1, "BaseDimension" -> 4|>,
    <|"Momentum" -> k2, "BaseDimension" -> 4|>
  },
  "NamedMixedOrder" -> {
    <|"Momentum" -> k1, "BaseDimension" -> 2|>,
    <|"Momentum" -> k2, "BaseDimension" -> 6|>
  },
  "ExpectedCoordinateDeterminant" -> 512,
  "ExpectedExternalCounts" -> {5, 4}
|>;

End[];
DlogBasisTests`Massless2L5P`fixture
