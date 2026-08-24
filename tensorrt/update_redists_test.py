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

    def _archive(self, version, full_version, filename):
        directory = self._root / version / "tars"
        directory.mkdir(parents=True, exist_ok=True)
        path = directory / filename
        strip_prefix = "TensorRT-{}".format(full_version)
        with tarfile.open(path, "w:gz") as archive:
            root = tarfile.TarInfo(strip_prefix)
            root.type = tarfile.DIRTYPE
            archive.addfile(root)
            contents = b"fixture\n"
            header = tarfile.TarInfo(strip_prefix + "/include/NvInferVersion.h")
            header.size = len(contents)
            archive.addfile(header, io.BytesIO(contents))
        return path, strip_prefix

    def test_checked_in_catalog_has_all_known_releases_and_complete_archives(self):
        expected_versions = [
            "10.16.0",
        ]
        catalog_path = Path(__file__).with_name("tensorrt_redist_versions.json")
        catalog = json.loads(catalog_path.read_text())

        self.assertEqual(expected_versions, list(catalog))
        archive_count = 0
        for tensorrt_version, cuda_families in catalog.items():
            for cuda_major, cuda_family in cuda_families.items():
                self.assertEqual(cuda_major, cuda_family["built_with_cuda"].split(".")[0])
                self.assertTrue(cuda_family["full_version"].startswith(tensorrt_version + "."))
                for cuda_minor in cuda_family["compatible_cuda"]:
                    self.assertEqual(cuda_major, cuda_minor.split(".")[0])
                self.assertIn("linux-x86_64", cuda_family["archives"])
                self.assertLessEqual(
                    set(cuda_family["archives"]),
                    {"linux-sbsa", "linux-x86_64"},
                )
                for archive in cuda_family["archives"].values():
                    archive_count += 1
                    self.assertTrue(
                        archive["relative_path"].startswith(
                            "{}/tars/TensorRT-{}.".format(
                                tensorrt_version,
                                cuda_family["full_version"],
                            ),
                        ),
                    )
                    self.assertRegex(archive["sha256"], r"^[0-9a-f]{64}$")
                    self.assertEqual(
                        "TensorRT-{}".format(cuda_family["full_version"]),
                        archive["strip_prefix"],
                    )
        self.assertEqual(3, archive_count)

    def test_generates_and_checks_probed_archive_families(self):
        cuda_12_x86, _ = self._archive(
            "10.16.0",
            "10.16.0.72",
            "TensorRT-10.16.0.72.Linux.x86_64-gnu.cuda-12.9.tar.gz",
        )
        self._archive(
            "10.16.0",
            "10.16.0.72",
            "TensorRT-10.16.0.72.Linux.x86_64-gnu.cuda-13.2.tar.gz",
        )
        # Exercises the sbsa file name pattern fallback; no cuda-12 sbsa
        # archive exists, so the cuda-12 family must stay x86_64 only.
        _, sbsa_prefix = self._archive(
            "10.16.0",
            "10.16.0.72",
            "TensorRT-10.16.0.72.Ubuntu-24.04.aarch64-gnu.cuda-13.2.tar.gz",
        )

        workspace = self._root / "workspace"
        workspace.mkdir()
        output = workspace / "tensorrt" / "tensorrt_redist_versions.json"
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
        self.assertEqual(["10.16.0"], list(catalog))
        self.assertEqual("12.9", catalog["10.16.0"]["12"]["built_with_cuda"])
        self.assertEqual("13.2", catalog["10.16.0"]["13"]["built_with_cuda"])
        self.assertEqual(["linux-x86_64"], list(catalog["10.16.0"]["12"]["archives"]))
        self.assertEqual(
            ["linux-sbsa", "linux-x86_64"],
            list(catalog["10.16.0"]["13"]["archives"]),
        )
        sbsa_entry = catalog["10.16.0"]["13"]["archives"]["linux-sbsa"]
        self.assertEqual(sbsa_prefix, sbsa_entry["strip_prefix"])
        self.assertTrue(sbsa_entry["relative_path"].endswith("Ubuntu-24.04.aarch64-gnu.cuda-13.2.tar.gz"))
        cuda_12_x86_entry = catalog["10.16.0"]["12"]["archives"]["linux-x86_64"]
        self.assertEqual(
            hashlib.sha256(cuda_12_x86.read_bytes()).hexdigest(),
            cuda_12_x86_entry["sha256"],
        )

        subprocess.run(
            command + ["--check"],
            check=True,
            capture_output=True,
            env=environment,
            text=True,
        )


if __name__ == "__main__":
    unittest.main()
