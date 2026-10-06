"""Accept an event in a local fake session. This contacts no agent host."""

import fcntl
import json
import os
from pathlib import Path
import sys
import uuid

database, event_path = map(Path, sys.argv[1:])
event = json.loads(event_path.read_text())
database.parent.mkdir(parents=True, exist_ok=True)
with database.with_suffix(".lock").open("a") as stream:
    fcntl.flock(stream, fcntl.LOCK_EX)
    state = json.loads(database.read_text()) if database.exists() else {"accepted": {}}
    state["accepted"].setdefault(event["event_id"], {"target": event["target"], "outcome": event["outcome"]})
    temporary = database.with_name("." + database.name + "." + uuid.uuid4().hex)
    with temporary.open("x") as saved:
        json.dump(state, saved, indent=2)
        saved.flush()
        os.fsync(saved.fileno())
    os.replace(temporary, database)
    directory = os.open(database.parent, os.O_RDONLY)
    try:
        os.fsync(directory)
    finally:
        os.close(directory)
print(json.dumps({"event_id": event["event_id"], "accepted": True, "fake_session": True}))
