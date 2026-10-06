#!/usr/bin/env python3
"""Optional local jobs and completion-only command callbacks."""

from pathlib import Path
import subprocess
import sys

import jobs
from support import envelope, process_capability, read
import watches


def main(argv):
    if argv[0] == "--supervise":
        jobs.supervise(Path(argv[1]).resolve())
        return 0
    if argv[0] == "--monitor":
        watches.monitor(Path(argv[1]).resolve())
        return 0
    canon, request, output = map(lambda value: Path(value).resolve(), argv)
    task = read(request)
    output.mkdir(parents=True, exist_ok=True)
    try:
        process_capability()
        if task["schema"] != "canon-neu/script-input/v1":
            raise ValueError("unsupported request schema")
        if task["step"] == "SUBMIT_JOB":
            return jobs.submit(canon, request, task, output)
        action = {"COLLECT_JOB": jobs.collect, "CANCEL_JOB": jobs.cancel,
                  "WATCH_COMPLETION": watches.watch, "CANCEL_WATCH": watches.cancel}[task["step"]]
        return action(request, task, output)
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as exc:
        return envelope(task, output, "ERROR", "LOCAL_OPERATION_ERROR", reason=str(exc))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
