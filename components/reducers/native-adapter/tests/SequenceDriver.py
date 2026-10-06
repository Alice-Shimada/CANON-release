#!/usr/bin/env python3
"""Test-only ordered fixture exporter; this program never runs a native solver."""
import json
from pathlib import Path
import shutil
import sys


context_path, action, expected_count, *arguments = sys.argv[1:]
context = json.loads(Path(context_path).read_text())
output = Path(context["output"])
trace_path = output / "sequence-trace.json"
trace = json.loads(trace_path.read_text()) if trace_path.exists() else []
assert len(trace) == int(expected_count)
assert Path.cwd() == output
trace.append({"action": action, "arguments": arguments, "cwd": str(Path.cwd())})
trace_path.write_text(json.dumps(trace, indent=2) + "\n")
print(action, arguments, flush=True)
if action == "fail":
    raise SystemExit(7)
if action == "export":
    backend_path = Path(context["backend"])
    backend = json.loads(backend_path.read_text())
    for filename, source in backend["fixture_exports"].items():
        shutil.copyfile(backend_path.parent / source, output / filename)
