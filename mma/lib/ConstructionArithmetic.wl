BeginPackage["CanonFFT`"];
CanonFFT`InitializeArithmetic::usage = "Initialize[task,input,output] selects explicit construction normalization and records its runtime.";
CanonFFT`NormalizeMatrix::usage = "NormalizeMatrix[label,matrix] normalizes entries with the selected arithmetic backend.";
Begin["`Private`"];
$Phases = {"source_current_lower_reduce", "current_core_inverse_reduce",
  "candidate_lower_transform_reduce", "candidate_full_gauge_reduce"};

emit[data_Association] := Module[{stream},
  stream = OpenAppend[$Trace];
  WriteString[stream, ExportString[data, "RawJSON", "Compact" -> True], "\n"];
  Close[stream]
];
abort[code_, message_] := (
  emit[<|"event" -> "error", "code" -> code, "message" -> message,
    "backend" -> $Backend, "phase" -> $Phase,
    "elapsed_seconds" -> N[AbsoluteTime[] - $Started]|>];
  CanonMethodCard`WriteResult[$Task, $Output, "ERROR", code, <||>,
    <|"reason" -> message, "normalization_backend" -> $Backend,
      "normalization_backends" -> $Backends,
      "scientific_acceptance" -> False|>]; Quit[1]
);
rationalQ[expression_] := Which[
  IntegerQ[expression] || Head[expression] === Rational, True,
  Head[expression] === Symbol, !TrueQ[NumericQ[expression]],
  MemberQ[{Plus, Times}, Head[expression]], AllTrue[List @@ expression, rationalQ],
  Head[expression] === Power, IntegerQ[expression[[2]]] && rationalQ[expression[[1]]],
  True, False
];

CanonFFT`InitializeArithmetic[task_Association, input_String, output_String] := Module[
  {options, overrides, path, config, entry, library, loaded, discovered, binding, actual,
   dependency, fermatEntry, executable, fermatTask, fermatRuntime, flintHelper, flintSource, flintExecutable, version},
  {$Task, $Output, $Started, $Counter} = {task, output, AbsoluteTime[], 0};
  {$Backend, $DefaultBackend, $Backends, $Phase} = {"together", "together", <||>, Null};
  If[!DirectoryQ[output], CreateDirectory[output, CreateIntermediateDirectories -> True]];
  $Trace = FileNameJoin[{output, "normalization-events.jsonl"}];
  options = Lookup[task["payload"], "method_options", <||>];
  If[!AssociationQ[options],
    abort["INVALID_ARITHMETIC_CONFIG", "method_options must be an Association."]];
  $Backend = $DefaultBackend = Lookup[options, "normalization_backend", "together"];
  If[!MemberQ[{"together", "finiteflow", "fermat", "flint"}, $Backend],
    abort["UNSUPPORTED_NORMALIZATION_BACKEND", "Select together, finiteflow, fermat or flint explicitly."]];
  overrides = Lookup[options, "normalization_backends", <||>];
  If[!AssociationQ[overrides] || !AllTrue[Keys[overrides], MemberQ[$Phases, #] &],
    abort["INVALID_NORMALIZATION_BACKENDS", "normalization_backends must map only the four declared construction phases."]];
  If[!AllTrue[Values[overrides], MemberQ[{"together", "finiteflow", "fermat", "flint"}, #] &],
    abort["UNSUPPORTED_NORMALIZATION_BACKEND", "Each phase must select together, finiteflow, fermat or flint explicitly."]];
  $Backends = Join[AssociationThread[$Phases, ConstantArray[$DefaultBackend, Length[$Phases]]], overrides];
  $Runtime = <|"schema" -> "canon-neu/construction-arithmetic/v1",
    "backend" -> If[Length[DeleteDuplicates[Values[$Backends]]] === 1, First[Values[$Backends]], "mixed"],
    "default_backend" -> $DefaultBackend, "normalization_backends" -> $Backends,
    "phase_scope" -> "Operational inclusive normalization intervals; no scientific acceptance.",
    "wolfram_version" -> $Version|>;
  If[AnyTrue[Values[$Backends], MemberQ[{"finiteflow", "fermat", "flint"}, #] &],
    $Backend = Which[MemberQ[Values[$Backends],"finiteflow"],"finiteflow",MemberQ[Values[$Backends],"fermat"],"fermat",True,"flint"];
    path = CanonMethodCard`ResolveArtifactPath[input, Lookup[options, "runtime_config", None]];
    If[FailureQ[path], abort["ARITHMETIC_BACKEND_UNAVAILABLE", "Supply a hash-bound runtime_config descriptor."]];
    config = Import[path, "RawJSON"];
    If[!AssociationQ[config], abort["INVALID_ARITHMETIC_CONFIG", "runtime_config must contain a JSON object."]]
  ];
  If[MemberQ[Values[$Backends], "finiteflow"],
    $Backend = "finiteflow";
    $Threads = Lookup[config, "finiteflow_threads", None];
    If[!IntegerQ[$Threads] || $Threads <= 0,
      abort["INVALID_ARITHMETIC_CONFIG", "finiteflow_threads must be a positive integer."]];
    $MaxPrimes = Lookup[config, "finiteflow_max_primes", 5];
    If[!IntegerQ[$MaxPrimes] || $MaxPrimes < 0,
      abort["INVALID_ARITHMETIC_CONFIG", "finiteflow_max_primes must be a nonnegative integer."]];
    entry = CanonMethodCard`ResolveArtifactPath[path, Lookup[config, "finiteflow_entry", None]];
    library = CanonMethodCard`ResolveArtifactPath[path, Lookup[config, "finiteflow_library", None]];
    If[FailureQ[entry] || FailureQ[library],
      abort["ARITHMETIC_BACKEND_UNAVAILABLE", "Declared FiniteFlow entry/library is missing or has a different hash."]];
    loaded = Quiet @ Check[Block[{$LibraryPath = Prepend[$LibraryPath, DirectoryName[library]]}, Get[entry]], $Failed];
    discovered = FiniteFlow`Private`fflowlib;
    binding = If[loaded === $Failed, $Failed, Quiet @ Check[
      FiniteFlow`Private`fflowlib = library;
      LibraryLoad[library]; FiniteFlow`Private`FFLoadLibObjects[], $Failed]];
    actual = Quiet @ Check[First[FiniteFlow`Private`FFNewGraphImplem], $Failed];
    Export[FileNameJoin[{output, "native-load-readback.json"}],
      <|"declared_library" -> library, "get_return" -> ToString[loaded, InputForm],
        "automatic_discovery_library" -> ToString[discovered, InputForm],
        "automatic_discovery_sha256" -> If[StringQ[discovered] && FileExistsQ[discovered],
          FileHash[discovered, "SHA256", "HexString"], Null],
        "binding_return" -> ToString[binding, InputForm],
        "actual_library" -> ToString[FiniteFlow`Private`fflowlib, InputForm],
        "native_function" -> ToString[FiniteFlow`Private`FFNewGraphImplem, InputForm],
        "native_function_library" -> ToString[actual, InputForm],
        "native_function_head" -> ToString[Head[FiniteFlow`Private`FFNewGraphImplem], InputForm]|>, "RawJSON"];
    If[loaded === $Failed || binding === $Failed || !StringQ[actual] ||
      ExpandFileName[actual] =!= library ||
      Head[FiniteFlow`Private`FFNewGraphImplem] =!= LibraryFunction,
      abort["ARITHMETIC_BACKEND_UNAVAILABLE", "The native LibraryFunction did not bind the declared FiniteFlow library."]];
    FiniteFlow`FFNThreads = $Threads;
    $Runtime = Join[$Runtime, <|"entry" -> entry, "entry_sha256" -> FileHash[entry, "SHA256", "HexString"],
      "native_library" -> library, "native_library_sha256" -> FileHash[library, "SHA256", "HexString"],
      "native_loaded" -> True, "native_function_library" -> actual, "finiteflow_threads" -> $Threads, "FFNThreads" -> FiniteFlow`FFNThreads,
      "reconstruction_NThreads" -> $Threads,
      "reconstruction_MaxPrimes" -> $MaxPrimes,
      "dependency_revision" -> Lookup[config, "finiteflow_revision", "unknown; installed bytes pinned"],
      "algebraic_scope" -> "Unnested principal quadratic powers of exact rational radicands; formal generators restored exactly."|>]
  ];
  If[MemberQ[Values[$Backends], "fermat"],
    $Backend = "fermat";
    If[Lookup[config, "fermat_threads", None] =!= 1,
      abort["INVALID_ARITHMETIC_CONFIG", "The initial Fermat phase backend requires fermat_threads = 1."]];
    dependency = CanonMethodCard`ResolveArtifactPath[path, Lookup[config, "fermat_dependency", None]];
    fermatEntry = CanonMethodCard`ResolveArtifactPath[path, Lookup[config, "fermatica_entry", None]];
    executable = CanonMethodCard`ResolveArtifactPath[path, Lookup[config, "fermat_executable", None]];
    If[AnyTrue[{dependency, fermatEntry, executable}, FailureQ],
      abort["ARITHMETIC_BACKEND_UNAVAILABLE", "The declared Fermat dependency, package or executable is unavailable or has a different hash."]];
    If[!StringQ[Environment["FERMATPATH"]] || ExpandFileName[Environment["FERMATPATH"]] =!= executable,
      abort["INVALID_ARITHMETIC_CONFIG", "FERMATPATH must match the declared Fermat executable."]];
    If[Quiet @ Check[Get[dependency]; True, False] =!= True,
      abort["ARITHMETIC_BACKEND_UNAVAILABLE", "The declared Fermat arithmetic dependency did not load."]];
    fermatTask = Join[task, <|"payload" -> Join[task["payload"],
      <|"method_options" -> Join[options, <|"package_entry" -> fermatEntry|>]|>]|>];
    fermatRuntime = CanonBlockArithmetic`InitializeFermatBlock[fermatTask, input, output];
    If[FailureQ[fermatRuntime], abort["ARITHMETIC_BACKEND_UNAVAILABLE", fermatRuntime[[2, "Message"]]]];
    If[!AssociationQ[fermatRuntime] || fermatRuntime["package_entry"] =!= fermatEntry ||
      fermatRuntime["executable"] =!= executable,
      abort["ARITHMETIC_BACKEND_UNAVAILABLE", "The initialized Fermat package/executable does not match the declared installation."]];
    $Runtime = Join[$Runtime, <|"fermat_runtime" -> Join[fermatRuntime,
      <|"dependency" -> dependency, "dependency_sha256" -> FileHash[dependency, "SHA256", "HexString"],
        "threads" -> 1, "normalization_scope" -> "Explicit matrix normalization only; existing zero-block route conditions unchanged."|>]|>]
  ];
  If[MemberQ[Values[$Backends], "flint"],
    $Backend = "flint";
    If[Lookup[config, "flint_threads", None] =!= 1, abort["INVALID_ARITHMETIC_CONFIG", "flint_threads must be 1."]];
    flintHelper = CanonMethodCard`ResolveArtifactPath[path, Lookup[config, "flint_helper", None]];
    flintSource = CanonMethodCard`ResolveArtifactPath[path, Lookup[config, "flint_source", None]];
    flintExecutable = CanonMethodCard`ResolveArtifactPath[path, Lookup[config, "flint_executable", None]];
    If[AnyTrue[{flintHelper, flintSource, flintExecutable}, FailureQ],
      abort["ARITHMETIC_BACKEND_UNAVAILABLE", "The declared FLINT helper/source/executable is missing or changed."]];
    If[Quiet@Check[Get[flintHelper];True,False] =!= True || DownValues[CanonFlintNormalize`Normalize] === {},
      abort["ARITHMETIC_BACKEND_UNAVAILABLE", "FLINT normalization helper did not load."]];
    version = Quiet@Check[RunProcess[{flintExecutable, "--version"}], $Failed];
    If[!AssociationQ[version] || version["ExitCode"] =!= 0 ||
      Length[StringSplit[StringTrim[version["StandardOutput"]], "\n"]] =!= 2,
      abort["ARITHMETIC_BACKEND_UNAVAILABLE", "Declared FLINT executable did not return header/runtime versions."]];
    $FlintExecutable = flintExecutable;
    $FlintSerializer = If[KeyExistsQ[config,"flint_serializer"],CanonFlintNormalize`CheckedSerializer[path,config["flint_serializer"]],None];
    If[$FlintSerializer=!=None&&!AssociationQ[$FlintSerializer],abort["ARITHMETIC_BACKEND_UNAVAILABLE","Declared structural serializer did not initialize."]];
    $Runtime = Join[$Runtime, <|"flint_runtime" -> <|"executable" -> flintExecutable,
      "executable_sha256" -> FileHash[flintExecutable,"SHA256","HexString"],
      "source" -> flintSource, "source_sha256" -> FileHash[flintSource,"SHA256","HexString"],
      "helper" -> flintHelper, "helper_sha256" -> FileHash[flintHelper,"SHA256","HexString"],
      "header_version" -> First[StringSplit[StringTrim[version["StandardOutput"]],"\n"]],
      "runtime_version" -> Last[StringSplit[StringTrim[version["StandardOutput"]],"\n"]],
      "threads" -> 1, "domain" -> "Exact rational functions or one explicit unnested principal quadratic generator."|>|>]
  ];
  If[MemberQ[Values[$Backends],"flint"]&&$FlintSerializer=!=None,$Runtime=Join[$Runtime,<|"flint_serializer"->$FlintSerializer|>]];
  $Backend = $DefaultBackend;
  Export[FileNameJoin[{output, "arithmetic-runtime.json"}], $Runtime, "RawJSON"];
  emit[<|"event" -> "initialized", "backend" -> $Runtime["backend"],
    "normalization_backends" -> $Backends, "elapsed_seconds" -> N[AbsoluteTime[] - $Started]|>]
];

finiteNormalize[expression_, row_, column_] := Module[{powers, roots, generators, lifted, variables, result, id, start},
  powers = Cases[expression, p_Power /; !IntegerQ[p[[2]]] :> p, {0, Infinity}];
  If[!AllTrue[powers, Head[#[[2]]] === Rational && Denominator[#[[2]]] === 2 && rationalQ[#[[1]]] &],
    abort["UNSUPPORTED_ARITHMETIC_DOMAIN", "Only exact rational expressions and unnested quadratic powers are supported."]];
  roots = DeleteDuplicates[First /@ powers];
  generators = Table[Unique["CanonFFT`Root$"], {Length[roots]}];
  lifted = expression /. p:Power[base_, exponent_Rational] /; Denominator[exponent] === 2 :>
    generators[[First @ FirstPosition[roots, base]]]^(2 exponent);
  If[!rationalQ[lifted],
    abort["UNSUPPORTED_ARITHMETIC_DOMAIN", "The expression contains an inexact, transcendental or unsupported algebraic term."]];
  variables = Variables[lifted];
  If[variables === {}, Return[expression]];
  id = ++$Counter; start = AbsoluteTime[];
  emit[<|"event" -> "start", "id" -> id, "parent" -> $Parent, "phase" -> $Phase,
    "row" -> row, "column" -> column, "backend" -> "finiteflow", "operation" -> "FFTogether",
    "parameter_count" -> Length[variables], "root_count" -> Length[roots],
    "elapsed_seconds" -> N[start - $Started]|>];
  result = Quiet @ Check[FiniteFlow`FFTogether[lifted, "Parameters" -> variables,
    "NThreads" -> $Threads, "MaxPrimes" -> $MaxPrimes], $Failed];
  emit[<|"event" -> "end", "id" -> id, "parent" -> $Parent, "phase" -> $Phase,
    "row" -> row, "column" -> column, "backend" -> "finiteflow", "operation" -> "FFTogether",
    "elapsed_seconds" -> N[AbsoluteTime[] - $Started], "operation_seconds" -> N[AbsoluteTime[] - start]|>];
  If[result === $Failed || !rationalQ[result] || !SubsetQ[variables, Variables[result]],
    abort["ARITHMETIC_RECONSTRUCTION_FAILED", "FFTogether did not return an exact rational expression; no fallback was used."]];
  result = result /. Thread[generators -> (Sqrt /@ roots)];
  If[!FreeQ[result, Indeterminate | _DirectedInfinity],
    abort["ARITHMETIC_RECONSTRUCTION_FAILED", "Restoring the declared quadratic generators produced an undefined expression."]];
  result
];

SetAttributes[CanonFFT`NormalizeMatrix, HoldAll];
fermatNormalize[matrix_] := Module[{frame, result, symbols, id, start},
  frame = CanonBlockArithmetic`FermatBlockFrame[{matrix}];
  If[FailureQ[frame], abort["UNSUPPORTED_ARITHMETIC_DOMAIN", frame[[2, "Message"]]]];
  id = ++$Counter; start = AbsoluteTime[];
  emit[<|"event" -> "start", "id" -> id, "parent" -> $Parent, "phase" -> $Phase,
    "backend" -> "fermat", "operation" -> "FermatBlockTogether", "dimensions" -> Dimensions[matrix],
    "root_count" -> Length[frame["bases"]], "elapsed_seconds" -> N[start - $Started]|>];
  result = CanonBlockArithmetic`FermatBlockTogether[frame, matrix];
  emit[<|"event" -> "end", "id" -> id, "parent" -> $Parent, "phase" -> $Phase,
    "backend" -> "fermat", "operation" -> "FermatBlockTogether",
    "elapsed_seconds" -> N[AbsoluteTime[] - $Started], "operation_seconds" -> N[AbsoluteTime[] - start]|>];
  If[FailureQ[result], abort["ARITHMETIC_NORMALIZATION_FAILED", result[[2, "Message"]]]];
  symbols = DeleteDuplicates[Cases[matrix, _Symbol, Infinity]];
  If[!MatrixQ[result] || Dimensions[result] =!= Dimensions[matrix] ||
    !FreeQ[result, Indeterminate | _DirectedInfinity | _Complex | _Root | _AlgebraicNumber] ||
    !AllTrue[Flatten[result], CanonMethodCard`ExactAlgebraicExpressionQ] ||
    Complement[DeleteDuplicates[Cases[result, _Symbol, Infinity]], symbols] =!= {},
    abort["ARITHMETIC_NORMALIZATION_FAILED", "Fermat did not return a defined exact matrix in the declared variables."]];
  result
];
flintNormalize[matrix_] := Module[{result, logger, directory},
  directory = FileNameJoin[{$Output, "flint-normalization-" <> ToString[$Parent]}];
  logger[label_, event_, details_] := emit[Join[<|"event" -> event, "parent" -> $Parent,
    "phase" -> $Phase, "backend" -> "flint", "operation" -> label,
    "elapsed_seconds" -> N[AbsoluteTime[]-$Started]|>, details]];
  result = If[$FlintSerializer===None,CanonFlintNormalize`Normalize[matrix, $FlintExecutable, directory, logger],
    CanonFlintNormalize`Normalize[matrix, $FlintExecutable, directory, logger, $FlintSerializer]];
  If[FailureQ[result], abort[If[result[[1]]==="UNSUPPORTED_FLINT_DOMAIN","UNSUPPORTED_ARITHMETIC_DOMAIN","ARITHMETIC_NORMALIZATION_FAILED"], result[[2,"Message"]]]];
  If[!AssociationQ[result] || !MatrixQ[result["matrix"]], abort["ARITHMETIC_NORMALIZATION_FAILED", "FLINT did not return a checked matrix."]];
  If[result["runtime","header_version"] =!= $Runtime["flint_runtime","header_version"] ||
     result["runtime","runtime_version"] =!= $Runtime["flint_runtime","runtime_version"],
    abort["ARITHMETIC_NORMALIZATION_FAILED", "Native operation version differs from initialized executable."]];
  result["matrix"]
];
CanonFFT`NormalizeMatrix[label_String, matrix_] := Module[{id, start, result, backend},
  If[!KeyExistsQ[$Backends, label],
    abort["INVALID_NORMALIZATION_BACKENDS", "NormalizeMatrix requires a declared construction phase."]];
  backend = $Backends[label];
  id = ++$Counter; start = AbsoluteTime[];
  emit[<|"event" -> "start", "id" -> id, "phase" -> label,
    "backend" -> backend, "elapsed_seconds" -> N[start - $Started]|>];
  result = Block[{$Backend = backend, $Parent = id, $Phase = label}, Switch[$Backend,
    "together", Map[Together, matrix, {2}],
    "finiteflow", MapIndexed[finiteNormalize[#1, Sequence @@ #2] &, matrix, {2}],
    "fermat", fermatNormalize[matrix],
    "flint", flintNormalize[matrix]]];
  emit[<|"event" -> "end", "id" -> id, "phase" -> label,
    "backend" -> backend, "elapsed_seconds" -> N[AbsoluteTime[] - $Started],
    "operation_seconds" -> N[AbsoluteTime[] - start]|>];
  result
];
End[];
EndPackage[];
