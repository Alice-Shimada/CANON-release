#!/usr/bin/env wolframscript
$HistoryLength = 0;
work = First[Rest[$ScriptCommandLine]];
zero[q_] := TrueQ[Together[q] === 0];
facts = <||>;
Do[
  expected = Get[FileNameJoin[{work, chart, "expected.wl"}]];
  Do[
    reduced = Get[FileNameJoin[{work, chart, adapter <> "-reduce", "ibp-reduction.wl"}]];
    ordered = Get[FileNameJoin[{work, chart, adapter <> "-de", "ordered-master-de.wl"}]];
    cut = Get[FileNameJoin[{work, chart, adapter <> "-de", "sector-cut-de.wl"}]];
    discovered = Get[FileNameJoin[{work, chart, adapter <> "-discover", "master-basis.wl"}]];
    AppendTo[facts, chart <> "/" <> adapter <> "/source-order" -> (reduced["masters"] === expected["masters"] === ordered["basis"])];
    AppendTo[facts, chart <> "/" <> adapter <> "/all-targets" -> (First /@ reduced["rules"] === First /@ expected["rules"] && AllTrue[Last /@ reduced["rules"] - (Last /@ expected["rules"]), zero])];
    AppendTo[facts, chart <> "/" <> adapter <> "/all-directions" -> (ordered["variables"] === expected["variables"] && AllTrue[Flatten[ordered["matrices"] - expected["matrices"]], zero])];
    AppendTo[facts, chart <> "/" <> adapter <> "/sector-cut" -> (cut["basis"] === expected["masters"][[{2, 3}]] &&
      AllTrue[Flatten[cut["matrices"] - (#[[{2, 3}, {2, 3}]] & /@ expected["matrices"])], zero] && Length[cut["proper_subsectors"]] === 1)];
    AppendTo[facts, chart <> "/" <> adapter <> "/native-order-in-sector" -> (discovered["masters"] === expected["masters"][[{1, 3, 2}]])],
    {adapter, {"blade", "fire7", "neatibp"}}], {chart, {"base", "alternate"}}];
expected = Get[FileNameJoin[{work, "base", "expected.wl"}]];
reduced = Get[FileNameJoin[{work, "conversion", "blade-reduce", "ibp-reduction.wl"}]];
ordered = Get[FileNameJoin[{work, "conversion", "blade-de", "ordered-master-de.wl"}]];
AppendTo[facts, "explicit-conversion/rules" -> AllTrue[Last /@ reduced["rules"] - Last /@ expected["rules"], zero]];
AppendTo[facts, "explicit-conversion/derivative-term" -> AllTrue[Flatten[ordered["matrices"] - expected["matrices"]], zero]];
dimensionMapped = Get[FileNameJoin[{work, "dimension-rule", "blade-de", "ordered-master-de.wl"}]];
AppendTo[facts, "dimension-rule/d-to-epsilon" -> (FreeQ[dimensionMapped["matrices"], d] && AllTrue[Flatten[dimensionMapped["matrices"] - expected["matrices"]], zero])];
targets = Get[FileNameJoin[{work, "driver", "fire7-reduce", "native", "targets.m"}]];
AppendTo[facts, "fire-input/target-encoding" -> (targets === {{7, {2, 1, 0}}, {7, {1, 2, -1}}, {7, {0, 0, 0}}, {7, {1, 0, 0}}})];
Get[FileNameJoin[{work, "driver", "neatibp-reduce", "native", "kinematics.txt"}]];
AppendTo[facts, "neatibp-input/scientific-chart" -> (LoopMomenta === {l} && Propagators === {l^2, (l - p)^2, (l - q)^2} && Kinematics === {p^2 -> x, q^2 -> y, p q -> 0})];
AppendTo[facts, "neatibp-input/target-encoding" -> (Get[FileNameJoin[{work, "driver", "neatibp-reduce", "native", "targetIntegrals.txt"}]] === {G[2, 1, 0], G[1, 2, -1], G[0, 0, 0], G[1, 0, 0]})];
Export[FileNameJoin[{work, "artifact-checks.json"}], facts, "RawJSON"];
If[!And @@ Values[facts], Print[facts]; Exit[1]];
