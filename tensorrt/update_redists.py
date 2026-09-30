#!/usr/bin/env python3
"""Generate the checked-in TensorRT redistribution catalog from NVIDIA archives.

NVIDIA publishes neither redistrib manifests nor a browsable archive index for
TensorRT, so the GA releases are declared in KNOWN_RELEASES below and every
declared archive is probed and verified against the download host. Adding a
release means adding one KNOWN_RELEASES entry and rerunning the tool.

TensorRT is distributed under the NVIDIA TensorRT Supplement to the NVIDIA
Software License Agreement.
"""

import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import sys
import tarfile
import tempfile
import time
from urllib.error import HTTPError
from urllib.request import Request, urlopen


DEFAULT_TENSORRT_REDIST_URL = "https://developer.download.nvidia.com/compute/machine-learning/tensorrt/"

# Each TensorRT release is built once per CUDA major; cuda_builds records the
# exact CUDA minor each build was compiled against (which appears in the
# tarball file name). NVIDIA's support matrix documents each build as
# compatible with its CUDA major line only ("Built with CUDA Toolkit 13.2.
# Compatible with CUDA 13.x versions only.").
KNOWN_RELEASES = {
    "10.16.0": {
        "full_version": "10.16.0.72",
        "cuda_builds": {"12": "12.9", "13": "13.2"},
    },
}
SUPPORTED_CUDA_MINORS = {
    "12": ["12.8", "12.9"],
    "13": ["13.0", "13.1", "13.2", "13.3"],
}

# The GA tarball naming convention changed across releases for Linux sbsa
# (older releases published Ubuntu-*.aarch64-gnu tarballs); the first pattern
# that exists on the download host wins. The x86_64 tarball must exist for
# every declared CUDA build; NVIDIA does not publish an sbsa tarball for every
# build (for example the 10.16.0 cuda-12 build is x86_64 only), so sbsa is
# optional.
PLATFORM_FILENAME_PATTERNS = {
    "linux-sbsa": [
        "TensorRT-{full_version}.Linux.aarch64-gnu.cuda-{cuda_build}.tar.gz",
        "TensorRT-{full_version}.Ubuntu-24.04.aarch64-gnu.cuda-{cuda_build}.tar.gz",
        "TensorRT-{full_version}.Ubuntu-22.04.aarch64-gnu.cuda-{cuda_build}.tar.gz",
        "TensorRT-{full_version}.Ubuntu-20.04.aarch64-gnu.cuda-{cuda_build}.tar.gz",
    ],
    "linux-x86_64": [
        "TensorRT-{full_version}.Linux.x86_64-gnu.cuda-{cuda_build}.tar.gz",
    ],
}
REQUIRED_PLATFORMS = ["linux-x86_64"]
USER_AGENT = "hermeticbuild-cuda-toolkit-tensorrt-catalog/1"


class _RangeReader:
    def __init__(self, url, chunk_size=32 * 1024 * 1024):
        self._url = url
        self._chunk_size = chunk_size
        self._position = 0
        self._buffer = b""
        self._digest = hashlib.sha256()
        request = Request(
            url,
            headers={"Accept-Encoding": "identity", "User-Agent": USER_AGENT},
            method="HEAD",
        )
        with urlopen(request, timeout=60) as response:
            self._length = int(response.headers["Content-Length"])
            self._etag = response.headers.get("ETag")

    def _fetch(self):
        start = self._position
        end = min(start + self._chunk_size, self._length) - 1
        headers = {
            "Accept-Encoding": "identity",
            "Range": "bytes={}-{}".format(start, end),
            "User-Agent": USER_AGENT,
        }
        if self._etag:
            headers["If-Match"] = self._etag

        for attempt in range(1, 11):
            try:
                request = Request(self._url, headers=headers)
                with urlopen(request, timeout=120) as response:
                    data = response.read()
                    status = response.status
                if status == 200 and start == 0 and len(data) == self._length:
                    self._buffer = data
                    return
                if status != 206:
                    raise ValueError("Expected HTTP 206, got {}".format(status))
                if len(data) != end - start + 1:
                    raise ValueError(
                        "Expected bytes {}-{}, received {} bytes".format(start, end, len(data)),
                    )
                self._buffer = data
                return
            except Exception:
                if attempt == 10:
                    raise
                time.sleep(min(2 ** attempt, 30))

    def read(self, size=-1):
        if self._position >= self._length:
            return b""
        if size < 0:
            size = self._length - self._position

        output = []
        remaining = min(size, self._length - self._position)
        while remaining:
            if not self._buffer:
                self._fetch()
            count = min(remaining, len(self._buffer))
            output.append(self._buffer[:count])
            self._buffer = self._buffer[count:]
            self._position += count
            remaining -= count
        data = b"".join(output)
        self._digest.update(data)
        return data

    def hexdigest(self):
        if self._position != self._length:
            raise ValueError("Archive stream is incomplete")
        return self._digest.hexdigest()


def _version_tuple(version):
    return tuple(int(part) for part in version.split("."))


def _url_exists(url):
    request = Request(url, headers={"User-Agent": USER_AGENT}, method="HEAD")
    try:
        with urlopen(request, timeout=60) as response:
            return response.status == 200
    except HTTPError as error:
        if error.code in (403, 404):
            return False
        raise


def _archive_candidates(version, release, base_url):
    full_version = release["full_version"]
    selected = {}
    for cuda_major, cuda_build in sorted(release["cuda_builds"].items()):
        if cuda_major not in SUPPORTED_CUDA_MINORS:
            raise SystemExit(
                "TensorRT {} declares unsupported CUDA major {}".format(version, cuda_major),
            )
        archives = {}
        for platform, patterns in PLATFORM_FILENAME_PATTERNS.items():
            for pattern in patterns:
                filename = pattern.format(full_version=full_version, cuda_build=cuda_build)
                relative_path = "{}/tars/{}".format(version, filename)
                url = base_url + relative_path
                if _url_exists(url):
                    archives[platform] = {
                        "filename": filename,
                        "relative_path": relative_path,
                        "url": url,
                        "version": version,
                    }
                    break
        missing_platforms = [
            platform
            for platform in REQUIRED_PLATFORMS
            if platform not in archives
        ]
        if missing_platforms:
            raise SystemExit(
                "TensorRT {} cuda-{} archives missing for {}".format(
                    version, cuda_build, missing_platforms,
                ),
            )
        selected[cuda_major] = {
            "archives": archives,
            "built_with_cuda": cuda_build,
            "full_version": full_version,
        }
    return selected


def _inspect_archive_once(archive):
    layout_reader = _RangeReader(archive["url"], chunk_size=8 * 1024 * 1024)
    with tarfile.open(fileobj=layout_reader, mode="r|*") as tar:
        first_member = next(iter(tar), None)
        if first_member is None:
            raise ValueError("Archive is empty")
        first_name = first_member.name.removeprefix("./")
        strip_prefix = first_name.split("/", 1)[0]

    if not strip_prefix:
        raise ValueError("Archive does not have a top-level directory")

    reader = _RangeReader(archive["url"])
    while reader.read(1024 * 1024):
        pass

    return {
        "sha256": reader.hexdigest(),
        "strip_prefix": strip_prefix,
    }


def _inspect_archive(archive):
    for attempt in range(1, 6):
        try:
            return _inspect_archive_once(archive)
        except Exception as error:
            if attempt == 5:
                raise
            print(
                "Retrying {} after attempt {}: {}".format(archive["url"], attempt, error),
                file=sys.stderr,
                flush=True,
            )
            time.sleep(min(2 ** attempt, 30))


def _load_cache(path):
    if not path.exists():
        return {}
    return json.loads(path.read_text())


def _write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_path = tempfile.mkstemp(prefix=path.name + ".", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w") as output:
            json.dump(value, output, indent=2, sort_keys=True)
            output.write("\n")
        os.replace(temporary_path, path)
    except Exception:
        os.unlink(temporary_path)
        raise


def _catalog_text(catalog):
    return json.dumps(catalog, indent=2) + "\n"


def _default_output():
    workspace_directory = os.environ.get("BUILD_WORKSPACE_DIRECTORY")
    if workspace_directory:
        return Path(workspace_directory) / "tensorrt" / "tensorrt_redist_versions.json"
    return Path(__file__).with_name("tensorrt_redist_versions.json")


def _write_catalog(path, catalog, check):
    content = _catalog_text(catalog)
    if check:
        if not path.exists() or path.read_text() != content:
            raise SystemExit("{} is out of date".format(path))
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_path = tempfile.mkstemp(prefix=path.name + ".", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w") as output:
            output.write(content)
        os.replace(temporary_path, path)
    except Exception:
        os.unlink(temporary_path)
        raise


def _parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--base-url",
        default=DEFAULT_TENSORRT_REDIST_URL,
        help="NVIDIA-compatible download root; primarily useful for hermetic tests.",
    )
    parser.add_argument(
        "--cache",
        type=Path,
        default=Path(tempfile.gettempdir()) / "cuda-toolkit-tensorrt-redists-cache.json",
        help="Local inspection cache; defaults outside the repository.",
    )
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--max-workers", type=int, default=2)
    parser.add_argument(
        "--output",
        type=Path,
        default=_default_output(),
    )
    parser.add_argument(
        "--refresh",
        action="store_true",
        help="Ignore cached archive inspections and verify every archive again.",
    )
    parser.add_argument(
        "--version",
        action="append",
        dest="versions",
        help="Generate only this TensorRT version; may be repeated.",
    )
    return parser.parse_args()


def main():
    args = _parse_args()
    base_url = args.base_url.rstrip("/") + "/"
    versions = args.versions or sorted(KNOWN_RELEASES, key=_version_tuple)
    missing_versions = sorted(set(versions) - set(KNOWN_RELEASES))
    if missing_versions:
        raise SystemExit("Unknown TensorRT versions: {}".format(missing_versions))

    selections = {}
    archives_to_inspect = []
    for version in versions:
        selected = _archive_candidates(version, KNOWN_RELEASES[version], base_url)
        if not selected:
            raise SystemExit("No supported CUDA archives found for TensorRT {}".format(version))
        selections[version] = selected
        for cuda_family in selected.values():
            archives_to_inspect.extend(cuda_family["archives"].values())

    cache = _load_cache(args.cache)
    uncached = {
        archive["url"]: archive
        for archive in archives_to_inspect
        if args.refresh or archive["url"] not in cache
    }
    print(
        "Inspecting {} archives ({} cached)".format(len(uncached), len(archives_to_inspect) - len(uncached)),
        file=sys.stderr,
        flush=True,
    )
    failures = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.max_workers) as executor:
        futures = {
            executor.submit(_inspect_archive, archive): url
            for url, archive in uncached.items()
        }
        for future in concurrent.futures.as_completed(futures):
            url = futures[future]
            try:
                cache[url] = future.result()
            except Exception as error:
                failures.append((url, error))
                print("Failed {}: {}".format(url, error), file=sys.stderr, flush=True)
                continue
            _write_json(args.cache, cache)
            print("Inspected {}".format(url), file=sys.stderr, flush=True)

    if failures:
        raise SystemExit(
            "Failed to inspect {} archives; rerun to resume from {}".format(len(failures), args.cache),
        )

    catalog = {}
    for version in versions:
        catalog[version] = {}
        for cuda_major, cuda_family in sorted(selections[version].items()):
            entry = {
                "archives": {},
                "built_with_cuda": cuda_family["built_with_cuda"],
                "compatible_cuda": SUPPORTED_CUDA_MINORS[cuda_major],
                "full_version": cuda_family["full_version"],
            }
            for platform in sorted(cuda_family["archives"]):
                archive = cuda_family["archives"][platform]
                inspection = cache[archive["url"]]
                entry["archives"][platform] = {
                    "relative_path": archive["relative_path"],
                    "sha256": inspection["sha256"],
                    "strip_prefix": inspection["strip_prefix"],
                }
            catalog[version][cuda_major] = entry

    _write_catalog(args.output, catalog, args.check)


if __name__ == "__main__":
    main()
