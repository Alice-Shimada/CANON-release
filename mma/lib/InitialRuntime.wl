(* Load the declared source without changing the external snapshot or installation. *)
BeginPackage["CanonInitialRuntime`"];
LoadInitial::usage = "LoadInitial[entry] loads INITIAL and returns source/adapter provenance, or $Failed on a load error.";
LoadInitial::source = "The recognized INITIAL source did not contain the unique expected sampling fragment.";
Begin["`Private`"];
adapterPath = ExpandFileName[$InputFileName];
knownSourceSHA256 = "4b4fe726f45484f31b909dc34eef85d77068b3d6dfaf3404163f8f706fc3888c";
originalFragment = "matrix=RowReduce[matrix[[2;;-1]],Modulus->prime];\nrank=MatrixRank[matrix,Modulus->prime];";
fixedFragment = "matrix=matrix[[2;;-1]];\nIf[matrix==={},\nrank=0,\nmatrix=RowReduce[matrix,Modulus->prime];\nrank=MatrixRank[matrix,Modulus->prime];\n];";

LoadInitial[entry_String] := Module[{path = ExpandFileName[entry], hash, source,
    stream, loaded, applied = False},
  hash = Check[FileHash[path, "SHA256", "HexString"], $Failed];
  If[hash === $Failed, Return[$Failed]];
  If[hash === knownSourceSHA256,
    source = Check[Import[path, "Text"], $Failed];
    If[!StringQ[source] || StringCount[source, originalFragment] =!= 1 ||
        FileHash[path, "SHA256", "HexString"] =!= hash,
      Message[LoadInitial::source]; Return[$Failed]];
    (* Get reads/evaluates one expression at a time, preserving BeginPackage
       context transitions. Never parse the complete package with ToExpression. *)
    stream = StringToStream[StringReplace[source, originalFragment -> fixedFragment]];
    If[Head[stream] =!= InputStream, Return[$Failed]];
    loaded = CheckAbort[Check[Get[stream], $Failed], $Aborted];
    Close[stream];
    If[loaded === $Aborted, Abort[]];
    applied = True,
    (* Custom, changed and already-fixed sources keep ordinary file semantics,
       including $InputFileName and relative package loading. *)
    loaded = Check[Get[path], $Failed]
  ];
  If[loaded === $Failed, Return[$Failed]];
  <|"source" -> <|"path" -> path, "sha256" -> hash|>,
    "adapter" -> <|"id" -> "initial-2.1-empty-training-rank-v1",
      "path" -> adapterPath, "sha256" -> FileHash[adapterPath, "SHA256", "HexString"],
      "applied" -> applied|>|>
];
End[];
EndPackage[];
