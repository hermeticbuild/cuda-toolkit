#!/usr/bin/env python3
"""Behavior tests for update_redists.py."""

import functools
import hashlib
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import io
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import threading
import unittest


class _QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass


class UpdateRedistsTest(unittest.TestCase):
    def setUp(self):
        self._temporary_directory = tempfile.TemporaryDirectory()
        self._root = Path(self._temporary_directory.name)
        handler = functools.partial(_QuietHandler, directory=self._root)
        self._server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
        self._server_thread = threading.Thread(target=self._server.serve_forever, daemon=True)
        self._server_thread.start()

    def tearDown(self):
        self._server.shutdown()
        self._server.server_close()
        self._server_thread.join()
        self._temporary_directory.cleanup()

    def _archive(self, version, filename, mode):
        directory = self._root / "v{}".format(version)
        directory.mkdir(exist_ok=True)
        path = directory / filename
        strip_prefix = filename.removesuffix(".tar.gz").removesuffix(".txz")
        with tarfile.open(path, mode) as archive:
            root = tarfile.TarInfo(strip_prefix)
            root.type = tarfile.DIRTYPE
            archive.addfile(root)
            contents = b"fixture\n"
            header = tarfile.TarInfo(strip_prefix + "/include/nccl.h")
            header.size = len(contents)
            archive.addfile(header, io.BytesIO(contents))
        return path, strip_prefix

    def test_generates_and_checks_old_and_new_archive_families(self):
        old_x86, _ = self._archive(
            "2.25.1",
            "nccl_2.25.1_cuda12.8_x86_64.txz",
            "w:xz",
        )
        self._archive(
            "2.25.1",
            "nccl_2.25.1_cuda12.8_aarch64.txz",
            "w:xz",
        )
        _, new_prefix = self._archive(
            "2.31.2",
            "nccl-nccl-stable-cuda-13-linux-x86_64-2.31.2-cuda13.3.tar.gz",
            "w:gz",
        )
        self._archive(
            "2.31.2",
            "nccl-nccl-stable-cuda-13-linux-sbsa-2.31.2-cuda13.3.tar.gz",
            "w:gz",
        )

        output = self._root / "catalog.bzl"
        cache = self._root / "cache.json"
        command = [
            sys.executable,
            str(Path(__file__).with_name("update_redists.py")),
            "--base-url",
            "http://127.0.0.1:{}/".format(self._server.server_port),
            "--cache",
            str(cache),
            "--max-workers",
            "2",
            "--output",
            str(output),
        ]
        subprocess.run(command, check=True, capture_output=True, text=True)

        catalog = output.read_text()
        self.assertIn('"2.25.1"', catalog)
        self.assertIn('"2.31.2"', catalog)
        self.assertIn('"built_with_cuda": "12.8"', catalog)
        self.assertIn('"built_with_cuda": "13.3"', catalog)
        self.assertIn('"strip_prefix": "{}"'.format(new_prefix), catalog)
        self.assertIn(hashlib.sha256(old_x86.read_bytes()).hexdigest(), catalog)

        subprocess.run(command + ["--check"], check=True, capture_output=True, text=True)


if __name__ == "__main__":
    unittest.main()
