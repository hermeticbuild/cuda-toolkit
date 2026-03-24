"""Unified NVSHMEM module extension."""

load("//nvshmem:nvshmem_compat_repository.bzl", "nvshmem_compat_repository")
load("//nvshmem:nvshmem_redist_repositories.bzl", "nvshmem_redist_repositories")
load("//nvshmem:nvshmem_redist_repository.bzl", "nvshmem_redist_repository")

_NVSHMEM_REDIST_VERSIONS_JSON = Label("//nvshmem:nvshmem_redist_versions.json")

def _collect_redist_tags(mctx):
    all_tags = []
    root_tags = []
    for mod in mctx.modules:
        for tag in mod.tags.redist:
            all_tags.append(tag)
            if mod.is_root:
                root_tags.append(tag)

    tags = root_tags if root_tags else all_tags
    if not tags:
        fail("nvshmem extension requires at least one redist tag")
    return tags

def _get_url_sha_from_version_map(version, version_to_url_sha, toolkit_name):
    url_sha = version_to_url_sha.get(version)
    if not url_sha:
        fail(
            ("Unsupported {toolkit_name} version '{version}'. " +
             "Supported versions: {supported}.").format(
                toolkit_name = toolkit_name,
                version = version,
                supported = sorted(version_to_url_sha.keys()),
            ),
        )
    return url_sha

def _json_from_url_future(mctx, url, sha256, output_path):
    return struct(
        output_path = output_path,
        token = mctx.download(
            url = [url],
            output = output_path,
            sha256 = sha256,
            block = False,
        ),
    )

def _read_downloaded_json(mctx, pending_download):
    pending_download.token.wait()
    return json.decode(mctx.read(pending_download.output_path))

def _normalize_version_parts(version):
    parts = []
    for raw_part in version.split("."):
        if raw_part:
            parts.append(int(raw_part))
    return parts

def _version_greater_than(left, right):
    left_parts = _normalize_version_parts(left)
    right_parts = _normalize_version_parts(right)
    max_len = max(len(left_parts), len(right_parts))
    for idx in range(max_len):
        left_value = left_parts[idx] if idx < len(left_parts) else 0
        right_value = right_parts[idx] if idx < len(right_parts) else 0
        if left_value > right_value:
            return True
        if left_value < right_value:
            return False
    return False

def _nvshmem_impl(mctx):
    nvshmem_version_map = json.decode(mctx.read(_NVSHMEM_REDIST_VERSIONS_JSON))

    tags = _collect_redist_tags(mctx)

    seen_repo_names = {}
    seen_versions = {}
    versions = []

    pending_redistributions_by_version = {}
    versions_to_fetch = []
    redistributions_by_version = {}

    for tag in tags:
        if tag.name == "nvshmem":
            fail("redist name 'nvshmem' is reserved for the global aggregated NVSHMEM repository")

        if tag.name in seen_repo_names:
            fail("Duplicate redist name '{}'".format(tag.name))
        seen_repo_names[tag.name] = True

        if tag.version in seen_versions:
            fail("Duplicate NVSHMEM version '{}'".format(tag.version))
        seen_versions[tag.version] = True
        versions.append(tag.version)

        if tag.version not in pending_redistributions_by_version:
            (nvshmem_redist_url, nvshmem_redist_sha256) = _get_url_sha_from_version_map(
                version = tag.version,
                version_to_url_sha = nvshmem_version_map,
                toolkit_name = "NVSHMEM",
            )
            pending_redistributions_by_version[tag.version] = _json_from_url_future(
                mctx = mctx,
                url = nvshmem_redist_url,
                sha256 = nvshmem_redist_sha256,
                output_path = "redistrib_nvshmem_%s.json" % tag.version,
            )
            versions_to_fetch.append(tag.version)

    for version in versions_to_fetch:
        redistributions_by_version[version] = _read_downloaded_json(
            mctx,
            pending_redistributions_by_version[version],
        )

    default_cuda_version_to_repo_name = {}
    for tag in tags:
        redist = redistributions_by_version[tag.version]
        if "libnvshmem" not in redist:
            fail("NVSHMEM manifest '{}' does not contain a 'libnvshmem' package".format(tag.version))

        generated_repos = nvshmem_redist_repositories(
            redist = redist["libnvshmem"],
            nvshmem_repo_name = tag.name,
            nvshmem_version = tag.version,
        )

        if not generated_repos:
            fail("NVSHMEM version '{}' did not generate any repositories".format(tag.version))

        combo_repo_mappings = {}
        actual_version = ""
        supported_cuda_versions = {}
        for generated in generated_repos:
            combo_key = "{}|{}".format(generated["cuda_version"], generated["platform"])
            combo_repo_mappings[combo_key] = generated["concrete_repo_name"]
            supported_cuda_versions[generated["cuda_version"]] = True
            if not actual_version:
                actual_version = generated["version"]

        nvshmem_redist_repository(
            name = tag.name,
            version = actual_version,
            combo_repo_mappings = combo_repo_mappings,
        )

        for cuda_version in supported_cuda_versions.keys():
            current = default_cuda_version_to_repo_name.get(cuda_version)
            if not current:
                default_cuda_version_to_repo_name[cuda_version] = struct(
                    requested_version = tag.version,
                    repo_name = tag.name,
                )
                continue

            if _version_greater_than(tag.version, current.requested_version):
                default_cuda_version_to_repo_name[cuda_version] = struct(
                    requested_version = tag.version,
                    repo_name = tag.name,
                )

    nvshmem_compat_repository(
        name = "nvshmem",
        registered_nvshmem_versions = sorted(versions),
        version_to_redist_repo_name = {
            tag.version: tag.name
            for tag in tags
        },
        default_cuda_version_to_repo_name = {
            cuda_version: data.repo_name
            for cuda_version, data in default_cuda_version_to_repo_name.items()
        },
    )

    return mctx.extension_metadata(reproducible = True)

_redist = tag_class(
    attrs = {
        "name": attr.string(mandatory = True),
        "version": attr.string(mandatory = True),
    },
)

nvshmem = module_extension(
    implementation = _nvshmem_impl,
    tag_classes = {"redist": _redist},
)
