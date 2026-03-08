"""Hermetic CUDA repositories initialization."""

load(
    "//cuda:cuda_redist_build_defs.bzl",
    "CUDA_REDIST_PATH_PREFIX",
    "CUDNN_REDIST_PATH_PREFIX",
    "REDIST_VERSIONS_TO_BUILD_DEFS",
)
load(
    "//cuda:redist_proxy_targets.bzl",
    "ARCH_REPO_SUFFIX",
    "PROXY_ARCH_CONDITIONS",
    "REPO_PUBLIC_TARGETS",
)

OS_ARCH_DICT = {
    "amd64": "x86_64-unknown-linux-gnu",
    "aarch64": "aarch64-unknown-linux-gnu",
}
_ARCH_REPO_SUFFIX = {
    "amd64": ARCH_REPO_SUFFIX["amd64"],
    "aarch64": ARCH_REPO_SUFFIX["aarch64"],
}
_REDIST_ARCH_DICT = {
    "linux-x86_64": "x86_64-unknown-linux-gnu",
    "linux-sbsa": "aarch64-unknown-linux-gnu",
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

def cudnn_redist_repository(
        cudnn_redistributions,
        cuda_version,
        cudnn_redist_path_prefix = CUDNN_REDIST_PATH_PREFIX,
        redist_versions_to_build_templates = REDIST_VERSIONS_TO_BUILD_DEFS):
    # buildifier: disable=function-docstring-args
    """Initializes CUDNN repository."""
    if "cudnn" in cudnn_redistributions:
        per_arch_url_dict = _get_redistribution_urls(
            cudnn_redistributions["cudnn"],
            dist_name = "cudnn",
        )
        component_version = cudnn_redistributions["cudnn"].get("version") or fail("Missing cudnn version")
    else:
        per_arch_url_dict = {}
        component_version = ""
    repo_data = redist_versions_to_build_templates["cudnn"]
    versions, templates = get_version_and_template_lists(
        repo_data["version_to_template"],
    )
    if component_version:
        available_arches = _create_component_arch_specific_repositories(
            repo_name = repo_data["package_name"],
            versions = versions,
            templates = templates,
            cuda_version = cuda_version,
            component_version = component_version,
            per_arch_url_dict = per_arch_url_dict,
            redist_path_prefix = cudnn_redist_path_prefix,
        )
        if available_arches:
            return {
                "component_versions": {repo_data["package_name"]: component_version},
                "component_arches": {repo_data["package_name"]: available_arches},
            }
    return {
        "component_versions": {},
        "component_arches": {},
    }

def cuda_redist_repositories(
        cuda_redistributions,
        cuda_version,
        cuda_redist_path_prefix = CUDA_REDIST_PATH_PREFIX,
        redist_versions_to_build_templates = REDIST_VERSIONS_TO_BUILD_DEFS):
    # buildifier: disable=function-docstring-args
    """Initializes CUDA repositories."""
    component_specs = []
    for redist_name in sorted(redist_versions_to_build_templates.keys()):
        if redist_name in ["cudnn", "cuda_nccl"]:
            continue
        # A given redist may exist in a CUDA version but not in another.
        if redist_name in cuda_redistributions:
            per_arch_url_dict = _get_redistribution_urls(
                cuda_redistributions[redist_name],
                dist_name = redist_name,
            )
            component_version = cuda_redistributions[redist_name].get("version") or fail("Missing {} version".format(redist_name))
        else:
            per_arch_url_dict = {}
            component_version = ""
        repo_data = redist_versions_to_build_templates[redist_name]
        versions, templates = get_version_and_template_lists(
            repo_data["version_to_template"],
        )
        component_specs.append({
            "package_name": repo_data["package_name"],
            "versions": versions,
            "templates": templates,
            "component_version": component_version,
            "per_arch_url_dict": per_arch_url_dict,
        })

    sorted_component_specs = [
        spec
        for spec in sorted(component_specs, key = lambda spec: spec["package_name"])
        if spec["package_name"] != "cuda_nvcc"
    ] + [
        spec
        for spec in sorted(component_specs, key = lambda spec: spec["package_name"])
        if spec["package_name"] == "cuda_nvcc"
    ]

    component_versions = {}
    component_arches = {}
    for spec in sorted_component_specs:
        if not spec["component_version"]:
            continue
        available_arches = _create_component_arch_specific_repositories(
            repo_name = spec["package_name"],
            versions = spec["versions"],
            templates = spec["templates"],
            cuda_version = cuda_version,
            component_version = spec["component_version"],
            per_arch_url_dict = spec["per_arch_url_dict"],
            redist_path_prefix = cuda_redist_path_prefix,
        )
        if available_arches:
            component_versions[spec["package_name"]] = spec["component_version"]
            component_arches[spec["package_name"]] = available_arches
    return {
        "component_versions": component_versions,
        "component_arches": component_arches,
    }

def _create_component_arch_specific_repositories(
        repo_name,
        versions,
        templates,
        cuda_version,
        component_version,
        per_arch_url_dict,
        redist_path_prefix):
    available_arches = []
    for arch in sorted(OS_ARCH_DICT.keys()):
        concrete_repo_name = _concrete_repo_name(repo_name, arch)
        if _has_arch_redistribution(per_arch_url_dict, cuda_version, arch):
            redist_repository(
                name = concrete_repo_name,
                versions = versions,
                build_defs = templates,
                cuda_version = cuda_version,
                component_version = component_version,
                per_arch_url_dict = per_arch_url_dict,
                redist_path_prefix = redist_path_prefix,
                target_arch = arch,
            )
            if arch in PROXY_ARCH_CONDITIONS:
                available_arches.append(arch)

    if repo_name not in _REPO_PUBLIC_TARGETS:
        fail("Missing public target catalog for repository '{}'".format(repo_name))
    return available_arches

def _concrete_repo_name(repo_name, arch):
    return "{}__{}".format(repo_name, _ARCH_REPO_SUFFIX[arch])

def _has_arch_redistribution(per_arch_url_dict, cuda_version, arch):
    arch_key = OS_ARCH_DICT[arch]
    if arch_key in per_arch_url_dict:
        return True
    major_cuda_arch_key = "cuda{version}_{arch}".format(
        version = cuda_version.split(".")[0],
        arch = arch_key,
    )
    return major_cuda_arch_key in per_arch_url_dict


def _get_redistribution_urls(dist_info, dist_name = "<unknown>"):
    # buildifier: disable=function-docstring-return
    # buildifier: disable=function-docstring-args
    """Returns a dict of redistribution URLs and their SHA256 values."""

    # CUDA redist json looks like this
    # "nvidia_fs": {
    #     "linux-x86_64": {
    #         "relative_path": "fs/linux-x86_64/libnvidia-fs.so",
    #     },
    #     ...
    # },
    per_arch_url_dict = {}
    for arch in sorted(_REDIST_ARCH_DICT.keys()):
        arch_key = arch
        if arch_key not in dist_info:
            continue
        if "relative_path" in dist_info[arch_key]:
            per_arch_url_dict[_REDIST_ARCH_DICT[arch]] = [
                dist_info[arch_key]["relative_path"],
                dist_info[arch_key].get("sha256", ""),
                dist_info[arch_key].get("strip_prefix", ""),
            ]
            continue

        if "full_path" in dist_info[arch_key]:
            per_arch_url_dict[_REDIST_ARCH_DICT[arch]] = [
                dist_info[arch_key]["full_path"],
                dist_info[arch_key].get("sha256", ""),
                dist_info[arch_key].get("strip_prefix", ""),
            ]
            continue

        # CUDNN and NVSHMEM JSON look like this:
        # "cudnn": {
        #     "linux-x86_64": {
        #         "cuda12": {
        #               "relative_path": "cudnn/linux-x86_64/...tar.xz",
        for cuda_version in sorted(dist_info[arch_key].keys()):
            data = dist_info[arch_key][cuda_version]

            # CUDNN and NVSHMEM JSON might contain paths for each CUDA version.
            if "relative_path" in data:
                path_key = "relative_path"
            elif "full_path" in data:
                path_key = "full_path"
            else:
                fail(
                    ("Invalid redistribution metadata for {dist_name} " +
                     "(arch={arch}, cuda={cuda_version}): expected either " +
                     "'relative_path' or 'full_path', got keys {keys}.").format(
                        dist_name = dist_name,
                        arch = arch_key,
                        cuda_version = cuda_version,
                        keys = sorted(data.keys()),
                    ),
                )
            per_arch_url_dict["{cuda_version}_{arch}".format(
                cuda_version = cuda_version,
                arch = _REDIST_ARCH_DICT[arch],
            )] = [data[path_key], data.get("sha256", ""), data.get("strip_prefix", "")]
    return per_arch_url_dict

def get_version_and_template_lists(version_to_template):
    # buildifier: disable=function-docstring-return
    # buildifier: disable=function-docstring-args
    """Returns lists of versions and templates provided in the dict."""
    template_to_version_map = {}
    for version, template in version_to_template.items():
        if template not in template_to_version_map:
            template_to_version_map[template] = [version]
        else:
            template_to_version_map[template].append(version)
    version_list = []
    template_list = []
    for template in sorted(template_to_version_map.keys()):
        version_list.append(",".join(sorted(template_to_version_map[template])))
        template_list.append(Label(template))
    return (version_list, template_list)

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

def _get_build_template(repository_ctx, major_lib_version):
    fallback_template = None
    template = None
    for i in range(0, len(repository_ctx.attr.versions)):
        for dist_version in repository_ctx.attr.versions[i].split(","):
            if dist_version == "any":
                fallback_template = repository_ctx.attr.build_defs[i]
            if dist_version == major_lib_version:
                template = repository_ctx.attr.build_defs[i]
                break
    if not template and fallback_template:
        template = fallback_template
    if not template:
        fail("No build template found for {} version {}".format(
            repository_ctx.original_name,
            major_lib_version,
        ))
    return template

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
    return """IS_PLACEHOLDER = {is_placeholder}
VERSION = "{version}"
VERSION_MAJOR = "{version_major}"
VERSION_MINOR = "{version_minor}"
VERSION_PATCH = "{version_patch}"
{lib_versions}
""".format(
        is_placeholder = "False" if component_version else "True",
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

#TODO(cerisier): remove me
def _tf_mirror_urls(url):
    """A helper for generating TF-mirror versions of URLs.

    Given a URL, it returns a list of the TF-mirror cache version of that URL
    and the original URL, suitable for use in `urls` field of `tf_http_archive`.
    """
    if not url.startswith("https://"):
        return [url]
    return [
        "https://storage.googleapis.com/mirror.tensorflow.org/%s" % url[8:],
        url,
    ]

def _download_redistribution(
        repository_ctx,
        arch_key,
        path_prefix):
    """Downloads and extracts NVIDIA redistribution."""
    (url, sha256, custom_strip_prefix) = repository_ctx.attr.per_arch_url_dict[arch_key]

    # If url is not relative, then appending prefix is not needed.
    if not (url.startswith("http") or url.startswith("file:///")):
        url = path_prefix + url
    archive_name = get_archive_name(url)
    repository_ctx.download_and_extract(
        url = _tf_mirror_urls(url),
        sha256 = sha256,
        stripPrefix = custom_strip_prefix if custom_strip_prefix else archive_name,
    )

## Redist component repository

def _redist_repository_impl(repository_ctx):
    # buildifier: disable=function-docstring-args
    """ Downloads redistribution and initializes hermetic repository."""
    component_version = repository_ctx.attr.component_version
    cuda_version = repository_ctx.attr.cuda_version

    arch_key = OS_ARCH_DICT[repository_ctx.attr.target_arch]
    if arch_key not in repository_ctx.attr.per_arch_url_dict:
        arch_key = "cuda{version}_{arch}".format(
            version = cuda_version.split(".")[0],
            arch = arch_key,
        )
    if arch_key not in repository_ctx.attr.per_arch_url_dict:
        fail(
            ("{dist_name}: The supported platforms are {supported_platforms}." +
             " Platform {platform} is not supported.")
                .format(
                supported_platforms = sorted(repository_ctx.attr.per_arch_url_dict.keys()),
                platform = arch_key,
                dist_name = repository_ctx.original_name,
            ),
        )

    _download_redistribution(
        repository_ctx,
        arch_key,
        repository_ctx.attr.redist_path_prefix,
    )
    lib_versions = _get_lib_versions_from_lib_dir(repository_ctx)

    build_template = _get_build_template(
        repository_ctx,
        component_version.split(".")[0],
    )
    repository_ctx.template("BUILD", build_template, {})

    _create_libcuda_symlinks(
        repository_ctx,
        component_version,
    )
    _create_version_file(repository_ctx, component_version, lib_versions)

redist_repository = repository_rule(
    implementation = _redist_repository_impl,
    attrs = {
        "per_arch_url_dict": attr.string_list_dict(mandatory = True),
        "versions": attr.string_list(mandatory = True),
        "build_defs": attr.label_list(mandatory = True),
        "cuda_version": attr.string(mandatory = True),
        "component_version": attr.string(mandatory = True),
        "redist_path_prefix": attr.string(),
        "target_arch": attr.string(mandatory = True),
    },
)

## Placeholder

def _redist_placeholder_repository_impl(repository_ctx):
    repository_ctx.template("BUILD", repository_ctx.attr.build_template, {})
    _create_version_file(repository_ctx, "")

redist_placeholder_repository = repository_rule(
    implementation = _redist_placeholder_repository_impl,
    attrs = {
        "build_template": attr.label(mandatory = True),
    },
)
