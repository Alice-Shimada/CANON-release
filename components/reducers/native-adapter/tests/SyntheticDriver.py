#!/usr/bin/env python3
"""A clearly labelled fixture operator for testing argv/export boundaries, never a native reducer."""
import json
from pathlib import Path
import shutil
import subprocess
import sys

context = json.loads(Path(sys.argv[1]).read_text())
backend_path = Path(context["backend"])
backend = json.loads(backend_path.read_text())
output = Path(context["output"])
if backend.get("test_prepare_driver"):
    subprocess.run([context["wolframscript"], "-file", str(Path(context["adapter_package"]) / "prepare.wls"), sys.argv[1]], check=True)
for name, source in backend["fixture_exports"][context["step"]].items():
    shutil.copyfile(backend_path.parent / source, output / name)
(output / "driver-receipt.json").write_text(json.dumps({"driver": "synthetic fixture exporter", "new_reduction_executed": False,
    "native_engine_executed": False, "test_only": True}) + "\n")
