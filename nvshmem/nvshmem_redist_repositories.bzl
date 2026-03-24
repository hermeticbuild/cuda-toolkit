"""Hermetic NVSHMEM repositories initialization."""

load(
    "//nvshmem:nvshmem_redist_build_defs.bzl",
    "NVSHMEM_REDIST_PATH_PREFIX",
    "NVSHMEM_VERSION_TO_TEMPLATE",
)

_PLATFORM_SPECS = {
    "linux_amd64": {
        "redist_platform_key": "linux-x86_64",
        "repo_suffix": "linux_x86_64",
    },
    "linux_arm64": {
        "redist_platform_key": "linux-sbsa",
        "repo_suffix": "linux_sbsa",
    },
}

_SUPPORTED_CUDA_MAJOR_VERSIONS = [
    "12",
    "13",
]

_SUPPORTED_ARCHIVE_EXTENSIONS = [
    ".tar.gz",
    ".tar.xz",
    ".tar.zst",
    ".tar.bz2",
    ".zip",
    ".jar",
    ".war",
    ".aar",
    ".tar",
    ".tgz",
    ".txz",
    ".tzst",
    ".tbz",
    ".ar",
    ".deb",
    ".whl",
]

def _platform_archive_entry(component_redist_entry, platform_key, cuda_version):
    platform_entry = component_redist_entry.get(platform_key)
    if not platform_entry:
        return None

    if platform_entry.get("relative_path"):
        return platform_entry

    variant_key = "cuda{}".format(cuda_version)
    return platform_entry.get(variant_key, platform_entry.get(cuda_version))

def nvshmem_redist_repositories(
        redist,
        nvshmem_version,
        nvshmem_repo_name = "nvshmem",
        nvshmem_redist_path_prefix = NVSHMEM_REDIST_PATH_PREFIX,
        version_to_template = NVSHMEM_VERSION_TO_TEMPLATE):
    generated_repos = []
    build_file = get_build_template(
        component_version = redist["version"],
        version_to_template = version_to_template,
    )

    for cuda_version in sorted(redist.get("cuda_variant", [])):
        if cuda_version not in _SUPPORTED_CUDA_MAJOR_VERSIONS:
            print("NVSHMEM '{}' CUDA {} variant ignored because CUDA {} is not supported by this repository".format(nvshmem_version, cuda_version, cuda_version))
            continue

        for platform, platform_spec in _PLATFORM_SPECS.items():
            archive_entry = _platform_archive_entry(
                component_redist_entry = redist,
                platform_key = platform_spec["redist_platform_key"],
                cuda_version = cuda_version,
            )
            if not archive_entry:
                print("NVSHMEM '{}' is missing for CUDA {} on platform '{}'".format(nvshmem_version, cuda_version, platform))
                continue

            concrete_repo_name = _concrete_repo_name(
                cuda_version = cuda_version,
                platform = platform,
                nvshmem_repo_name = nvshmem_repo_name,
            )
            nvshmem_component_repository(
                name = concrete_repo_name,
                build_file = Label(build_file),
                component_version = redist["version"],
                sha256 = archive_entry.get("sha256", ""),
                url = nvshmem_redist_path_prefix + archive_entry["relative_path"],
            )
            generated_repos.append({
                "concrete_repo_name": concrete_repo_name,
                "cuda_version": cuda_version,
                "platform": platform,
                "version": redist["version"],
            })

    return generated_repos

def _concrete_repo_name(cuda_version, platform, nvshmem_repo_name):
    return "{}__nvshmem__cuda{}__{}".format(
        nvshmem_repo_name,
        cuda_version,
        _PLATFORM_SPECS[platform]["repo_suffix"],
    )

def get_build_template(component_version, version_to_template):
    if not component_version:
        fail("Missing NVSHMEM component version while selecting build template")

    template = version_to_template.get(component_version.split(".")[0])
    if template:
        return template

    fail("No build template found for NVSHMEM {}".format(component_version))

def get_archive_name(url):
    last_slash_index = url.rfind("/")
    filename = url[last_slash_index + 1:]
    for extension in _SUPPORTED_ARCHIVE_EXTENSIONS:
        if filename.endswith(extension):
            return filename[:-len(extension)]
    return filename

def _update_lib_versions_from_dir(dir_path, lib_versions):
    if not dir_path.exists:
        return

    for lib_path in dir_path.readdir():
        file_name = lib_path.basename
        lib_suffix = ".so."
        so_idx = file_name.find(lib_suffix)
        if so_idx <= 0:
            continue

        lib_name = file_name[:so_idx].lower()
        version = file_name[so_idx + len(lib_suffix):]
        if not version:
            continue

        existing = lib_versions.get(lib_name, "")
        if not existing:
            lib_versions[lib_name] = version
            continue

        existing_parts = existing.split(".")
        version_parts = version.split(".")
        if len(version_parts) > len(existing_parts):
            lib_versions[lib_name] = version
        elif len(version_parts) == len(existing_parts) and len(version) > len(existing):
            lib_versions[lib_name] = version

def _get_lib_versions(repository_ctx):
    lib_versions = {}
    _update_lib_versions_from_dir(repository_ctx.path("lib"), lib_versions)
    return lib_versions

def _format_lib_versions_bzl(lib_versions):
    lines = ["LIB_VERSIONS = {"]
    for lib_name in sorted(lib_versions.keys()):
        lines.append('    "{name}": "{version}",'.format(
            name = lib_name,
            version = lib_versions[lib_name],
        ))
    lines.append("}")
    return "\n".join(lines)

def _version_bzl_content(component_version, lib_versions = {}):
    parts = component_version.split(".") if component_version else []
    version_major = parts[0] if len(parts) > 0 else ""
    version_minor = parts[1] if len(parts) > 1 else ""
    version_patch = parts[2] if len(parts) > 2 else ""
    return """\
VERSION = "{version}"
VERSION_MAJOR = "{version_major}"
VERSION_MINOR = "{version_minor}"
VERSION_PATCH = "{version_patch}"
{lib_versions}
""".format(
        version = component_version,
        version_major = version_major,
        version_minor = version_minor,
        version_patch = version_patch,
        lib_versions = _format_lib_versions_bzl(lib_versions),
    )

def _download_redistribution(rctx):
    url = rctx.attr.url
    archive_name = get_archive_name(url)
    rctx.download_and_extract(
        url = url,
        sha256 = rctx.attr.sha256,
        strip_prefix = archive_name,
    )

def _nvshmem_component_repository_impl(repository_ctx):
    component_version = repository_ctx.attr.component_version

    _download_redistribution(repository_ctx)

    repository_ctx.template(
        "BUILD",
        repository_ctx.attr.build_file,
        {"{cuda_redist_repo}": "@cuda_toolkit++cuda+cuda"},
    )

    lib_versions = _get_lib_versions(repository_ctx)
    repository_ctx.file(
        "version.bzl",
        _version_bzl_content(component_version, lib_versions),
    )

    return repository_ctx.repo_metadata(reproducible = True)

nvshmem_component_repository = repository_rule(
    implementation = _nvshmem_component_repository_impl,
    attrs = {
        "build_file": attr.label(mandatory = True),
        "component_version": attr.string(mandatory = True),
        "sha256": attr.string(),
        "url": attr.string(mandatory = True),
    },
)
