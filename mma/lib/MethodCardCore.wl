BeginPackage["CanonMethodCard`"];
IntegralCoefficientRows::usage = "IntegralCoefficientRows[expressions, basis, head] returns exact ordered integral rows by unit-vector substitution, or $Failed for each expression outside the homogeneous linear span.";

SectorBits::usage = "SectorBits[integral, propagatorSlots] returns the full index-order sector mask, with ISP slots set to zero.";
FormatMasterArtifacts::usage = "FormatMasterArtifacts[prepared, masters, sourceHash] groups ordered masters into the standard sector manifest and master basis.";
SectorDEArtifacts::usage = "SectorDEArtifacts[orderedDE, sectorManifest, sectorRecord] slices a validated ordered DE and returns sector_basis, sector_cut_de and resident_positions.";

ReadTask::usage = "ReadTask[path, step] reads and validates a script input envelope.";
ScriptArguments::usage = "ScriptArguments[] returns arguments following the active WL script.";
LoadArtifact::usage = "LoadArtifact[task, inputPath, name] reads one WL Association artifact.";
ParseSymbolRules::usage = "ParseSymbolRules[mapping] decodes declared source/target name pairs in the data context, preserves explicit contexts, and returns rules or $Failed.";
ReadWLData::usage = "ReadWLData[path] reads WL data with unqualified symbols in CANON`DEData` and preserves explicitly qualified symbols.";
ResolveInputPath::usage = "ResolveInputPath[inputFile, path] resolves a path relative to the file that declares it.";
RelativeArtifactPath::usage = "RelativeArtifactPath[declaringFile, target] stores a relocatable reference to target from declaringFile.";
ResolveMethodPackage::usage = "ResolveMethodPackage[task, inputPath, context] resolves a workflow-declared package entry or the standard Wolfram package path.";
WriteWLArtifact::usage = "WriteWLArtifact[expr, outputDir, fileName] writes a new WL artifact.";
WriteResult::usage = "WriteResult[task, outputDir, status, code, artifacts, summary] writes result.json.";
WriteProviderResult::usage = "WriteProviderResult[task, outputDir, status, code, artifacts, summary] writes a provider result that cannot claim PASS or FAIL.";
ValidCutDEQ::usage = "ValidCutDEQ[expr, allowAlgebraic:False] checks the exact cut-DE contract. Rational providers retain the default; the independent checker can also accept a declared algebraic cut.";
SameSectorQ::usage = "SameSectorQ[sectors] compares sector records by keys and values, independently of association key order.";
SameSectorTraceQ::usage = "SameSectorTraceQ[left, right] preserves sector sequence order while ignoring record key order.";
ValidSectorBasisQ::usage = "ValidSectorBasisQ[expr] checks the sector-basis artifact shape.";
ValidCandidatesQ::usage = "ValidCandidatesQ[expr] checks the core-candidates artifact shape.";
ValidatePreparedBasis::usage = "ValidatePreparedBasis[expr] validates canon-neu/prepared-basis/v1 and returns the input or a deterministic Failure.";
PreparedBasisRoute::usage = "PreparedBasisRoute[prepared] returns a deterministic canon-neu/route-decision/v1 artifact for a valid prepared basis.";
CheckCoreCandidate::usage = "CheckCoreCandidate[candidate, matrices, variables, regulator, index] independently checks one exact core candidate.";
GaugeTransform::usage = "GaugeTransform[matrices, variables, T] applies old=T.new exactly.";
FermatGaugeIdentityQ::usage = "FermatGaugeIdentityQ[matrices, variables, T, target] proves A.T-D[T]-T.target=0 in the binomial algebraic extension using a loaded Fermatica backend.";
ZeroMatrixQ::usage = "ZeroMatrixQ[matrix] tests exact entrywise vanishing.";
FlatConnectionQ::usage = "FlatConnectionQ[matrices, variables] tests the exact symbolic curvature in every pair of variables.";
EpsilonFactorizedQ::usage = "EpsilonFactorizedQ[matrices, eps] tests exact epsilon factorization.";
DLogResidues::usage = "DLogResidues[matrices, variables, eps, alphabet] solves shared constant residues using exact Wolfram algebraic expressions.";
DLogAlphabet::usage = "DLogAlphabet[matrices, variables, eps] extracts regulator-free pole factors as candidate letters.";
QuadraticRootLetters::usage = "QuadraticRootLetters[matrices, variables] proposes norm-ratio letters for quadratic roots with rational square leading coefficients.";
AlgebraicPrimitive::usage = "AlgebraicPrimitive[components, variables] solves a polynomial-over-poles primitive in the algebraic components of an exact one-form.";
DLogConnectionQ::usage = "DLogConnectionQ[matrices, variables, eps, alphabet] tests the exact shared-residue dlog form across all directions.";
ExactRationalExpressionQ::usage = "ExactRationalExpressionQ[expr] accepts only finite exact rational functions.";
ExactAlgebraicExpressionQ::usage = "ExactAlgebraicExpressionQ[expr] accepts exact sums, products and rational powers of non-System symbols; no machine numbers or transcendental functions.";
ValidMatrixSystemQ::usage = "ValidMatrixSystemQ[matrices, variables, regulator, dimension] checks an exact algebraic matrix list and its independent differentiation coordinates at an external boundary.";
ValidateStructuredRepairInput::usage = "ValidateStructuredRepairInput[prepared, route, request] validates the frozen-prefix Libra repair contract.";
DeclaredCoefficientDomainQ::usage = "DeclaredCoefficientDomainQ[expr, symbols] checks exact rational syntax and rejects undeclared coefficient symbols.";
StructuredRepairPublicationGate::usage = "StructuredRepairPublicationGate[request, candidate] applies only the provider's minimal structural publication gate.";

Begin["`Private`"];

(* Fragments share the existing public/private contexts; keep their load order explicit. *)
With[{directory = FileNameJoin[{DirectoryName[$InputFileName], "method-card"}]},
  Get[FileNameJoin[{directory, "ArtifactIO.wl"}]];
  Get[FileNameJoin[{directory, "Contracts.wl"}]];
  Get[FileNameJoin[{directory, "PreparedBasis.wl"}]];
  Get[FileNameJoin[{directory, "IntegralBasis.wl"}]];
  Get[FileNameJoin[{directory, "Sectors.wl"}]];
  Get[FileNameJoin[{directory, "GaugeChecks.wl"}]];
  Get[FileNameJoin[{directory, "DLogAlgebra.wl"}]];
  Get[FileNameJoin[{directory, "StructuredRepair.wl"}]];
];

End[];
EndPackage[];
