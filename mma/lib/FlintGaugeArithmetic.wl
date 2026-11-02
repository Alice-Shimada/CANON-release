BeginPackage["CanonFlintGauge`"];
FlintGaugeIdentity::usage="FlintGaugeIdentity[A,variables,T,B,executable,output,logger] proves each exact A_i T-D_i T-T B_i using the loaded strict quadratic normalizer; invertibility is the independent caller gate.";
Begin["`Private`"];
FlintGaugeIdentity[matrices_List,variables_List,t_?MatrixQ,target_List,exe_String,out_String,logger_:None,serializer_:None]:=
 Catch[Module[{tick,residual,normalized,records={},timings=<||>,zero,all=True,i,directory,relay},
  SetAttributes[tick,HoldRest];
  tick[label_,body_]:=Module[{started=AbsoluteTime[],value},
   If[logger=!=None,logger[label,"start",<||>]];value=body;
   timings[label]=N[AbsoluteTime[]-started];
   If[logger=!=None,logger[label,"end",<|"seconds"->timings[label]|>]];value];
  If[DownValues[CanonFlintNormalize`Normalize]==={},
   Throw[Failure["FLINT_NORMALIZATION_FAILED",<|"Message"->"Strict FLINT normalizer is not initialized."|>],gauge]];
  Do[
   directory=FileNameJoin[{out,"direction-"<>ToString[i]}];
   relay[label_,state_,extra_]:=If[logger=!=None,logger["gauge/"<>ToString[i]<>"/"<>label,state,extra]];
   residual=tick["gauge_product/"<>ToString[i],Normal[
    SparseArray[matrices[[i]]].SparseArray[t]-SparseArray[D[t,variables[[i]]]]-SparseArray[t].SparseArray[target[[i]]]]];
   normalized=tick["gauge_normalize/"<>ToString[i],If[serializer===None,CanonFlintNormalize`Normalize[residual,exe,directory,relay],CanonFlintNormalize`Normalize[residual,exe,directory,relay,serializer]]];
   If[FailureQ[normalized],Throw[normalized,gauge]];
   If[normalized["runtime","header_version"]=!=normalized["runtime","runtime_version"] ||
      !StringQ[normalized["runtime","runtime_version"]] || normalized["runtime","runtime_version"]==="",
    Throw[Failure["FLINT_NORMALIZATION_FAILED",<|"Message"->"Native header/runtime versions disagree."|>],gauge]];
   zero=AllTrue[Flatten[normalized["matrix"]],#===0&];all=all&&zero;
   AppendTo[records,<|"direction"->i,"variable"->ToString[variables[[i]],InputForm],"exact_zero"->zero,
    "dimensions"->Dimensions[residual],"normalization"->KeyDrop[normalized,{"matrix","pairs"}]|>],
   {i,Length[variables]}];
  If[!DirectoryQ[out],CreateDirectory[out,CreateIntermediateDirectories->True]];
  Export[FileNameJoin[{out,"gauge-readback.json"}],<|"zero"->TrueQ[all],"directions"->records,"timings"->timings,
   "clock_scope"->"AbsoluteTime differences within one kernel; products and normalization are separate, nested native/frame intervals overlap normalization."|>,"RawJSON"];
  <|"zero"->TrueQ[all],"runtime"-><|"threads"->1,"executable"->exe,"executable_sha256"->FileHash[exe,"SHA256","HexString"],
   "header_version"->First[records]["normalization","runtime","header_version"],
   "runtime_version"->First[records]["normalization","runtime","runtime_version"],
   "domain"->"exact rational functions or one unnested principal quadratic generator, merging only exactly equal rational radicands",
   "directions_checked"->Length[records],"direction_exact_zero"->Lookup[records,"exact_zero"]|>|>
 ],gauge];
End[];
EndPackage[];
