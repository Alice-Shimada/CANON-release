(* Exact one-variable rational off-diagonal Fuchsification.
   Exact bounded helper for SOLVE_TAIL. GPL-3.0-or-later.
   No CANONICA implementation is copied. *)
BeginPackage["CanonRationalTailPoleRepair`"];
Repair::usage = "Repair[A,x,eps,lower,options] removes rational fixed finite higher poles and polynomial infinity tails by a complete lower shear. It returns exact evidence, never canonical acceptance.";
PoleEvidence::usage = "PoleEvidence[m,x,eps] returns exact reduced-denominator finite-pole and polynomial-at-infinity witnesses or a scoped Failure.";
Begin["`Private`"];
Clear[Repair, PoleEvidence];
zeroQ[z_] := TrueQ[Together[z] === 0];
zeroMatrixQ[z_] := AllTrue[Flatten[Normal[z]], zeroQ];
qqQ[z_] := IntegerQ[z] || Head[z] === Rational;
ratQ[z_, symbols_List] := Module[{v=Together[z], n, d},
 If[!FreeQ[v, _Real | Indeterminate | ComplexInfinity | _DirectedInfinity], Return[False]];
 n=Numerator[v];d=Denominator[v];
 PolynomialQ[n,symbols] && PolynomialQ[d,symbols] &&
 AllTrue[Join[Last /@ CoefficientRules[n,symbols], Last /@ CoefficientRules[d,symbols]],qqQ]
];
failure[code_, details_:<||>] := Failure[code, Join[<|"scope"->"exact rational one-variable fixed-rational-pole lower shear; inconclusive outside declared scope"|>,details]];
factorData[den_, x_, eps_] := Module[{fl, out={}, f, power, degree, root},
 fl=Quiet[Check[FactorList[den],$Failed]];
 If[!ListQ[fl],Return[failure["DENOMINATOR_FACTORIZATION_FAILED"]]];
 Catch[Do[f=pair[[1]];power=pair[[2]];degree=Exponent[f,x];
  If[degree===0,Continue[]];
  If[degree=!=1,Throw[failure["UNSUPPORTED_POLE_FACTOR",<|"factor"->f,"multiplicity"->power|>],"factors"]];
  root=Together[-Coefficient[f,x,0]/Coefficient[f,x,1]];
  If[!qqQ[root] || !FreeQ[root,eps],Throw[failure["UNSUPPORTED_MOVING_OR_NONRATIONAL_POLE",<|"factor"->f,"root"->root|>],"factors"]];
  AppendTo[out,<|"factor"->x-root,"root"->root,"order"->power|>],{pair,fl}];out,"factors"]
];
entryEvidence[v_, pos_, x_, eps_, factors_] := Module[{finite={}, poly={}, n,den,d,leading},
 n=Numerator[v];den=Denominator[v];
 Catch[Do[
  leading=Together[(x-pole["root"])^pole["order"] v] /. x->pole["root"];
  leading=Together[leading];
  If[!ratQ[leading,{eps}] || zeroQ[leading],Throw[failure["INVALID_REDUCED_POLE_WITNESS",<|"entry"->pos,"pole"->pole|>],"entry"]];
  AppendTo[finite,Join[pole,<|"entry"->pos,"leading_coefficient"->leading|>]],{pole,factors}];
 d=Exponent[n,x]-Exponent[den,x];
 If[IntegerQ[d] && d>=0,
  leading=Together[Coefficient[n,x,Exponent[n,x]]/Coefficient[den,x,Exponent[den,x]]];
  AppendTo[poly,<|"entry"->pos,"polynomial_degree"->d,"leading_coefficient"->leading|>]];
 <|"finite"->finite,"polynomial"->poly|>,"entry"]
];
PoleEvidence[m_, x_Symbol, eps_Symbol] := Module[
 {a=Normal[m], finite={},poly={},den,factors,w,v,cache=<||>,cacheKey,rows,cols},
 If[!MatrixQ[a],Return[failure["INVALID_MATRIX"]]];
 {rows,cols}=Dimensions[a];
 Catch[Do[v=Together[a[[i,j]]];If[zeroQ[v],Continue[]];
  If[!ratQ[v,{x,eps}],Throw[failure["UNSUPPORTED_COEFFICIENT_DOMAIN",<|"entry"->{i,j},"expression"->v|>],"evidence"]];
  den=Denominator[v]; cacheKey=ToString[den,InputForm];
  If[KeyExistsQ[cache,cacheKey],factors=cache[cacheKey],factors=factorData[den,x,eps];AssociateTo[cache,cacheKey->factors]];
  If[FailureQ[factors],Throw[factors,"evidence"]];
  w=entryEvidence[v,{i,j},x,eps,factors];If[FailureQ[w],Throw[w,"evidence"]];
  finite=Join[finite,w["finite"]];poly=Join[poly,w["polynomial"]],{i,rows},{j,cols}];
 <|"schema"->"canon-neu/rational-pole-evidence/v1","finite_poles"->finite,
   "higher_poles"->Select[finite,#["order"]>1 &],"polynomial_at_infinity"->poly,
   "fuchsian"->(AllTrue[finite,#["order"]===1 &] && poly==={})|>,"evidence"]
];
residueMatrix[m_,x_,a_] := Map[Function[z,Together[Together[(x-a) z] /. x->a]],m,{2}];
infinityMatrix[m_,x_] := Map[Function[z,Module[{v=Together[z],n,d,deg},
 If[zeroQ[v],0,n=Numerator[v];d=Denominator[v];deg=Exponent[n,x]-Exponent[d,x];
 If[deg===-1,Together[Coefficient[n,x,Exponent[n,x]]/Coefficient[d,x,Exponent[d,x]]],0]]]],m,{2}];
leadingMatrix[r_, evidence_List, key_, wanted_, m_,l_] := Module[{c=ConstantArray[0,{m,l}]},
 Do[If[w[key]===wanted,c[[Sequence@@w["entry"]]]=w["leading_coefficient"]],{w,evidence}];c
];
sylvester[p_,q_,constant_,sign_,rhs_,eps_,bound_] := Module[{m=Length[q],l=Length[p],op,sol,v},
 If[(m l)^2>bound,Return[failure["SYLVESTER_ENTRY_BOUND",<|"entries"->(m l)^2,"bound"->bound|>]]];
 op=constant IdentityMatrix[m l,SparseArray] + sign eps
   (KroneckerProduct[SparseArray[q],IdentityMatrix[l,SparseArray]]-
    KroneckerProduct[IdentityMatrix[m,SparseArray],SparseArray[Transpose[p]]]);
 sol=Quiet[Check[LinearSolve[op,Flatten[rhs]],$Failed]];
 If[!VectorQ[sol] || Length[sol]=!=m l,Return[failure["EXACT_SYLVESTER_SOLVE_FAILED"]]];
 v=Map[Together,Partition[sol,l],{2}];
 If[!AllTrue[Flatten[v],ratQ[#,{eps}] &] ||
   !zeroMatrixQ[constant v + sign eps (q.v-v.p)-rhs],Return[failure["SYLVESTER_EXACT_CHECK_FAILED"]]];
 v
];
Repair[a0_,x_Symbol,eps_Symbol,lower_Integer, options_Association:<||>] := Module[
 {a=Normal[a0],n,m,p,q,r,u,s,b,lp,cp,te,before,after,roots,root,order,w,c,v,du,
  steps={},maxSteps,maxEntries,maxDimension,result,started=AbsoluteTime[],wholeResidual},
 If[Complement[Keys[options],{"max_steps","max_operator_entries","max_dimension"}]=!={},Return[failure["UNKNOWN_OPTIONS"]]];
 {maxSteps,maxEntries,maxDimension}=Lookup[Join[<|"max_steps"->64,"max_operator_entries"->2000000,"max_dimension"->128|>,options],{"max_steps","max_operator_entries","max_dimension"}];
 If[!AllTrue[{maxSteps,maxEntries,maxDimension},IntegerQ[#] && #>0 &],Return[failure["INVALID_BOUNDS"]]];
 If[x===eps,Return[failure["VARIABLE_REGULATOR_COLLISION"]]];
 If[!MatrixQ[a] || a==={} || Length[Dimensions[a]]=!=2 || Dimensions[a]=!={Length[a],Length[a]},Return[failure["INVALID_MATRIX"]]];
 n=Length[a];m=n-lower;
 If[n>maxDimension || lower<0 || m<1,Return[failure["DIMENSION_BOUND"]]];
 If[!AllTrue[Flatten[a],ratQ[#,{x,eps}] &],Return[failure["UNSUPPORTED_COEFFICIENT_DOMAIN"]]];
 If[lower===0,Return[failure["NO_LOWER_TAIL_OUT_OF_SCOPE"]]];
 If[!zeroMatrixQ[a[[1;;lower,lower+1;;n]]],Return[failure["NONZERO_UPPER_RIGHT"]]];
 p=Map[Together,a[[1;;lower,1;;lower]]/eps,{2}];q=Map[Together,a[[lower+1;;n,lower+1;;n]]/eps,{2}];
 If[!FreeQ[{p,q},eps],Return[failure["DIAGONAL_NOT_EPSILON_FACTORIZED"]]];
 lp=PoleEvidence[p,x,eps];cp=PoleEvidence[q,x,eps];
 If[FailureQ[lp] || FailureQ[cp],Return[failure["UNSUPPORTED_DIAGONAL",<|"lower"->lp,"current"->cp|>]]];
 If[!TrueQ[lp["fuchsian"]] || !TrueQ[cp["fuchsian"]],Return[failure["NONFUCHSIAN_DIAGONAL",<|"lower"->lp,"current"->cp|>]]];
 r=Map[Together,a[[lower+1;;n,1;;lower]],{2}];u=ConstantArray[0,{m,lower}];
 before=PoleEvidence[r,x,eps];
 If[FailureQ[before],Return[before]];
 te=before;
 result=Catch[
  While[te["higher_poles"]=!={},
   If[Length[steps]>=maxSteps,Throw[failure["STEP_BOUND",<|"steps"->steps,"remaining"->te|>],"repair"]];
   root=First[te["higher_poles"]]["root"];
   w=Select[te["finite_poles"],#["root"]===root &];order=Max[Lookup[w,"order"]];
   c=leadingMatrix[r,Select[w,#["order"]===order &],"order",order,m,lower];
   v=sylvester[residueMatrix[p,x,root],residueMatrix[q,x,root],order-1,1,-c,eps,maxEntries];
   If[FailureQ[v],Throw[v,"repair"]];du=v/(x-root)^(order-1);
   r=Map[Together,r+eps q.du-eps du.p-D[du,x],{2}];u=Map[Together,u+du,{2}];
   AppendTo[steps,<|"kind"->"finite","root"->root,"order_removed"->order,"leading_coefficient"->c,"sylvester_solution"->v|>];
   te=PoleEvidence[r,x,eps];If[FailureQ[te],Throw[te,"repair"]];
   If[AnyTrue[te["finite_poles"],#["root"]===root && #["order"]>=order &],Throw[failure["FINITE_POLE_NOT_REDUCED"],"repair"]]
  ];
  While[te["polynomial_at_infinity"]=!={},
   If[Length[steps]>=maxSteps,Throw[failure["STEP_BOUND",<|"steps"->steps,"remaining"->te|>],"repair"]];
   order=Max[Lookup[te["polynomial_at_infinity"],"polynomial_degree"]];
   c=leadingMatrix[r,te["polynomial_at_infinity"],"polynomial_degree",order,m,lower];
   v=sylvester[infinityMatrix[p,x],infinityMatrix[q,x],order+1,-1,c,eps,maxEntries];
   If[FailureQ[v],Throw[v,"repair"]];du=v x^(order+1);
   r=Map[Together,r+eps q.du-eps du.p-D[du,x],{2}];u=Map[Together,u+du,{2}];
   AppendTo[steps,<|"kind"->"infinity","polynomial_degree_removed"->order,"leading_coefficient"->c,"sylvester_solution"->v|>];
   te=PoleEvidence[r,x,eps];If[FailureQ[te],Throw[te,"repair"]];
   If[te["higher_poles"]=!={} || AnyTrue[te["polynomial_at_infinity"],#["polynomial_degree"]>=order &],Throw[failure["INFINITY_DEGREE_NOT_REDUCED"],"repair"]]
  ];True,"repair"];
 If[FailureQ[result],Return[result]];
 s=IdentityMatrix[n];s[[lower+1;;n,1;;lower]]=u;
 b=a;b[[lower+1;;n,1;;lower]]=r;
 (* Exact full-system gauge differential identity avoids an unnecessary dense
    inverse. The constructed unit block shear has inverse S(-U), determinant1. *)
 wholeResidual=Normal[SparseArray[a].SparseArray[s]-SparseArray[D[s,x]]-SparseArray[s].SparseArray[b]];
 If[!zeroMatrixQ[wholeResidual] || !TrueQ[te["fuchsian"]],Return[failure["FULL_GAUGE_OR_POLE_CHECK_FAILED"]]];
 <|"schema"->"canon-neu/rational-tail-pole-repair/v1","success"->True,
  "convention"->"old=S.new; B=S^-1 A S-S^-1 S'",
  "transformation"->s,"matrices"->b,"steps"->steps,"before"->before,"after"->te,
  "checks"-><|"full_gauge_differential_identity"->True,"lower_and_current_unchanged"->True,"unit_shear_determinant"->1,"removed_claimed_poles"->True|>,
  "bounds"-><|"max_steps"->maxSteps,"max_operator_entries"->maxEntries,"max_dimension"->maxDimension|>,
  "elapsed_seconds"->AbsoluteTime[]-started|>
];
End[];
EndPackage[];
