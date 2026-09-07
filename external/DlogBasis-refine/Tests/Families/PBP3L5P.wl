(* Collaborator three-loop five-point PBP top sector: 11 denominators, 7 ISPs. *)

Begin["DlogBasisTests`PBP3L5P`"];

family = DlogBasis`CreateDlogFamily[
  "Name" -> "ThreeLoopFivePointPBP",
  "LoopMomenta" -> {l1, l2, l3},
  "ExternalMomenta" -> {k1, k2, k3, k4},
  "Propagators" -> {
    (k1 + k2 - l1)^2,
    (k1 + k2 + k3 - l1)^2,
    (k1 + k2 + k3 - l2)^2,
    l3^2,
    (k1 + k2 + k3 + k4 - l2)^2,
    l2^2,
    (k1 + k2 - l3)^2,
    (l1 - l3)^2,
    (k1 - l3)^2,
    (l1 - l2)^2,
    (l2 - l3)^2,
    l1^2,
    (k1 - l1)^2,
    (k1 + k2 - l2)^2,
    (k1 + k2 + k3 + k4 - l1)^2,
    (k1 - l2)^2,
    (k1 + k2 + k3 - l3)^2,
    (k1 + k2 + k3 + k4 - l3)^2
  },
  "KinematicVariables" -> {s12, s23, s34, s45, s15},
  "KinematicRules" -> {
    k1^2 -> 0, k2^2 -> 0, k3^2 -> 0, k4^2 -> 0,
    k1 k2 -> s12/2,
    k1 k3 -> (-s12 - s23 + s45)/2,
    k1 k4 -> (-s15 + s23 - s45)/2,
    k2 k3 -> s23/2,
    k2 k4 -> (s15 - s23 - s34)/2,
    k3 k4 -> s34/2
  }
];

fixture = <|
  "Family" -> family,
  "Sector" -> Join[ConstantArray[1, 11], ConstantArray[0, 7]],
  "NumeratorPositions" -> Range[12, 18],
  "LoopSpecifications" -> {
    <|"Momentum" -> l1, "BaseDimension" -> 4|>,
    <|"Momentum" -> l2, "BaseDimension" -> 4|>,
    <|"Momentum" -> l3, "BaseDimension" -> 4|>
  },
  "ExpectedAbsCoordinateDeterminant" -> 32768,
  "ExpectedExternalCounts" -> {6, 5, 4},
  "ExpectedNumeratorBound3Count" -> 120
|>;

End[];
DlogBasisTests`PBP3L5P`fixture
