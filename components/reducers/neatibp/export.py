#!/usr/bin/env python3
"""Export an already solved NeatIBP/Kira result; never turn generated IBPs into reduction success."""
import json
from pathlib import Path
import shutil
import sys


def main():
    context_path = Path(sys.argv[1]).resolve()
    context = json.loads(context_path.read_text())
    backend_path = Path(context["backend"])
    cfg = json.loads(backend_path.read_text())
    output = Path(context["output"])

    def path(value):
        p = Path(value)
        return p if p.is_absolute() else (backend_path.parent / p).resolve()

    if context["step"] == "BUILD_CUT_DE":
        raise SystemExit("NeatIBP's equation generator is not a DE exporter; configure an explicit solver/DE driver.")
    # No source tree is copied. A new native generation/solve campaign belongs in caller-supplied argv.
    result = path(cfg["solved_output"])
    if context["step"] == "REDUCE_IBP":
        solver = cfg.get("solver", {})
        if solver.get("kind") != "Kira" or not solver.get("completed", False):
            raise SystemExit("A completed explicit solver export is required; IBP_all.txt is insufficient.")
        table = result / "results" / "Kira_reduction_results" / "reduced_IBP_Table.txt"
        shutil.copyfile(table, output / "rules.wl")
    shutil.copyfile(result / "results" / "MI_all.txt", output / "masters.wl")
    (output / "driver-receipt.json").write_text(json.dumps({"driver": "NeatIBP solved-output export", "declared_revision": cfg["software_revision"],
        "solver": cfg.get("solver"), "new_equations_generated": False, "new_reduction_executed": False}, indent=2) + "\n")


if __name__ == "__main__":
    main()
