$HistoryLength = 0;
scriptArgs = If[ListQ[$ScriptCommandLine] && Length[$ScriptCommandLine] > 1,
  Rest[$ScriptCommandLine], Drop[$CommandLine, First @ FirstPosition[$CommandLine, "-script"] + 1]];
{repoRoot,inputPath,outputDir} = ExpandFileName /@ scriptArgs;
Get[FileNameJoin[{repoRoot,"mma","lib","MethodCardCore.wl"}]];
task = CanonMethodCard`ReadTask[inputPath,"PREPARE_FFT_FIXTURES"];
{x,y,eps,f} = Symbol /@ {"CANON`DEData`x","CANON`DEData`y","CANON`DEData`eps","CANON`DEData`f"};
variables={x,y}; sector=<|"id"->2,"propagator_count"->1|>;
family="T013-manufactured-arithmetic"; basisID="fixture/current";
normalize[m_] := Map[Together,m,{2}];
put[name_,value_] := (CanonMethodCard`WriteWLArtifact[value,outputDir,name<>".wl"];<|"path"->name<>".wl"|>);
names={};
make[name_,kind_,withPrefix_:True,upper_:False,backend_:"finiteflow"] := Module[
 {q,p,l,t0,u,w,target,raw,source,accepted,basis,cut,pool,core,rows,refs,options,request,expected},
 q=eps^3*Switch[kind,"root",Sqrt[1+x+y],"cubic",x^(1/3),_,1+x];
 p=y/(1+x);l=1+x;
 t0=If[withPrefix,{{l,0},{0,1}},{{1}}];
 u=If[withPrefix,{{1,0},{p,q}},{{q}}];
 w=normalize[t0.Inverse[u]];
 target=If[withPrefix,{eps*{{1/x,If[upper,1/(1+x),0]},{0,2/x}},eps*{{1/y,0},{0,2/y}}},
   {eps*{{2/x}},eps*{{2/y}}}];
 raw=MapThread[normalize[(D[w,#2]+w.#1).Inverse[w]]&,{target,variables}];
 source=MapThread[normalize[Inverse[t0].(#1.t0-D[t0,#2])]&,{raw,variables}];
 basis=If[withPrefix,{f[1],f[2]},{f[2]}];
 accepted=If[withPrefix,<|"schema"->"canon-neu/accepted-prefix/v1","prefix_id"->"fixture/lower",
   "family_id"->family,"source_basis"->{f[1]},"basis"->{f[1]/l},"transformation"->{{l}},
   "variables"->variables,"regulator"->eps,"matrices"->(#[[1;;1,1;;1]]&/@source)|>,Null];
 cut=<|"schema"->"canon-neu/sector-cut-de/v1","sector"->sector,"family_id"->family,
   "basis_id"->basisID,"coefficient_domain"->"exact-algebraic-functions","basis"->{f[2]},
   "variables"->variables,"regulator"->eps,"matrices"->(#[[-1;;-1,-1;;-1]]&/@raw)|>;
 rows=If[withPrefix,{{p/l,q}},{{q}}];
 pool=<|"schema"->"canon-neu/core-candidates/v1","sector"->sector,"family_id"->family,"basis_id"->basisID,
   "coefficient_domain"->"exact-algebraic-functions","basis"->{f[2]},"variables"->variables,"regulator"->eps,
   "convention"->"old_basis = transformation . new_basis","source_basis"->basis,
   "candidates"->{<|"candidate_id"->"fixture/candidate","member_candidate_ids"->{"fixture/member"},
     "construction_rejection"->None,"transformation"->{{1/q}},"new_basis_rows"->{{q}},
     "full_new_basis_rows"->rows,"transformed_matrices"->(#[[-1;;-1,-1;;-1]]&/@target)|>}|>;
 core=<|"schema"->"canon-neu/core-transform/v1","sector"->sector,"family_id"->family,"basis_id"->basisID,
   "basis"->{f[2]},"variables"->variables,"regulator"->eps,"candidate_id"->"fixture/candidate",
   "transformation"->{{1/q}},"checks"-><|"pass"->True|>|>;
 refs=<|"ordered_master_de"->put[name<>"-ordered",<|"schema"->"canon-neu/ordered-master-de/v1",
   "family_id"->family,"basis"->basis,"variables"->variables,"regulator"->eps,"matrices"->raw|>],
   "sector_cut_de"->put[name<>"-cut",cut],"core_candidates"->put[name<>"-pool",pool],
   "core_transform"->put[name<>"-core",core],"declared_alphabet"->Null,
   "accepted_prefix"->If[withPrefix,put[name<>"-accepted",accepted],Null]|>;
 options=task["payload","method_options"];
 If[backend=!=Null,options=Join[options,<|"normalization_backend"->backend|>]];
 request=<|"schema"->"canon-neu/script-input/v1","task_id"->"T013-"<>name,"step"->"BUILD_FULL_DE",
   "sector"->sector,"payload"->Join[refs,<|"method_options"->options|>]|>;
 Export[outputDir<>"/"<>name<>".json",request,"RawJSON"];
 expected=<|"target"->target,"raw"->raw,"raw_transformation"->w,"mixed_rows"->u,
   "mixed_transformation"->normalize[Inverse[u]],"source_transform"->t0,"source_matrices"->source,
   "epsilon_singular"->True,"nonzero_lower_rows"->withPrefix,"nonzero_upper_block"->upper|>;
 put[name<>"-expected",expected];AppendTo[names,name];
];
make["rational-nonzero","rational",True,True];
make["root-nonzero","root",True,True];
make["no-prefix","rational",False];
make["default","rational",True,True,Null];
make["unsupported-cubic","cubic",True];
Export[outputDir<>"/fixtures.json",<|"names"->names,"scientific_acceptance"->False|>,"RawJSON"];
CanonMethodCard`WriteResult[task,outputDir,"PASS","FIXTURES_PREPARED",
  <|"fixtures"-><|"type"->"json","path"->"fixtures.json"|>|>,<|"scientific_acceptance"->False|>];
