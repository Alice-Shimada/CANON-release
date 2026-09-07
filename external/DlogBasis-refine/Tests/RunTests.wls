#!/usr/bin/env wolframscript

testDirectory = DirectoryName[$InputFileName];
arguments = Rest[$ScriptCommandLine];
If[Length[arguments] =!= 1,
  Print["usage: wolframscript -file Tests/RunTests.wls /path/to/FiniteFlow.m"];
  Exit[64]
];
finiteFlowFile = First[arguments];
SetEnvironment["DLOGBASIS_TEST_DIRECTORY" -> testDirectory];
SetEnvironment["DLOGBASIS_FINITEFLOW_FILE" -> finiteFlowFile];
report = TestReport[FileNameJoin[{testDirectory, "UnitTests.wlt"}]];
Print[InputForm[<|
  "TestsSucceeded" -> report["TestsSucceededCount"],
  "TestsFailed" -> report["TestsFailedCount"]
|>]];
Exit[If[report["TestsFailedCount"] === 0, 0, 1]];
