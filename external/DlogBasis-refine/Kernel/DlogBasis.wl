(* ::Package:: *)

BeginPackage["DlogBasis`"];

CreateDlogFamily::usage =
  "CreateDlogFamily[opts] constructs an explicit, immutable integral-family association.";
EnumerateDlogCandidates::usage =
  "EnumerateDlogCandidates[family, sector, bnum, bdot] enumerates the exact-sector bounded numerator/dot lattice.";
LoopByLoopBaikovChart::usage =
  "LoopByLoopBaikovChart[family, sector, loopSpecifications, numeratorPositions] constructs the supplied loop-by-loop Baikov chart.";
MapDlogCandidates::usage =
  "MapDlogCandidates[chart, candidates] maps every scalar-integral atom into the common D0-2 epsilon Baikov chart.";
DimensionalRegulator::usage =
  "DimensionalRegulator is the inert epsilon in the automatic D=D0-2 epsilon Baikov form.";
FinitePoleSignature::usage =
  "FinitePoleSignature[forms, variables, kinematics] computes all supported finite affine principal parts and terminal flag residues with FiniteFlow.";
AlgebraicMaximalCutSignature::usage =
  "AlgebraicMaximalCutSignature[forms, variables, kinematics, cutVariables] computes aligned higher-pole and finite-root rows after the ordered maximal cut, including certified-square rational multivariate cuts.";
ImplicitDivisorPrincipalPart::usage =
  "ImplicitDivisorPrincipalPart[forms, variable, divisor] computes all principal-part coefficients in the finite algebra defined by divisor == 0 without solving for its roots.";
ImplicitAlgebraicResidueSignature::usage =
  "ImplicitAlgebraicResidueSignature[forms, variables, kinematics] experimentally computes all supported finite simple-divisor-pair residues on one variable-dependent quadratic cover without intermediate root substitution.";
DimensionallyRegulatedMaximalCutSignature::usage =
  "DimensionallyRegulatedMaximalCutSignature[forms, regulatorRatio, variables, kinematics, cutVariables] takes the first nonzero D=D0-2 epsilon generalized cut in the stated variable order and computes its remaining finite residues.";
SingularModuleLift::usage =
  "SingularModuleLift[higherRows, residueRows, kinematics] intersects the candidate signature module with the constant-residue module and lifts the result with Singular.";
DlogBasisSearch::usage =
  "DlogBasisSearch[family, sector, opts] runs candidate enumeration, automatic D0-2 epsilon LBL Baikov mapping, finite-pole signatures, and Singular module lift.";
DlogIntegral::usage =
  "DlogIntegral[familyID, indices] is the inert scalar-integral atom used in returned combinations.";

Begin["`Private`"];

Get[FileNameJoin[{DirectoryName[$InputFileName], "FamilyAndCandidates.wl"}]];
Get[FileNameJoin[{DirectoryName[$InputFileName], "LBLBaikov.wl"}]];
Get[FileNameJoin[{DirectoryName[$InputFileName], "ResidueSignature.wl"}]];
Get[FileNameJoin[{DirectoryName[$InputFileName], "SingularModule.wl"}]];
Get[FileNameJoin[{DirectoryName[$InputFileName], "ImplicitAlgebraicResidue.wl"}]];
Get[FileNameJoin[{DirectoryName[$InputFileName], "Interface.wl"}]];

End[];
EndPackage[];
