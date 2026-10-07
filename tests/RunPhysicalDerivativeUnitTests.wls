#!/usr/bin/env wolframscript
$HistoryLength=0;
{repo, receipt}=Rest[$ScriptCommandLine];
Get[FileNameJoin[{repo,"mma","lib","PhysicalDerivative.wl"}]];
Get[FileNameJoin[{repo,"components","parameterization","Parameterization.wl"}]];
checks=<||>;
check[name_, expression_]:=(checks[name]=TrueQ[expression];Print[name,": ",checks[name]]);
zero[e_]:=And@@(TrueQ[Together[#]===0]&/@Flatten[{e}]);
expandRecord[record_, denominators_]:=record["constant"]+
  Total[(#["coefficient"] denominators[[#["denominator"]]])&/@record["linear"]];

gSpec=Get[FileNameJoin[{repo,"tests","fixtures","physical-derivatives","g3447-spec.wl"}]];
gFamily=CanonParameterization`ParameterizeFamily[gSpec]["family"];
generated=CANON`PhysicalDerivative`PreparePhysicalDerivatives[gFamily];
z=Array[zz,12];
check["g3447_schema_and_order", AssociationQ[generated]&&generated["variables"]==={s,u}&&generated["denominator_count"]===12];
check["g3447_candidate_bridge_protected_slots",generated["exact_strategy"]===<|"propagator_slots"->gFamily["propagator_slots"]|>];
expectedS={0,0,(u-1)(z[[3]]-z[[7]])/(s u),(z[[4]]-z[[12]])/s,0,0,
  (z[[7]]-z[[3]])/(s u),0,0,(z[[10]]-z[[9]])/s,-1+(z[[12]]-z[[4]])/s,0};
expectedU={0,0,(z[[3]]-z[[7]])/u,0,0,0,0,0,0,(z[[9]]-z[[10]])/(1-u),0,0};
check["g3447_all12_s_records",zero[(expandRecord[#,z]&/@generated["operators",s])-expectedS]];
check["g3447_all12_u_records",zero[(expandRecord[#,z]&/@generated["operators",u])-expectedU]];
check["g3447_external_flow_preserves_onshell_and_s",generated["construction","external_flows",s]==={{1/s,0},{0,0}}&&
  generated["construction","external_flows",u]===ConstantArray[0,{2,2}]];
check["old_fixed_projection_s_input_is_rejected_by_identity",!zero[expectedS-{0,0,0,0,0,0,0,0,0,0,-1,0}]];

bubble=<|"loop_momenta"->{q},"external_momenta"->{p},"variables"->{t},
  "scalar_products"->{{p,p}->t},"propagator_momenta"->{q,q-p},"propagator_masses_squared"->{0,0}|>;
b=CANON`PhysicalDerivative`PreparePhysicalDerivatives[bubble];
check["bubble_analytic_chain_rule",zero[(expandRecord[#,Take[z,2]]&/@b["operators",t])-
  {0,1/2+(z[[2]]-z[[1]])/(2t)}]];
mass=CANON`PhysicalDerivative`PreparePhysicalDerivatives[Join[bubble,
  <|"variables"->{t,m2},"propagator_masses_squared"->{m2,0}|>]];
check["squared_mass_sign",zero[(expandRecord[#,Take[z,2]]&/@mass["operators",m2])-{-1,0}]];
coupled=CANON`PhysicalDerivative`PreparePhysicalDerivatives[Join[bubble,
  <|"variables"->{x},"scalar_products"->{{p,p}->x^2},"propagator_momenta"->{q,q-x p}|>]];
check["routing_coefficients_and_gram_both_differentiated",zero[(expandRecord[#,Take[z,2]]&/@coupled["operators",x])-
  {0,2x^3+2(z[[2]]-z[[1]])/x}]];
indexed=CANON`PhysicalDerivative`PreparePhysicalDerivatives[Join[bubble,
  <|"variables"->{x[1]},"scalar_products"->{{p,p}->x[1]^2},"point_rules"->{x[1]->2}|>]];
check["indexed_coordinate_differentiated_before_point",indexed["variables"]==={x[1]}&&
  zero[(expandRecord[#,Take[z,2]]&/@indexed["operators",x[1]])-{0,x[1]+(z[[2]]-z[[1]])/x[1]}]];
noExternal=CANON`PhysicalDerivative`PreparePhysicalDerivatives[<|"loop_momenta"->{q},"external_momenta"->{},
  "variables"->{m2},"propagator_momenta"->{q},"propagator_masses_squared"->{m2}|>];
check["massive_vacuum_derivative",noExternal["operators",m2]==={<|"constant"->-1,"linear"->{}|>}];
nullGram=CANON`PhysicalDerivative`PreparePhysicalDerivatives[Join[bubble,
  <|"variables"->{m2},"scalar_products"->{{p,p}->0},"propagator_masses_squared"->{m2,0}|>]];
check["fixed_null_gram_with_mass_variation",!FailureQ[nullGram]&&
  zero[(expandRecord[#,Take[z,2]]&/@nullGram["operators",m2])-{-1,0}]];
incomplete=CANON`PhysicalDerivative`PreparePhysicalDerivatives[Join[bubble,
  <|"propagator_momenta"->{q-p},"propagator_masses_squared"->{0}|>]];
check["missing_isp_span_fails_closed",FailureQ[incomplete]&&incomplete[[1]]==="DERIVATIVE_OUTSIDE_PROPAGATOR_SPAN"];
inexact=CANON`PhysicalDerivative`PreparePhysicalDerivatives[Join[bubble,<|"scalar_products"->{{p,p}->1.0 t}|>]];
check["inexact_kinematics_rejected",FailureQ[inexact]&&inexact[[1]]==="INEXACT_DERIVATIVE_GEOMETRY"];
nonlinear=CANON`PhysicalDerivative`PreparePhysicalDerivatives[Join[bubble,<|"propagator_momenta"->{q^2,q-p}|>]];
check["nonlinear_routing_rejected",FailureQ[nonlinear]&&nonlinear[[1]]==="NONLINEAR_OR_UNDECLARED_DERIVATIVE_MOMENTUM"];
algebraic=CANON`PhysicalDerivative`PreparePhysicalDerivatives[Join[bubble,<|"scalar_products"->{{p,p}->Sqrt[2] t}|>]];
check["unsupported_algebraic_coefficients_fail_before_v2_output",FailureQ[algebraic]&&algebraic[[1]]==="NONRATIONAL_PHYSICAL_DERIVATIVE"];
regulator=CANON`PhysicalDerivative`PreparePhysicalDerivatives[Join[bubble,<|"dimension"->d,"regulator"->eps,"variables"->{eps}|>]];
check["dimension_and_regulator_derivatives_are_out_of_scope",FailureQ[regulator]&&regulator[[1]]==="KINEMATIC_DERIVATIVES_ONLY"];
Export[receipt,checks,"RawJSON"];
Exit[If[And@@Values[checks],0,1]];
