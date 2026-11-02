BeginPackage["CanonFlintNormalize`"];
Normalize::usage="Normalize[matrix,executable,output,logger] returns an exact matrix and runtime from the existing quadratic-pair engine.";
ReadPairs::usage="ReadPairs[stdout,stderr,variables,lambda,dimensions] parses the restricted native rational-pair format without evaluating native text.";
CheckedSerializer::usage="CheckedSerializer[declaringFile,spec] validates an explicitly hash-bound structural serializer; None retains interpreted encoding.";
Begin["`Private`"];
rationalQ[e_] := Which[IntegerQ[e]||Head[e]===Rational,True,
 Head[e]===Symbol,!TrueQ[NumericQ[e]],
 MemberQ[{Plus,Times},Head[e]],AllTrue[List@@e,rationalQ],
 Head[e]===Power,IntegerQ[e[[2]]]&&rationalQ[e[[1]]],True,False];
domain[reason_] := Throw[Failure["UNSUPPORTED_FLINT_DOMAIN",<|"Message"->reason|>],flint];
fail[reason_] := Throw[Failure["FLINT_NORMALIZATION_FAILED",<|"Message"->reason|>],flint];
parse[line_String,vars_List] := Module[{tokens,pos=1,n,peek,take,integer,primary,power,unary,term,expression,value,clean},
 clean=StringReplace[line,WhitespaceCharacter->""];
 tokens=StringCases[clean,RegularExpression["v[0-9]+|[0-9]+|[+*/^()-]"]];
 If[StringJoin[tokens]=!=clean||clean===""||StringCount[clean,"/"]>1,fail["Native coefficient contains an unsupported token or division format."]];
 n=Length[tokens];peek[]:=If[pos<=n,tokens[[pos]],""];
 take[]:=If[pos<=n,tokens[[pos++]],fail["Unexpected end of native coefficient."]];
 integer[s_]:=FromDigits[ToCharacterCode[s]-ToCharacterCode["0"][[1]]];
 primary[]:=Module[{t=take[],i,v},
  Which[StringMatchQ[t,DigitCharacter..],integer[t],
   StringMatchQ[t,"v"~~DigitCharacter..],i=integer[StringDrop[t,1]];
    If[i<0||i>=Length[vars],fail["Native variable index is outside the declared variables."]];vars[[i+1]],
   t==="(",v=expression[];If[take[]=!=")",fail["Unmatched native parentheses."]];v,
   True,fail["Expected integer, declared variable or parentheses."]]];
 power[]:=Module[{v=primary[],e,t},
  If[peek[]==="^",take[];t=take[];
   If[!StringMatchQ[t,DigitCharacter..],fail["Native exponent must be a nonnegative integer."]];
   e=integer[t];If[e>10000||!MemberQ[vars,v],fail["Native polynomial exponent/base is outside the supported format."]];v=v^e];v];
 unary[]:=Switch[peek[],"+",take[];unary[],"-",take[];-unary[],_,power[]];
 term[]:=Module[{v=unary[],op,d},
  While[MemberQ[{"*","/"},peek[]],op=take[];d=unary[];
   If[op==="/"&&d===0,fail["Native coefficient has a zero denominator."]];v=If[op==="*",v*d,v/d]];v];
 expression[]:=Module[{v=term[],op,d},
  While[MemberQ[{"+","-"},peek[]],op=take[];d=term[];v=If[op==="+",v+d,v-d]];v];
 value=Quiet@Check[expression[],fail["Native arithmetic expression is undefined."]];
 If[pos<=n||!rationalQ[value]||!FreeQ[value,Indeterminate|_DirectedInfinity],
  fail["Native coefficient is incomplete or not exact rational arithmetic."]];
 value
];
CanonFlintNormalize`ReadPairs[stdout_String,stderr_String,vars_List,lambda_,dimensions_List] :=
 Catch[Module[{lines,receipt,pairs,result,count=Times@@dimensions,zero},
 If[Length[dimensions]=!=2||!AllTrue[dimensions,IntegerQ[#]&&#>0&]||
   !DuplicateFreeQ[vars]||!AllTrue[vars,Head[#]===Symbol&&!TrueQ[NumericQ[#]]&]||!rationalQ[lambda],
  fail["Invalid declared readback frame."]];
 lines=StringSplit[StringTrim[stdout],"\n"];
 If[Length[lines]=!=2 count,fail["Native pair count does not match matrix dimensions."]];
 receipt=Quiet@Check[ImportString[StringTrim[stderr],"RawJSON"],$Failed];
 If[!AssociationQ[receipt]||Lookup[receipt,"count",None]=!=count||
  !MemberQ[{True,False},Lookup[receipt,"all_zero",None]]||
  !StringQ[Lookup[receipt,"header_version",None]]||!StringQ[Lookup[receipt,"runtime_version",None]]||
  !NumericQ[Lookup[receipt,"native_seconds",None]]||receipt["native_seconds"]<0,
  fail["Missing or inconsistent native exact-arithmetic receipt."]];
 pairs=Partition[parse[#,vars]&/@lines,2];
 If[lambda===0&&!AllTrue[pairs,#[[2]]===0&],fail["A rational matrix returned a spurious quadratic coefficient."]];
 zero=AllTrue[pairs,#[[1]]===0&&#[[2]]===0&];
 If[receipt["all_zero"]=!=zero,fail["Native zero flag disagrees with exact pair output."]];
 result=Partition[(#[[1]]+#[[2]]*Sqrt[lambda])&/@pairs,Last[dimensions]];
 <|"matrix"->result,"runtime"->receipt,"pairs"->pairs|>
 ],flint];
CanonFlintNormalize`CheckedSerializer[base_String,spec_] := Module[{exe,source,version},
 If[spec===None,Return[None]];
 If[!AssociationQ[spec]||Sort[Keys[spec]]=!=Sort[{"executable","source"}]||
   !AllTrue[Values[spec],AssociationQ[#]&&StringQ[Lookup[#,"sha256",None]]&&StringLength[#["sha256"]]===64&],
  Return[Failure["FLINT_SERIALIZER_UNAVAILABLE",<|"Message"->"Supply exactly hash-bound serializer executable/source descriptors."|>]]];
 exe=CanonMethodCard`ResolveArtifactPath[base,spec["executable"]];source=CanonMethodCard`ResolveArtifactPath[base,spec["source"]];
 If[FailureQ[exe]||FailureQ[source],Return[Failure["FLINT_SERIALIZER_UNAVAILABLE",<|"Message"->"Serializer executable/source is unavailable or changed."|>]]];
 version=Quiet@Check[RunProcess[{exe,"--version"}],$Failed];
 If[!AssociationQ[version]||version["ExitCode"]=!=0||StringTrim[version["StandardOutput"]]=!="canon-fullform-postfix/v1",
  Return[Failure["FLINT_SERIALIZER_UNAVAILABLE",<|"Message"->"Serializer version/initialization failed."|>]]];
 <|"name"->"fullform-postfix","executable"->exe,"executable_sha256"->FileHash[exe,"SHA256","HexString"],
  "source"->source,"source_sha256"->FileHash[source,"SHA256","HexString"],"version"->StringTrim[version["StandardOutput"]]|>
];
CanonFlintNormalize`Normalize[m_?MatrixQ,exe_String,out_String,logger_:None,serializer_:None] :=
 Catch[Module[{powers,rawBases,canonicalBases,bases,frame,frameStart,saveFrame,lambda,root=Unique["flintRoot$"],formal,vars,encode,rejectCoefficient,text,path,native,readback,timings=<||>,tick,fullform,spellings,converted,conversion,serialization,stream,writePart,closedStream,shape,i,j},
 SetAttributes[tick,HoldRest];
 tick[label_,body_]:=Module[{start=AbsoluteTime[],value},
  If[logger=!=None,logger[label,"start",<||>]];
  value=body;timings[label]=N[AbsoluteTime[]-start];
  If[logger=!=None,logger[label,"end",<|"operation_seconds"->timings[label]|>]];value];
 If[!DirectoryQ[out],CreateDirectory[out,CreateIntermediateDirectories->True]];
 frameStart=AbsoluteTime[];
 tick["flint_root_collect",powers=DeleteDuplicates@Cases[m,Power[b_,p_Rational]:>{b,p},Infinity];
 rawBases=DeleteDuplicates[First/@powers]];
 frame=<|"raw_distinct_radicand_count"->Length[rawBases],
   "raw_radicands"->(ToString[#,InputForm]&/@rawBases),
   "canonical_distinct_radicand_count"->Null,"canonical_radicands"->{},
   "merge_policy"->"Only exact rational equality, Together[raw-canonical] === 0; no square/sign/branch identification."|>;
 saveFrame[]:=(frame=Join[frame,<|"frame_seconds"->N[AbsoluteTime[]-frameStart]|>];
   Export[FileNameJoin[{out,"radicand-frame.json"}],frame,"RawJSON"]);
 If[!AllTrue[powers,Denominator[Last[#]]===2&&rationalQ[First[#]]&],
   frame["status"]="rejected_nonrational_or_nested_radicand";saveFrame[];
   domain["Only exact rational functions or unnested principal half-integer powers are supported."]];
 canonicalBases=tick["flint_radicand_canonicalize",Factor[Together[#]]&/@rawBases];
 If[!AllTrue[canonicalBases,rationalQ]||
   !AllTrue[MapThread[Together[#1-#2]&,{rawBases,canonicalBases}],#===0&],
   frame["status"]="rejected_radicand_canonicalization";saveFrame[];
   domain["Radicand canonicalization did not preserve exact rational equality."]];
 bases=DeleteDuplicates[canonicalBases,TrueQ[Together[#1-#2]===0]&];
 frame=Join[frame,<|"canonical_distinct_radicand_count"->Length[bases],
   "canonical_radicands"->(ToString[#,InputForm]&/@bases),
   "canonical_by_raw"->(ToString[#,InputForm]&/@canonicalBases),
   "exact_raw_to_canonical_equality"->True,
   "canonicalization_seconds"->timings["flint_radicand_canonicalize"],
   "status"->If[Length[bases]>1,"rejected_distinct_radicands","accepted_single_frame"]|>];
 saveFrame[];
 If[Length[bases]>1,domain["Only one explicit quadratic generator is supported."]];
 lambda=If[bases==={},0,First[bases]];
 formal=tick["flint_formal_substitute",If[bases==={},m,m/.Power[b_,p_Rational]/;MemberQ[rawBases,b]:>root^(2p)]];
 rejectCoefficient[]:=(frame["status"]="rejected_inexact_or_transcendental_coefficient";saveFrame[];
   domain["Inexact, transcendental or unsupported algebraic input."]);
 tick["flint_variables_domain",vars=DeleteDuplicates@DeleteCases[Cases[{formal,lambda},_Symbol,Infinity],root];
   If[!AllTrue[vars,rationalQ],rejectCoefficient[]]];
 (* The installed native requires at least one slot. Constants never encode it,
    and readback only accepts actual vars, so the internal slot cannot leak. *)
 encode[e_]:=Which[IntegerQ[e],"n "<>ToString[e]<>"\n",
  Head[e]===Rational,encode[Numerator[e]]<>encode[Denominator[e]]<>"p -1\nm 2\n",
  Head[e]===Symbol&&MemberQ[vars,e],"v "<>ToString[First@FirstPosition[vars,e]-1]<>"\n",
  e===root,"r\n",
  Head[e]===Plus,StringJoin[encode/@(List@@e)]<>"a "<>ToString[Length[e]]<>"\n",
  Head[e]===Times,StringJoin[encode/@(List@@e)]<>"m "<>ToString[Length[e]]<>"\n",
  Head[e]===Power&&IntegerQ[e[[2]]]&&Abs[e[[2]]]<=10000,encode[e[[1]]]<>"p "<>ToString[e[[2]]]<>"\n",
  True,If[Head[e]===Power&&IntegerQ[e[[2]]]&&rationalQ[e[[1]]],
    domain["Input is outside the exact postfix protocol."],rejectCoefficient[]]];
 If[!DirectoryQ[out],CreateDirectory[out,CreateIntermediateDirectories->True]];
 path=FileNameJoin[{out,"matrix.postfix"}];
 serialization=<|"name"->"wolfram-postfix"|>;
 If[serializer===None,
 tick["flint_serialize",text=ToString[Max[1,Length[vars]]]<>"\n"<>encode[lambda]<>"e\n"<>StringJoin[(encode[#]<>"e\n")&/@Flatten[formal]];Export[path,text,"Text"]];,
  If[!AssociationQ[serializer]||Lookup[serializer,"name",None]=!="fullform-postfix",fail["Serializer must be checked explicitly before normalization."]];
  fullform=FileNameJoin[{out,"matrix.fullform"}];
  tick["flint_fullform_export",stream=None;
   Internal`WithLocalSettings[Null,
    Block[{$Context="CanonSerializerFrame`",$ContextPath={"System`"}},
     shape=Dimensions[m];
     spellings=ToString[FullForm[#],OutputForm,PageWidth->Infinity]&/@Join[{root},vars];
     stream=Quiet@Check[OpenWrite[fullform,CharacterEncoding->"UTF8"],$Failed];
     If[Head[stream]=!=OutputStream,fail["Could not open structural serializer output stream."]];
     writePart[part_String]:=If[Quiet@Check[WriteString[stream,part],$Failed]=!=Null,
       fail["Could not write structural serializer output stream."]];
     writePart["CANON_FULLFORM_POSTFIX_V1\n"<>StringRiffle[ToString/@Join[{Length[vars]},shape]," "]<>"\n"<>
       StringRiffle[spellings,"\n"]<>"\nList["];
     writePart[ToString[FullForm[lambda],OutputForm,PageWidth->Infinity]];
     writePart[", List["];
     Do[If[i>1,writePart[", "]];writePart["List["];
      Do[If[j>1,writePart[", "]];
       writePart[ToString[FullForm[formal[[i,j]]],OutputForm,PageWidth->Infinity]],
       {j,shape[[2]]}];writePart["]"],{i,shape[[1]]}];
     writePart["]]"];
     closedStream=Quiet@Check[Close[stream],$Failed];
     If[!StringQ[closedStream],fail["Could not close structural serializer output stream."]];stream=None],
    If[Head[stream]===OutputStream,Quiet@Check[Close[stream],Null]]]];
  converted=tick["flint_converter",Quiet@Check[RunProcess[{serializer["executable"],fullform,path}],$Failed]];
  If[!AssociationQ[converted],fail["Structural serializer could not run."]];
  Export[FileNameJoin[{out,"serializer.stdout"}],converted["StandardOutput"],"Text"];
  Export[FileNameJoin[{out,"serializer.stderr"}],converted["StandardError"],"Text"];
  If[converted["ExitCode"]=!=0,domain["Structural serializer rejected unsupported/malformed exact input: "<>converted["StandardError"]]];
  conversion=Quiet@Check[ImportString[StringTrim[converted["StandardOutput"]],"RawJSON"],$Failed];
  If[!AssociationQ[conversion]||Lookup[conversion,"schema",None]=!="canon-fullform-postfix/v1"||
    Lookup[conversion,"variable_count",None]=!=Length[vars]||Lookup[conversion,"count",None]=!=Times@@Dimensions[m]||
    {Lookup[conversion,"rows",None],Lookup[conversion,"columns",None]}=!=Dimensions[m]||
    !FileExistsQ[path]||Lookup[conversion,"postfix_bytes",None]=!=FileByteCount[path],fail["Structural serializer receipt/frame/output is inconsistent."]];
  serialization=Join[serializer,<|"receipt"->conversion,"export_strategy"->"coefficient-stream","maximum_formatted_coefficients_per_chunk"->1|>]
 ];
 native=tick["flint_native",Quiet@Check[RunProcess[{exe,path,"--batch"}],$Failed]];
 If[!AssociationQ[native],fail["Native executable could not run."]];
 Export[FileNameJoin[{out,"native.stdout"}],native["StandardOutput"],"Text"];
 Export[FileNameJoin[{out,"native.stderr"}],native["StandardError"],"Text"];
 If[native["ExitCode"]=!=0,fail["Native exact arithmetic returned a nonzero exit code."]];
 readback=tick["flint_readback",CanonFlintNormalize`ReadPairs[native["StandardOutput"],native["StandardError"],vars,lambda,Dimensions[m]]];
 If[FailureQ[readback],Throw[readback,flint]];
 readback=Join[readback,<|"timings"->timings,"variables"->(ToString[#,InputForm]&/@vars),
  "generator_squared"->ToString[lambda,InputForm],"radicand_frame"->frame,"native_variable_count"->Max[1,Length[vars]],
  "constant_dummy_slot"->(vars==={}),"serialization"->serialization,"executable"->exe,"executable_sha256"->FileHash[exe,"SHA256","HexString"]|>];
 Export[FileNameJoin[{out,"readback.json"}],KeyDrop[readback,{"matrix","pairs"}],"RawJSON"];
 readback
 ],flint];
End[];
EndPackage[];
