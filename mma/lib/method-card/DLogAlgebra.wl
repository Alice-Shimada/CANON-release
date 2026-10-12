(* Algebraic letters, shared constant residues, and exact primitives.
   Loaded inside CanonMethodCard`Private` by MethodCardCore.wl. *)

DLogAlphabet[matrices_List, variables_List, regulator_Symbol] := DeleteDuplicates @ Select[
  Flatten[(First /@ Rest[FactorList[Denominator[Together[#/regulator]]]]) & /@
    Flatten[matrices]],
  FreeQ[#, regulator] && !FreeQ[#, Alternatives @@ variables] &];

QuadraticRootLetters[matrices_List, variables_List] := Module[
  {bases, squareRoot, candidates = {}, a, c, numerators},
  squareRoot[value_] := Module[{factors = FactorList[Together[value]]},
    If[And @@ (EvenQ[Last[#]] & /@ Rest[factors]),
      Sqrt[factors[[1, 1]]] Times @@ (First[#]^(Last[#]/2) & /@ Rest[factors]),
      $Failed]];
  bases = DeleteDuplicates @ Cases[matrices,
    Power[b_, p_Rational] /; Denominator[p] === 2 :> Factor[b], Infinity];
  Do[
    If[PolynomialQ[base, variables] && Exponent[base, x] === 2,
      a = squareRoot[Coefficient[base, x, 2]];
      If[a =!= $Failed,
        c = squareRoot[Coefficient[base, x, 0]];
        numerators = If[c === $Failed, {D[base, x]/(2 a)},
          Expand /@ {a x - c, a x + c}];
        candidates = Join[candidates,
          ((# + Sqrt[base])/(# - Sqrt[base]) &) /@ numerators]
      ]
    ], {base, bases}, {x, variables}];
  DeleteDuplicates[candidates]
];

DLogResidues[matrices_List, variables_List, regulator_Symbol, alphabet_List] :=
  If[FreeQ[alphabet, regulator] && EpsilonFactorizedQ[matrices, regulator],
    constantDLogResidues[Map[Together[#/regulator] &, matrices, {3}], variables, alphabet, {}],
    $Failed];

DLogFormResidues[matrices_List, variables_List, regulator_Symbol, alphabet_List] :=
  If[FreeQ[alphabet, regulator],
    constantDLogResidues[matrices, variables, alphabet, {regulator}], $Failed];

constantDLogResidues[matrices_List, variables_List, alphabet_List, coefficientSymbols_List] := Catch[Module[
  {powers, bases, orders, roots, relations, formal, numerator, fieldPowers,
   fieldBasis, fieldVector, points, point, pointCount, letterValues,
   logarithmicDerivatives, connectionEntries, connectionValues, logVectors,
   entryVectors, sampled, sampledEntries, coefficientMatrix,
   pivotPositions, rows, columns, inverse, entry, entryResidues},
  If[alphabet === {}, Return[If[And @@ (ZeroMatrixQ /@ matrices), {}, $Failed]]];
  powers = DeleteDuplicates @ Cases[{matrices, alphabet},
    Power[b_, p_Rational] /; !FreeQ[b, Alternatives @@ variables] :>
      {Factor[b], Denominator[p]}, Infinity];
  bases = DeleteDuplicates[First /@ powers];
  orders = (LCM @@ Cases[powers, {#, n_} :> n]) & /@ bases;
  roots = Table[Unique["root$"], {Length[bases]}];
  formal[expr_] := expr /. Power[b_, p_Rational] /;
      MemberQ[bases, Factor[b]] :> With[
        {i = First @ FirstPosition[bases, Factor[b]]}, roots[[i]]^(p orders[[i]])];
  relations = MapThread[#1^#2 - formal[#3] &, {roots, orders, bases}];
  numerator[expr_] := With[{n = Numerator[Together[expr]]},
    If[roots === {}, n, Numerator[Together[Last @ PolynomialReduce[n, relations, roots]]]]];
  fieldPowers = Tuples[Range[0, # - 1] & /@ orders];
  fieldBasis = Times @@ MapThread[Power, {roots, #}] & /@ fieldPowers;
  fieldVector[expr_, point_] := Quiet[Check[Module[{q, rel, vector, n, d, result},
    q = Together[expr /. point];
    If[!FreeQ[q, Indeterminate | _DirectedInfinity], Return[$Failed]];
    If[roots === {}, Return[{q}]];
    rel = relations /. point;
    vector[poly_] := With[{rules = CoefficientRules[
        Last @ PolynomialReduce[poly, rel, roots], roots]},
      Replace[fieldPowers, Join[rules, {_List -> 0}], {1}]];
    n = vector[Numerator[q]]; d = Denominator[q];
    result = LinearSolve[Transpose[vector[d #] & /@ fieldBasis], n];
    If[VectorQ[result] && FreeQ[result, Indeterminate | _DirectedInfinity], result, $Failed]
  ], $Failed]];
  logarithmicDerivatives = Quiet[Check[
    Table[formal[Together[D[letter, direction]/letter]],
      {direction, variables}, {letter, alphabet}], $Failed]];
  If[logarithmicDerivatives === $Failed, Return[$Failed]];
  connectionEntries = DeleteDuplicates[Flatten[Table[matrices[[All, row, column]],
    {row, Length[First[matrices]]}, {column, Length[First[matrices]]}], 1]];
  connectionValues = formal[Together[#]] & /@ connectionEntries;
  pointCount = Ceiling[Length[alphabet]/Max[1, Length[variables] - 1]] + 2;
  points = {}; sampled = {}; sampledEntries = {};
  (* Reject divisors and singular field inversions before any matrix algebra.
     Sampling is bounded and only proposes constants, never an identity proof. *)
  Do[
    point = Thread[variables -> Prime[Range[Length[variables]] + k Length[variables]]];
    letterValues = Quiet[Check[alphabet /. point, $Failed]];
    If[letterValues === $Failed || !FreeQ[letterValues, Indeterminate | _DirectedInfinity] ||
        MemberQ[letterValues, 0], Continue[]];
    logVectors = Map[fieldVector[#, point] &, logarithmicDerivatives, {2}];
    entryVectors = Map[fieldVector[#, point] &, connectionValues, {2}];
    If[!FreeQ[{logVectors, entryVectors}, $Failed], Continue[]];
    AppendTo[points, point];
    AppendTo[sampled, Transpose /@ logVectors];
    AppendTo[sampledEntries, entryVectors];
    If[Length[points] === pointCount, Break[]],
    {k, 0, 8 pointCount - 1}];
  If[Length[points] =!= pointCount, Return[$Failed]];
  coefficientMatrix = Flatten[sampled, 2];
  pivotPositions[a_] := (First @ FirstPosition[#, x_ /; x =!= 0, Missing[], {1}, Heads -> False] &) /@
    DeleteCases[RowReduce[a], {0..}];
  rows = pivotPositions[Transpose[coefficientMatrix]];
  columns = pivotPositions[coefficientMatrix];
  If[columns =!= {}, inverse = Inverse[coefficientMatrix[[rows, columns]]]];
  (* Samples fix candidate constants; every original direction is proved below. *)
  entry[entries_] := entry[entries] = Module[{position, values, sampledValues, solution},
    position = First @ FirstPosition[connectionEntries, entries, Missing[], {1}];
    values = connectionValues[[position]];
    sampledValues = Flatten[sampledEntries[[All, position]]];
    solution = ConstantArray[0, Length[alphabet]];
    If[columns =!= {}, solution[[columns]] = inverse.sampledValues[[rows]]];
    If[Complement[Cases[solution, _Symbol, Infinity], coefficientSymbols] =!= {} ||
        !And @@ MapThread[TrueQ[numerator[Together[#1 - solution.#2]] === 0] &,
        {values, logarithmicDerivatives}], Throw[$Failed, constantDLogResidues]];
    solution
  ];
  entryResidues = Table[entry[matrices[[All, row, column]]],
    {row, Length[First[matrices]]}, {column, Length[First[matrices]]}];
  Table[entryResidues[[All, All, i]], {i, Length[alphabet]}]
], constantDLogResidues];

AlgebraicPrimitive[components_List, variables_List] := Catch[Module[
  {parts, classes, radicalPart, terms, prefactor, rational, den, factors, fd,
   degree, monomials, coefficients, ansatz, equations, solutions, solution,
   t, totalDegree, result = 0},
  radicalPart[term_] := Times @@ Cases[term,
    Power[b_, p_Rational] :> Factor[b]^Mod[p, 1], {0, Infinity}];
  terms[expr_] := With[{x = Expand[expr]}, If[Head[x] === Plus, List @@ x, {x}]];
  parts = (GroupBy[terms[#], radicalPart, Total] & /@ components);
  classes = Union @@ (Keys /@ parts);
  totalDegree[poly_] := Exponent[poly /. Thread[variables -> t variables], t];
  Do[
    rational = Together[Lookup[#, root, 0]/root] & /@ parts;
    If[!FreeQ[rational, Power[_, _Rational]], Throw[$Failed, AlgebraicPrimitive]];
    den = PolynomialLCM @@ (Denominator /@ rational);
    factors = Rest[FactorList[den]];
    prefactor = root/Times @@ (#[[1]]^Max[0, #[[2]] - 1] & /@ factors);
    fd = Together[D[prefactor, #]/prefactor] & /@ variables;
    rational = Together[root rational/prefactor];
    degree = Max[0, Max[(totalDegree[Numerator[#]] -
      totalDegree[Denominator[#]] + 1) & /@ DeleteCases[rational, 0]]];
    monomials = DeleteDuplicates[Times @@@ Tuples[Prepend[variables, 1], degree]];
    coefficients = Array[Unique["primitive$"] &, Length[monomials]];
    ansatz = coefficients.monomials;
    equations = Union @@ Table[Last /@ CoefficientRules[Numerator[Together[
      D[ansatz, variables[[i]]] + fd[[i]] ansatz - rational[[i]]]], variables],
      {i, Length[variables]}];
    solutions = Solve[Thread[equations == 0], coefficients];
    If[solutions === {}, Throw[$Failed, AlgebraicPrimitive]];
    solution = ansatz /. First[solutions] /. Thread[coefficients -> 0];
    result += prefactor solution,
    {root, classes}];
  Together[result]
], AlgebraicPrimitive];

DLogConnectionQ[matrices_List, variables_List, regulator_Symbol, alphabet_List] :=
  DLogResidues[matrices, variables, regulator, alphabet] =!= $Failed;
