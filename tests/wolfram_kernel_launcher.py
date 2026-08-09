#!/usr/bin/env python3
"""Fail-closed exec launcher for Mathematica's PID-named libomp registration."""

from __future__ import annotations

import ctypes
import errno
import os
from pathlib import Path
import sys


def unlink_stale_libomp_registration(pid: int) -> None:
    """Remove only this future kernel PID's stale libomp registration object."""
    name = f"/__KMP_REGISTERED_LIB_{pid}".encode("ascii")
    libc = ctypes.CDLL(None, use_errno=True)
    shm_unlink = libc.shm_unlink
    shm_unlink.argtypes = [ctypes.c_char_p]
    shm_unlink.restype = ctypes.c_int
    if shm_unlink(name) == 0:
        return
    error = ctypes.get_errno()
    if error != errno.ENOENT:
        raise OSError(error, os.strerror(error), name.decode("ascii"))


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(f"usage: {Path(argv[0]).name} WOLFRAM_KERNEL [ARG ...]", file=sys.stderr)
        return 64
    kernel = Path(argv[1])
    if not kernel.is_absolute() or not kernel.is_file():
        print(f"invalid WolframKernel path: {kernel}", file=sys.stderr)
        return 66
    try:
        unlink_stale_libomp_registration(os.getpid())
    except OSError as exc:
        print(f"refusing WolframKernel exec: stale libomp registration cleanup failed: {exc}", file=sys.stderr)
        return 73
    os.execve(str(kernel), [str(kernel), *argv[2:]], os.environ.copy())
    return 127


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
