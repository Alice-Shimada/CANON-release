BeginPackage["CanonFlintBasis`"];
FlintBasisZero::usage="FlintBasisZero[matrix,variables,executable,output] tests exact zero in rational functions or one explicitly represented quadratic extension.";
Begin["`Private`"];
FlintBasisZero[m_?MatrixQ,vars_List,exe_String,out_String,logger_:None]:=Catch[Module[
 {powers,rawBases,canonicalBases,bases,lambda,root=Unique["flintRoot$"],formal,encode,stream,path,native,lines,values,runtime,timings=<||>,tick,zero},
 fail[reason_]:=Throw[Failure["UNSUPPORTED_FLINT_BASIS",<|"Message"->reason|>],flint];
 SetAttributes[tick,HoldRest];
 tick[label_,body_]:=Module[{started=AbsoluteTime[],value},
  If[logger=!=None,logger[label,"start",<||>]];
  value=body;timings[label]=AbsoluteTime[]-started;
  If[logger=!=None,logger[label,"end",<|"seconds"->timings[label]|>]];value];

 If[!DuplicateFreeQ[vars]||!AllTrue[vars,Head[#]===Symbol&],fail["Variables must be distinct symbols."]];
 tick["flint_frame",powers=DeleteDuplicates@Cases[m,Power[b_,p_Rational]:>{b,p},Infinity];
 If[!AllTrue[powers,Denominator[Last[#]]===2&],fail["Only half-integer powers are supported."]];
 rawBases=DeleteDuplicates[First/@powers];
 If[!AllTrue[rawBases,CanonMethodCard`ExactRationalExpressionQ],fail["Only exact rational radicands without nested roots are supported."]];
 canonicalBases=Factor[Together[#]]&/@rawBases;
 If[!AllTrue[canonicalBases,CanonMethodCard`ExactRationalExpressionQ]||
   !AllTrue[MapThread[Together[#1-#2]&,{rawBases,canonicalBases}],#===0&],
  fail["Radicand framing did not preserve exact rational equality."]];
 bases=DeleteDuplicates[canonicalBases,TrueQ[Together[#1-#2]===0]&];
 If[Length[bases]>1,fail["Only one quadratic generator is supported."]];
 lambda=If[bases==={},0,First[bases]];
 formal=If[bases==={},m,m/.Power[b_,p_Rational]/;MemberQ[rawBases,b]:>root^(2p)]];
 encode[e_]:=Which[
  IntegerQ[e],"n "<>ToString[e]<>"\n",
  Head[e]===Rational,encode[Numerator[e]]<>encode[Denominator[e]]<>"p -1\nm 2\n",
  MemberQ[vars,e],"v "<>ToString[First@FirstPosition[vars,e]-1]<>"\n",
  e===root,"r\n",
  Head[e]===Plus,StringJoin[encode/@(List@@e)]<>"a "<>ToString[Length[e]]<>"\n",
  Head[e]===Times,StringJoin[encode/@(List@@e)]<>"m "<>ToString[Length[e]]<>"\n",
  Head[e]===Power&&IntegerQ[e[[2]]]&&Abs[e[[2]]]<=10000,encode[e[[1]]]<>"p "<>ToString[e[[2]]]<>"\n",
  True,fail["Unsupported coefficient expression: "<>ToString[InputForm[e]]]];
 If[!DirectoryQ[out],CreateDirectory[out,CreateIntermediateDirectories->True]];
 path=FileNameJoin[{out,"basis-residual.postfix"}];
 stream=tick["flint_serialize",ToString[Length[vars]]<>"\n"<>encode[lambda]<>"e\n"<>StringJoin[(encode[#]<>"e\n")&/@Flatten[formal]]];
 tick["flint_export",Export[path,stream,"Text"]];
 native=tick["flint_native",Quiet@Check[RunProcess[{exe,path,"--batch"}],$Failed]];
 If[!AssociationQ[native],fail["Native executable could not run."]];
 tick["flint_receipt_write",Export[FileNameJoin[{out,"native.stdout"}],native["StandardOutput"],"Text"];
 Export[FileNameJoin[{out,"native.stderr"}],native["StandardError"],"Text"]];
 If[native["ExitCode"]=!=0,fail["Native exact arithmetic failed; see native.stderr."]];
 tick["flint_readback",lines=StringSplit[StringTrim[native["StandardOutput"]],"\n"];
 If[Length[lines]=!=2 Length[Flatten[m]],fail["Native output count mismatch."]];
 (* Only the canonical zero pair can pass. Nonzero native output need not be
    evaluated in Wolfram; it deterministically makes this independent gate false. *)
 runtime=Quiet@Check[ImportString[StringTrim[native["StandardError"]],"RawJSON"],$Failed]];
 If[!AssociationQ[runtime]||Lookup[runtime,"count",None]=!=Length[Flatten[m]],fail["Missing native receipt."]];
 zero=tick["flint_zero_test",And@@(StringTrim[#]==="0"&/@lines)];
 <|"zero"->zero,"timings"->timings,"runtime"->Join[runtime,
  <|"executable"->exe,"executable_sha256"->FileHash[exe,"SHA256","HexString"],
    "domain"->"rational functions or one explicit nonnested quadratic generator",
    "variables"->(ToString[#,InputForm]&/@vars),"generator_squared"->ToString[lambda,InputForm],
    "raw_distinct_radicand_count"->Length[rawBases],"canonical_distinct_radicand_count"->Length[bases],
    "raw_radicands"->(ToString[#,InputForm]&/@rawBases),"canonical_radicands"->(ToString[#,InputForm]&/@bases),
    "radicand_merge_policy"->"Only exact rational equality; no square/sign/branch equivalence."|>]|>
],flint];
End[];
EndPackage[];
