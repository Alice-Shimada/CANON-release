BeginPackage["CanonNativeAdapter`"];
NormalizeStep::usage = "NormalizeStep[input, output, runtime] imports one explicitly declared native export.";
DriverInputs::usage = "DriverInputs[contextJSON] returns bound scientific inputs and explicitly encoded native targets for a configured driver.";
Begin["`Private`"];

With[{directory = FileNameJoin[{DirectoryName[$InputFileName], "lib"}]},
  Scan[Get[FileNameJoin[{directory, #}]] &,
    {"Inputs.wl", "Basis.wl", "Discovery.wl", "Reduction.wl", "DifferentialEquations.wl", "Normalization.wl"}]
];

End[];
EndPackage[];
