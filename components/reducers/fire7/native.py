#!/usr/bin/env python3
"""FIRE7's documented CLI plus tables2rules; the caller supplies a matching .start file."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
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
        raise SystemExit("FIRE7 does not supply this driver's DE builder; configure an explicit full-DE export driver or select another component.")
    master_source = cfg["master_export"]
    if context["step"] == "DISCOVER":
        if master_source.get("base") != "output":
            raise SystemExit("FIRE DISCOVER requires master_export.base=output before any native launch.")
        if not (output / master_source["path"]).resolve().is_relative_to(output.resolve()):
            raise SystemExit("FIRE DISCOVER master_export.path must remain inside the native output directory.")
    subprocess.run([context["wolframscript"], "-file", str(Path(__file__).with_name("prepare.wls")), str(context_path)], check=True)
    shutil.copyfile(path(cfg["start_file"]), output / "family.start")
    family = cfg["encoding"]["family"]
    lines = ["#compressor none", f"#threads {cfg['threads']}", f"#fthreads {cfg['fthreads']}", "#variables " + ",".join(cfg["variables"])]
    lines += cfg.get("options", [])
    if context["step"] == "DISCOVER":
        lines.append("#masters")
    lines += ["#start", "#folder ./", f"#problem {family} family.start", "#integrals targets.m", "#preferred preferred.m", "#output reduction.tables"]
    (output / "reduction.config").write_text("\n".join(lines) + "\n")
    executable = str(path(cfg["executable"])) if "/" in cfg["executable"] or "\\" in cfg["executable"] else cfg["executable"]
    subprocess.run([executable, "--config", "reduction"], cwd=output, check=True)
    if context["step"] == "REDUCE_IBP":
        exporter = str(path(cfg["tables2rules"])) if "/" in cfg["tables2rules"] or "\\" in cfg["tables2rules"] else cfg["tables2rules"]
        subprocess.run([exporter, "reduction.tables", "rules.wl"], cwd=output, check=True)
    # A source master file is explicit because native master-file naming can vary by FIRE release/configuration.
    if master_source["base"] == "output":
        source = output / master_source["path"]
    elif master_source["base"] == "backend":
        source = path(master_source["path"])
    else:
        raise SystemExit("master_export.base must be output or backend")
    if source.resolve() != (output / "masters.wl").resolve():
        shutil.copyfile(source, output / "masters.wl")
    (output / "driver-receipt.json").write_text(json.dumps({"driver": "FIRE7 plus tables2rules", "declared_revision": cfg["software_revision"],
        "start_sha256": hashlib.sha256((output / "family.start").read_bytes()).hexdigest(), "master_export": master_source,
        "new_reduction_executed": context["step"] == "REDUCE_IBP",
        "scope": "configured native run; the normalizer still checks source basis and every requested target"}, indent=2) + "\n")


if __name__ == "__main__":
    main()
