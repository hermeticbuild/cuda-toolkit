"""Hermetic CUDA repositories initialization."""

load(
    "//cuda:cuda_redist_build_defs.bzl",
    "CUDA_REDIST_PATH_PREFIX",
    "CUDNN_REDIST_PATH_PREFIX",
    "COMPONENTS_REGISTRY",
)
load(
    "//cuda:redist_proxy_targets.bzl",
    "REPO_PUBLIC_TARGETS",
)

_PLATFORM_SPECS = {
    "linux_amd64": {
        "redist_key": "linux-x86_64",
        "repo_suffix": "linux_x86_64",
        "config_setting": "@cuda_toolkit//:linux_amd64",
    },
    "linux_aarch64": {
        "redist_key": "linux-sbsa",
        "repo_suffix": "linux_sbsa",
        "config_setting": "@cuda_toolkit//:linux_arm64",
    },
}

_REPO_PUBLIC_TARGETS = REPO_PUBLIC_TARGETS
_SUPPORTED_ARCHIVE_EXTENSIONS = [
    # we use suffix match, so suffix specializations should be
    # before more general ones, e.g. .tar.gz should be before .tar
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

# -----------------------------------------------------------------------------
# Public macros
# -----------------------------------------------------------------------------

# def cudnn_redist_repository(
#         cudnn_redistributions,
#         cuda_version,
#         cudnn_redist_path_prefix = CUDNN_REDIST_PATH_PREFIX,
#         components_registry = COMPONENTS_REGISTRY):
#     # buildifier: disable=function-docstring-args
#     """Initializes CUDNN repository."""
#     if "cudnn" not in cudnn_redistributions:
#         fail("Missing cudnn redistribution metadata")

#     per_arch_url_dict = _get_redistribution_urls(
#         component = "cudnn",
#         component_redist_entry = cudnn_redistributions["cudnn"],
#         cuda_version_major = cuda_version.split(".")[0],
#     )
#     component_version = cudnn_redistributions["cudnn"].get("version")
#     if not component_version:
#         fail("Missing cudnn version")

#     repo_data = components_registry["cudnn"]
#     build_file = get_build_template(
#         repo_data["version_to_template"],
#         component_version,
#     )
#     repo_name = repo_data["repo_name"]
#     available_arches = _create_component_arch_specific_repositories(
#         repo_name = repo_name,
#         build_file = build_file,
#         component_version = component_version,
#         per_arch_url_dict = per_arch_url_dict,
#         redist_path_prefix = cudnn_redist_path_prefix,
#     )
#     return {
#         "component_versions": {repo_name: component_version},
#         "component_arches": {repo_name: available_arches},
#     }

def cuda_redist_repositories(
        redist,
        cuda_version,
        cuda_redist_path_prefix = CUDA_REDIST_PATH_PREFIX,
        components_registry = COMPONENTS_REGISTRY):
    # buildifier: disable=function-docstring-args
    """Initializes CUDA repositories."""
    cuda_version_major = cuda_version.split(".")[0]
    generated_repos = []
    for component_name in sorted(components_registry.keys()):

        # A given redist may exist in a CUDA version but not in another.
        if component_name not in redist:
            # buildifier: disable=print
            print("Component '{}' is missing from CUDA {} redist".format(component_name, cuda_version)) 
            continue

        component_redist_entry = redist[component_name]
        component_version = component_redist_entry.get("version")
        if not component_version:
            fail("Missing {} version".format(component_name))
        repo_data = components_registry[component_name]
        build_file = get_build_template(
            repo_data["version_to_template"],
            component_version,
        )
        for platform in sorted(_PLATFORM_SPECS.keys()):
            platform_spec = _PLATFORM_SPECS[platform]
            platform_redist = _get_redistribution_url_for_platform_key(
                component = component_name,
                component_redist_entry = component_redist_entry,
                cuda_version_major = cuda_version_major,
                redist_key = platform_spec["redist_key"],
                redist_path_prefix = cuda_redist_path_prefix,
            )
            # Component may not be available for that platform
            if platform_redist:
                concrete_repo_name = _concrete_repo_name(repo_data["repo_name"], platform)
                (url, sha256, strip_prefix) = platform_redist
                redist_repository(
                    name = concrete_repo_name,
                    build_file = Label(build_file),
                    component_version = component_version,
                    cuda_version = cuda_version,
                    strip_prefix = strip_prefix,
                    sha256 = sha256,
                    url = url,
                )
                generated_repos.append({
                    "component_repo_name": repo_data["repo_name"],
                    "concrete_repo_name": concrete_repo_name,
                    "platform": platform,
                    "config_setting": platform_spec["config_setting"],
                    "version": component_version,
                    "targets": _REPO_PUBLIC_TARGETS.get(repo_data["repo_name"], []),
                })

    return generated_repos

def _concrete_repo_name(repo_name, platform):
    return "{}__{}".format(repo_name, _PLATFORM_SPECS[platform]["repo_suffix"])

def _get_redistribution_url_for_platform_key(
    component,
    component_redist_entry,
    cuda_version_major,
    redist_key,
    redist_path_prefix = CUDA_REDIST_PATH_PREFIX,
):
    # buildifier: disable=function-docstring-return
    # buildifier: disable=function-docstring-args
    """Returns redistribution URL metadata for a given platform redist key."""

    # CUDA redist json looks like this
    # "nvidia_fs": {
    #     "linux-x86_64": {
    #         "relative_path": "fs/linux-x86_64/libnvidia-fs.so",
    #     },
    #     ...
    # },
    if redist_key not in component_redist_entry:
        return None

    arch_info = component_redist_entry[redist_key]
    if "relative_path" in arch_info:
        return [
            redist_path_prefix + arch_info["relative_path"],
            arch_info.get("sha256", ""),
            arch_info.get("strip_prefix", ""),
        ]

    if "full_path" in arch_info:
        return [
            arch_info["full_path"],
            arch_info.get("sha256", ""),
            arch_info.get("strip_prefix", ""),
        ]

    # CUDNN and NVSHMEM JSON look like this:
    # "cudnn": {
    #     "linux-x86_64": {
    #         "cuda12": {
    #               "relative_path": "cudnn/linux-x86_64/...tar.xz",
    cuda_variant_key = "cuda%s" % cuda_version_major
    data = component_redist_entry[redist_key].get(cuda_variant_key)
    if not data:
        fail("Missing redistribution metadata for {component} (platform={platform}, cuda={cuda_version_major})".format(
            component = component,
            platform = redist_key,
            cuda_version_major = cuda_version_major,
        ))
    if "relative_path" in data:
        path_key = "relative_path"
    elif "full_path" in data:
        path_key = "full_path"
    else:
        fail("Missing redistribution path for {component} (platform={platform}, cuda={cuda_version_major})".format(
            component = component,
            platform = redist_key,
            cuda_version_major = cuda_version_major,
        ))
    return [
        (redist_path_prefix + data[path_key]) if path_key == "relative_path" else data[path_key],
        data.get("sha256", ""),
        data.get("strip_prefix", ""),
    ]

def get_build_template(version_to_template, component_version):
    # buildifier: disable=function-docstring-return
    # buildifier: disable=function-docstring-args
    """Returns the matching build template path for a component version."""
    if not component_version:
        fail("Missing component version while selecting build template")

    template = version_to_template.get(component_version.split(".")[0])
    if template:
        return template

    fallback_template = version_to_template.get("any")
    if fallback_template:
        return fallback_template

    fail("No build template found for component version {}".format(component_version))

def _get_file_name(url):
    last_slash_index = url.rfind("/")
    return url[last_slash_index + 1:]

def get_archive_name(url):
    # buildifier: disable=function-docstring-return
    # buildifier: disable=function-docstring-args
    """Returns the archive name without extension."""
    filename = _get_file_name(url)
    for extension in _SUPPORTED_ARCHIVE_EXTENSIONS:
        if filename.endswith(extension):
            return filename[:-len(extension)]
    return filename

def _create_libcuda_symlinks(
        repository_ctx,
        component_version):
    lib_names = ["cuda", "nvidia-ml", "nvidia-ptxjitcompiler"]
    if repository_ctx.original_name == "cuda_driver" and component_version:
        for lib in lib_names:
            versioned_lib_path = "lib/lib{}.so.{}".format(
                lib,
                component_version,
            )
            if not repository_ctx.path(versioned_lib_path).exists:
                fail("%s doesn't exist!" % versioned_lib_path)
            symlink_so_1 = "lib/lib%s.so.1" % lib
            if repository_ctx.path(symlink_so_1).exists:
                print("File %s already exists!" % repository_ctx.path(symlink_so_1))  # buildifier: disable=print
            else:
                repository_ctx.symlink(versioned_lib_path, symlink_so_1)
            if lib == "cuda":
                unversioned_symlink = "lib/lib%s.so" % lib
                if repository_ctx.path(unversioned_symlink).exists:
                    print("File %s already exists!" % repository_ctx.path(unversioned_symlink))  # buildifier: disable=print
                else:
                    repository_ctx.symlink(symlink_so_1, unversioned_symlink)

def _get_lib_versions_from_lib_dir(repository_ctx):
    lib_versions = {}
    lib_dir = repository_ctx.path("lib")
    if not lib_dir.exists:
        return lib_versions

    for lib_path in lib_dir.readdir():
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

        # Prefer the most specific soname suffix for a library
        # (for example 12.9.1.4 over 12 or 1).
        existing_parts = existing.split(".")
        version_parts = version.split(".")
        if len(version_parts) > len(existing_parts):
            lib_versions[lib_name] = version
        elif len(version_parts) == len(existing_parts) and len(version) > len(existing):
            lib_versions[lib_name] = version

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

def _create_version_file(repository_ctx, component_version, lib_versions = {}):
    if repository_ctx.name == "cuda_driver" and component_version:
        print("Downloaded User Mode Driver version is %s" % component_version)  # buildifier: disable=print

    repository_ctx.file(
        "version.bzl",
        _version_bzl_content(component_version, lib_versions),
    )

def _download_redistribution(rctx):
    """Downloads and extracts NVIDIA redistribution."""

    # If url is not relative, then appending prefix is not needed.
    url = rctx.attr.url
    if not (url.startswith("http") or url.startswith("file:///")):
        url = rctx.attr.redist_path_prefix + url

    archive_name = get_archive_name(url)
    rctx.download_and_extract(
        url = url,
        sha256 = rctx.attr.sha256,
        strip_prefix = rctx.attr.strip_prefix or archive_name,
    )

## Redist component repository

def _redist_repository_impl(repository_ctx):
    # buildifier: disable=function-docstring-args
    """ Downloads redistribution and initializes hermetic repository."""
    component_version = repository_ctx.attr.component_version

    _download_redistribution(repository_ctx)
    lib_versions = _get_lib_versions_from_lib_dir(repository_ctx)

    repository_ctx.template("BUILD", repository_ctx.attr.build_file, {})

    # write cuda version in cuda_version.bzl
    repository_ctx.file(
        "cuda_version.bzl",
        "CUDA_VERSION = \"{}\"".format(repository_ctx.attr.cuda_version),
    )

    _create_libcuda_symlinks(
        repository_ctx,
        component_version,
    )
    _create_version_file(repository_ctx, component_version, lib_versions)

    return repository_ctx.repo_metadata(reproducible = True)

redist_repository = repository_rule(
    implementation = _redist_repository_impl,
    attrs = {
        "build_file": attr.label(mandatory = True),
        "component_version": attr.string(mandatory = True),
        "cuda_version": attr.string(mandatory = True),
        "strip_prefix": attr.string(),
        "sha256": attr.string(),
        "url": attr.string(mandatory = True),
    },
)
