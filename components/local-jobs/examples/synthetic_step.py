"""Short operational example; this computes no physical result."""

import json
from pathlib import Path
import sys
import time

request, output = map(Path, sys.argv[1:])
task = json.loads(request.read_text())
output.mkdir(parents=True)
time.sleep(0.1)
(output / "result.json").write_text(json.dumps({
    "schema": "canon-neu/script-result/v1", "task_id": task["task_id"], "step": task["step"],
    "status": "PROVISIONAL", "code": "SYNTHETIC_DEMO_FINISHED", "artifacts": {},
    "summary": {"synthetic": True, "scientific_acceptance": False},
}, indent=2) + "\n")
