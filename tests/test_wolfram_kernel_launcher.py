from __future__ import annotations

import ctypes
import errno
import os
import unittest

from tests.wolfram_kernel_launcher import unlink_stale_libomp_registration


class WolframKernelLauncherTest(unittest.TestCase):
    def test_unlinks_only_the_requested_pid_registration(self) -> None:
        pid = os.getpid()
        name = f"/__KMP_REGISTERED_LIB_{pid}".encode("ascii")
        libc = ctypes.CDLL(None, use_errno=True)
        shm_open = libc.shm_open
        shm_open.argtypes = [ctypes.c_char_p, ctypes.c_int, ctypes.c_uint]
        shm_open.restype = ctypes.c_int
        shm_unlink = libc.shm_unlink
        shm_unlink.argtypes = [ctypes.c_char_p]
        shm_unlink.restype = ctypes.c_int
        # PID reuse may leave exactly the stale object the launcher handles.
        # Prepare our own PID only before constructing the controlled fixture.
        try:
            unlink_stale_libomp_registration(pid)
        except OSError as exc:
            if exc.errno == errno.EACCES:
                self.skipTest("sandbox does not permit caller-owned POSIX SHM")
            raise
        fd = shm_open(name, os.O_CREAT | os.O_EXCL | os.O_RDWR, 0o600)
        if fd == -1:
            error = ctypes.get_errno()
            if error == errno.EACCES:
                self.skipTest("sandbox does not permit caller-owned POSIX SHM")
            self.fail(f"shm_open failed: {os.strerror(error)}")
        os.close(fd)
        try:
            unlink_stale_libomp_registration(pid)
            self.assertEqual(shm_unlink(name), -1)
            self.assertEqual(ctypes.get_errno(), errno.ENOENT)
            unlink_stale_libomp_registration(pid)
        finally:
            shm_unlink(name)


if __name__ == "__main__":
    unittest.main()
