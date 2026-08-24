#!/usr/bin/env python3
"""Behavior tests for update_redists.py."""

import functools
import hashlib
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import io
import json
import os
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

    def test_checked_in_catalog_has_all_supported_versions_and_complete_archives(self):
        expected_versions = [
            "2.25.1",
            "2.26.2",
            "2.26.5",
            "2.27.3",
            "2.27.5",
            "2.27.6",
            "2.27.7",
            "2.28.3",
            "2.28.7",
            "2.28.9",
            "2.29.2",
            "2.29.3",
            "2.29.7",
            "2.30.3",
            "2.30.4",
            "2.30.7",
            "2.31.2",
        ]
        catalog_path = Path(__file__).with_name("nccl_redist_versions.json")
        catalog = json.loads(catalog_path.read_text())

        self.assertEqual(expected_versions, list(catalog))
        archive_count = 0
        for nccl_version, cuda_families in catalog.items():
            for cuda_major, cuda_family in cuda_families.items():
                self.assertEqual(cuda_major, cuda_family["built_with_cuda"].split(".")[0])
                for cuda_minor in cuda_family["compatible_cuda"]:
                    self.assertEqual(cuda_major, cuda_minor.split(".")[0])
                self.assertEqual(
                    {"linux-sbsa", "linux-x86_64"},
                    set(cuda_family["archives"]),
                )
                for archive in cuda_family["archives"].values():
                    archive_count += 1
                    self.assertTrue(archive["relative_path"].startswith("nccl/v{}/".format(nccl_version)))
                    self.assertRegex(archive["sha256"], r"^[0-9a-f]{64}$")
                    self.assertTrue(archive["strip_prefix"])
        self.assertEqual(56, archive_count)

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

        workspace = self._root / "workspace"
        workspace.mkdir()
        output = workspace / "nccl" / "nccl_redist_versions.json"
        cache = self._root / "cache.json"
        environment = os.environ.copy()
        environment["BUILD_WORKSPACE_DIRECTORY"] = str(workspace)
        command = [
            sys.executable,
            str(Path(__file__).with_name("update_redists.py")),
            "--base-url",
            "http://127.0.0.1:{}/".format(self._server.server_port),
            "--cache",
            str(cache),
            "--max-workers",
            "2",
        ]
        subprocess.run(command, check=True, capture_output=True, env=environment, text=True)

        catalog = json.loads(output.read_text())
        self.assertEqual(["2.25.1", "2.31.2"], list(catalog))
        self.assertEqual("12.8", catalog["2.25.1"]["12"]["built_with_cuda"])
        self.assertEqual("13.3", catalog["2.31.2"]["13"]["built_with_cuda"])
        new_x86 = catalog["2.31.2"]["13"]["archives"]["linux-x86_64"]
        self.assertEqual(new_prefix, new_x86["strip_prefix"])
        old_x86_entry = catalog["2.25.1"]["12"]["archives"]["linux-x86_64"]
        self.assertEqual(hashlib.sha256(old_x86.read_bytes()).hexdigest(), old_x86_entry["sha256"])

        subprocess.run(
            command + ["--check"],
            check=True,
            capture_output=True,
            env=environment,
            text=True,
        )


if __name__ == "__main__":
    unittest.main()
