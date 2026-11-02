BeginPackage["CanonBlockArithmetic`"];
InitializeFermatBlock::usage="InitializeFermatBlock[task,input,output] loads the selected installed Fermatica entry and records its actual runtime identity.";
FermatBlockFrame::usage="FermatBlockFrame[data] constructs a rational or single quadratic binomial frame without changing root branches.";
FermatBlockDot::usage="FermatBlockDot[frame,{matrices}] multiplies exact matrices natively and reduces the declared binomial extension.";
FermatBlockPlus::usage="FermatBlockPlus[frame,{matrices}] adds exact matrices natively and reduces the declared binomial extension.";
FermatBlockTogether::usage="FermatBlockTogether[frame,matrix] normalizes exact entries natively in the declared extension.";
Begin["`Private`"];
failure[tag_,message_]:=Failure[tag,<|"Message"->message|>];
InitializeFermatBlock[task_,input_,output_]:=Module[{resolved,entry,temp,exe},
 resolved=CanonMethodCard`ResolveMethodPackage[task,input,"Fermatica`"];
 If[FailureQ[resolved],Return[resolved]];
 entry=resolved["entry"];temp=FileNameJoin[{output,"fermat-temp"}];
 If[!DirectoryQ[temp],CreateDirectory[temp,CreateIntermediateDirectories->True]];
 Quiet[Check[Block[{$TemporaryDirectory=temp},Get[entry]],
   Return[failure["FERMAT_BLOCK_UNAVAILABLE","The declared Fermatica entry did not load."]]]];
 (* This installed snapshot concatenates the snippet name to its public home
    directory. Bind that directory from the actual entry, with a separator. *)
 Fermatica`$FermaticaHomeDirectory=DirectoryName[entry]<>$PathnameSeparator;
 Fermatica`$FermatTempDir=temp<>$PathnameSeparator;
 exe=Fermatica`$FermatCMD;
 If[!StringQ[exe]||FileType[exe]=!=File||!StringQ[Fermatica`$FermatVersionString]||
   Fermatica`$FermatVersionString==="",
   Return[failure["FERMAT_BLOCK_UNAVAILABLE","FERMATPATH must name the installed Fermat executable."]]];
 <|"backend"->"fermat","package_entry"->entry,"package_sha256"->FileHash[entry,"SHA256","HexString"],
   "package_version"->Fermatica`$FermaticaVersion,"executable"->exe,
   "executable_sha256"->FileHash[exe,"SHA256","HexString"],"executable_version"->Fermatica`$FermatVersionString,
   "domain"->"rational functions or one explicit quadratic binomial extension",
   "temporary_directory"->temp|>
];
FermatBlockFrame[data_]:=Module[{powers,bases,roots},
 If[!AllTrue[Flatten[data],CanonMethodCard`ExactAlgebraicExpressionQ]||
   !FreeQ[data,_Complex|_Root|_AlgebraicNumber],
   Return[failure["UNSUPPORTED_FERMAT_BLOCK_DOMAIN","Use exact rational functions and explicit quadratic powers."]]];
 powers=DeleteDuplicates@Cases[data,Power[b_,p_Rational]:>{Factor[b],p},Infinity];
 If[!AllTrue[powers,Denominator[#[[2]]]===2&&CanonMethodCard`ExactRationalExpressionQ[#[[1]]]&],
   Return[failure["UNSUPPORTED_FERMAT_BLOCK_DOMAIN","Only nonnested half-integer powers are supported."]]];
 bases=DeleteDuplicates[First/@powers];
 If[Length[bases]>1,Return[failure["UNSUPPORTED_FERMAT_BLOCK_DOMAIN","The initial backend supports one quadratic generator."]]];
 roots=Table[Unique["blockRoot$"],{Length[bases]}];
 <|"bases"->bases,"roots"->roots,
   "relations"->MapThread[#1->#1^2-#2&,{roots,bases}],
   "restore"->MapThread[#1->Sqrt[#2]&,{roots,bases}]|>
];
formal[frame_,m_]:=m/.Power[b_,p_Rational]/;MemberQ[frame["bases"],Factor[b]]:>
 With[{i=First@FirstPosition[frame["bases"],Factor[b]]},frame["roots"][[i]]^(2p)];
reduce[frame_,m_]:=Module[{result=m},
 If[!MatrixQ[result],Return[failure["FERMAT_BLOCK_ARITHMETIC_FAILED","Native arithmetic did not return a matrix."]]];
 If[frame["relations"]=!={},result=Quiet@CheckAbort[
   Fermatica`FQuolyMod[result,frame["relations"]],$Failed]];
 If[!MatrixQ[result],Return[failure["FERMAT_BLOCK_ARITHMETIC_FAILED","Binomial quotient reduction failed."]]];
 result/.frame["restore"]
];
formalMatrices[frame_,ms_]:=Module[{values=formal[frame,#]&/@ms},
 If[!AllTrue[values,MatrixQ]||!AllTrue[Flatten[values],CanonMethodCard`ExactAlgebraicExpressionQ]||
   !FreeQ[values,Power[_,p_]/;!IntegerQ[p]]||!FreeQ[values,_Complex|_Root|_AlgebraicNumber],
   failure["UNSUPPORTED_FERMAT_BLOCK_DOMAIN","An operand is outside the declared binomial frame."],values]
];
FermatBlockDot[frame_,ms_List]:=Module[{values,result},
 values=formalMatrices[frame,ms];If[FailureQ[values],Return[values]];
 result=Quiet@CheckAbort[Fermatica`FDot@@values,$Failed];reduce[frame,result]
];
FermatBlockPlus[frame_,ms_List]:=Module[{values,result},
 values=formalMatrices[frame,ms];If[FailureQ[values],Return[values]];
 result=Quiet@CheckAbort[Fermatica`FPlus@@values,$Failed];reduce[frame,result]
];
FermatBlockTogether[frame_,m_]:=Module[{values,result},
 values=formalMatrices[frame,{m}];If[FailureQ[values],Return[values]];
 result=Quiet@CheckAbort[Fermatica`FTogether[First[values]],$Failed];reduce[frame,result]
];
End[];
EndPackage[];
