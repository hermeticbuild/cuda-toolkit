#!/usr/bin/env python3
"""Generate the checked-in NCCL redistribution catalog from NVIDIA archives."""

import argparse
import concurrent.futures
import hashlib
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import re
import sys
import tarfile
import tempfile
import time
from urllib.parse import urljoin
from urllib.request import Request, urlopen


DEFAULT_NCCL_REDIST_URL = "https://developer.download.nvidia.com/compute/redist/nccl/"
MINIMUM_NCCL_VERSION = (2, 25, 1)
SUPPORTED_CUDA_MINORS = {
    "12": ["12.8", "12.9"],
    "13": ["13.0", "13.1", "13.2", "13.3"],
}
PLATFORMS = ["linux-sbsa", "linux-x86_64"]
USER_AGENT = "hermeticbuild-cuda-toolkit-nccl-catalog/1"


class _LinkParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []

    def handle_starttag(self, tag, attrs):
        if tag != "a":
            return
        href = dict(attrs).get("href")
        if href:
            self.links.append(href)


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


def _fetch_text(url):
    request = Request(url, headers={"User-Agent": USER_AGENT})
    with urlopen(request, timeout=60) as response:
        return response.read().decode("utf-8")


def _links(url):
    parser = _LinkParser()
    parser.feed(_fetch_text(url))
    return parser.links


def _version_tuple(version):
    return tuple(int(part) for part in version.split("."))


def _available_version_directories(base_url):
    versions = {}
    for href in _links(base_url):
        match = re.fullmatch(r"v(\d+\.\d+\.\d+)/", href)
        if not match:
            continue
        version = match.group(1)
        if _version_tuple(version) >= MINIMUM_NCCL_VERSION:
            versions[version] = href
    return versions


def _archive_platform(filename):
    if "linux-sbsa" in filename or "_aarch64." in filename:
        return "linux-sbsa"
    if "linux-x86_64" in filename or "_x86_64." in filename:
        return "linux-x86_64"
    return None


def _archive_extension(filename):
    for extension in [".tar.gz", ".tar.xz", ".txz"]:
        if filename.endswith(extension):
            return extension
    return None


def _archive_candidates(version, directory, base_url):
    directory_url = urljoin(base_url, directory)
    candidates = {}
    for href in _links(directory_url):
        filename = href.rsplit("/", 1)[-1]
        extension = _archive_extension(filename)
        platform = _archive_platform(filename)
        cuda_match = re.search(r"cuda(\d+\.\d+)", filename)
        if not extension or not platform or not cuda_match:
            continue

        cuda_minor = cuda_match.group(1)
        cuda_major = cuda_minor.split(".", 1)[0]
        if cuda_minor not in SUPPORTED_CUDA_MINORS.get(cuda_major, []):
            continue

        candidates.setdefault(cuda_minor, {})[platform] = {
            "filename": filename,
            "relative_path": "nccl/{}/{}".format(directory.rstrip("/"), filename),
            "url": urljoin(directory_url, href),
            "version": version,
        }

    selected = {}
    for cuda_major in SUPPORTED_CUDA_MINORS:
        variants = [
            cuda_minor
            for cuda_minor, archives in candidates.items()
            if cuda_minor.startswith(cuda_major + ".") and all(
                platform in archives
                for platform in PLATFORMS
            )
        ]
        if variants:
            selected[cuda_major] = candidates[max(variants, key=_version_tuple)]
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
        return Path(workspace_directory) / "nccl" / "nccl_redist_versions.json"
    return Path(__file__).with_name("nccl_redist_versions.json")


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
        default=DEFAULT_NCCL_REDIST_URL,
        help="NVIDIA-compatible directory index; primarily useful for hermetic tests.",
    )
    parser.add_argument(
        "--cache",
        type=Path,
        default=Path(tempfile.gettempdir()) / "cuda-toolkit-nccl-redists-cache.json",
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
        help="Generate only this NCCL version; may be repeated.",
    )
    return parser.parse_args()


def main():
    args = _parse_args()
    base_url = args.base_url.rstrip("/") + "/"
    version_directories = _available_version_directories(base_url)
    versions = args.versions or sorted(version_directories, key=_version_tuple)
    missing_versions = sorted(set(versions) - set(version_directories), key=_version_tuple)
    if missing_versions:
        raise SystemExit("Unknown NCCL versions: {}".format(missing_versions))

    selections = {}
    archives_to_inspect = []
    for version in versions:
        selected = _archive_candidates(version, version_directories[version], base_url)
        if not selected:
            raise SystemExit("No supported CUDA archives found for NCCL {}".format(version))
        selections[version] = selected
        for archives in selected.values():
            archives_to_inspect.extend(archives.values())

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
        for cuda_major, archives in sorted(selections[version].items()):
            first_archive = archives[PLATFORMS[0]]
            cuda_match = re.search(r"cuda(\d+\.\d+)", first_archive["filename"])
            entry = {
                "archives": {},
                "built_with_cuda": cuda_match.group(1),
                "compatible_cuda": SUPPORTED_CUDA_MINORS[cuda_major],
            }
            for platform in PLATFORMS:
                archive = archives[platform]
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
