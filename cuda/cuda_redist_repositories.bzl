"""Hermetic CUDA repositories initialization."""

load(
    "//cuda:cuda_redist_build_defs.bzl",
    "COMPONENTS_REGISTRY",
    "CUDA_REDIST_PATH_PREFIX",
)
load(
    "//cuda:redist_proxy_targets.bzl",
    "REPO_PUBLIC_TARGETS",
)
load("//cuda:repository_metadata.bzl", "write_repo_bazel")

_PLATFORM_SPECS = {
    "linux_amd64": {
        "redist_platform_key": "linux-x86_64",
        "repo_suffix": "linux_x86_64",
        "config_setting": "@cuda_toolkit//:linux_amd64",
    },
    "linux_aarch64": {
        "redist_platform_key": "linux-sbsa",
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

def _platform_archive_entry(component_redist_entry, platform_key, cuda_version_major):
    platform_entry = component_redist_entry.get(platform_key)
    if not platform_entry:
        return None

    if platform_entry.get("relative_path"):
        return platform_entry

    variants = component_redist_entry.get("cuda_variant", [])
    if not variants:
        return platform_entry

    variant_key = "cuda{}".format(cuda_version_major)
    archive_entry = platform_entry.get(variant_key, platform_entry.get(cuda_version_major))
    if archive_entry:
        return archive_entry

    return None

def cuda_redist_repositories(
        redist,
        cuda_version,
        cuda_repo_name = "cuda",
        cuda_redist_path_prefix = CUDA_REDIST_PATH_PREFIX,
        components_registry = COMPONENTS_REGISTRY,
        default_package_metadata = ()):
    cuda_version_major = cuda_version.split(".")[0]
    generated_repos = []
    for component_name in sorted(components_registry.keys()):
        repo_data = components_registry[component_name]
        redist_component_names = [component_name] + repo_data.get("redist_component_aliases", [])
        component_redist_entry = None
        for redist_component_name in redist_component_names:
            if redist_component_name in redist:
                component_redist_entry = redist[redist_component_name]
                break

        # A given redist may exist in a CUDA version but not in another.
        if component_redist_entry == None:
            # buildifier: disable=print
            print("Component '{}' is missing from CUDA {} redist".format(component_name, cuda_version))
            continue

        component_version = component_redist_entry["version"]
        build_file = get_build_template(
            component_name,
            component_version,
            repo_data["version_to_template"],
        )
        for platform, platform_spec in _PLATFORM_SPECS.items():
            platform_key = platform_spec["redist_platform_key"]
            archive_entry = _platform_archive_entry(component_redist_entry, platform_key, cuda_version_major)
            if not archive_entry:
                # Component may not be available for that platform
                # buildifier: disable=print
                print("Component '{}' is missing for platform '{}' in CUDA {} redist".format(component_name, platform_key, cuda_version))
                continue

            concrete_repo_name = _concrete_repo_name(
                repo_name = repo_data["repo_name"],
                platform = platform,
                cuda_repo_name = cuda_repo_name,
            )
            cuda_component_repository(
                name = concrete_repo_name,
                build_file = Label(build_file),
                component_version = component_version,
                cuda_version = cuda_version,
                cuda_repo_name = cuda_repo_name,
                default_package_metadata = default_package_metadata,
                sha256 = archive_entry.get("sha256", ""),
                soname_libraries = repo_data.get("soname_libraries_by_version", {}).get(
                    component_version.split(".")[0],
                    repo_data.get("soname_libraries", []),
                ),
                strip_prefix = archive_entry.get("strip_prefix", ""),
                url = cuda_redist_path_prefix + archive_entry["relative_path"],
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

def _concrete_repo_name(repo_name, platform, cuda_repo_name):
    return "{}__{}__{}".format(
        cuda_repo_name,
        repo_name,
        _PLATFORM_SPECS[platform]["repo_suffix"],
    )

def get_build_template(component_name, component_version, version_to_template):
    if not component_version:
        fail("Missing component version while selecting build template")

    template = version_to_template.get(component_version.split(".")[0])
    if template:
        return template

    fallback_template = version_to_template.get("any")
    if fallback_template:
        return fallback_template

    fail("No build template found for {} {}".format(component_name, component_version))

def get_archive_name(url):
    last_slash_index = url.rfind("/")
    filename = url[last_slash_index + 1:]
    for extension in _SUPPORTED_ARCHIVE_EXTENSIONS:
        if filename.endswith(extension):
            return filename[:-len(extension)]
    return filename

def _update_lib_entries_from_dir(dir_path, lib_entries):
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

        entries = lib_entries.get(lib_name)
        if entries == None:
            entries = []
            lib_entries[lib_name] = entries
        entries.append(struct(
            is_symlink = lib_path.basename != lib_path.realpath.basename,
            realpath = str(lib_path.realpath),
            version = version,
        ))

def _is_more_specific_version(candidate, current):
    candidate_parts = candidate.split(".")
    current_parts = current.split(".")
    if len(candidate_parts) != len(current_parts):
        return len(candidate_parts) > len(current_parts)
    if len(candidate) != len(current):
        return len(candidate) > len(current)
    return candidate > current

def _is_less_specific_version(candidate, current):
    candidate_parts = candidate.split(".")
    current_parts = current.split(".")
    if len(candidate_parts) != len(current_parts):
        return len(candidate_parts) < len(current_parts)
    if len(candidate) != len(current):
        return len(candidate) < len(current)
    return candidate < current

def _get_lib_versions(repository_ctx):
    lib_entries = {}
    _update_lib_entries_from_dir(repository_ctx.path("lib"), lib_entries)
    _update_lib_entries_from_dir(repository_ctx.path("compat"), lib_entries)

    lib_versions = {}
    for lib_name, entries in lib_entries.items():
        most_specific = entries[0]
        for entry in entries:
            if _is_more_specific_version(entry.version, most_specific.version):
                most_specific = entry

        lib_versions[lib_name] = most_specific.version

    lib_soname_versions = {}
    for lib_name in repository_ctx.attr.soname_libraries:
        entries = lib_entries.get(lib_name)
        if not entries:
            fail("Cannot determine SONAME for '{}': no versioned library files found".format(lib_name))

        realpaths = {}
        for entry in entries:
            realpaths[entry.realpath] = True

        # NVIDIA user-space redistributions encode the ELF DT_SONAME as the
        # least-specific versioned symlink in a single library's symlink chain
        # (for example libcudart.so.12 -> libcudart.so.12.9.79). Do not infer a
        # SONAME from unrelated real files or a lone fully versioned file.
        if len(realpaths) != 1:
            fail("Cannot determine SONAME for '{}': versioned paths resolve to multiple files".format(lib_name))

        soname = None
        for entry in entries:
            if not entry.is_symlink:
                continue
            if soname == None or _is_less_specific_version(entry.version, soname.version):
                soname = entry
        if soname == None:
            fail("Cannot determine SONAME for '{}': no versioned symlink found".format(lib_name))
        lib_soname_versions[lib_name] = soname.version

    return lib_versions, lib_soname_versions

def _format_lib_versions_bzl(name, lib_versions):
    lines = [name + " = {"]
    for lib_name in sorted(lib_versions.keys()):
        lines.append('    "{name}": "{version}",'.format(
            name = lib_name,
            version = lib_versions[lib_name],
        ))
    lines.append("}")
    return "\n".join(lines)

def _version_bzl_content(component_version, lib_versions = {}, lib_soname_versions = {}):
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
{lib_soname_versions}
""".format(
        version = component_version,
        version_major = version_major,
        version_minor = version_minor,
        version_patch = version_patch,
        lib_versions = _format_lib_versions_bzl("LIB_VERSIONS", lib_versions),
        lib_soname_versions = _format_lib_versions_bzl("LIB_SONAME_VERSIONS", lib_soname_versions),
    )

def _download_redistribution(rctx):
    # If url is not relative, then appending prefix is not needed.
    url = rctx.attr.url
    strip_prefix = rctx.attr.strip_prefix or get_archive_name(url)
    rctx.download_and_extract(
        url = url,
        sha256 = rctx.attr.sha256,
        strip_prefix = strip_prefix,
    )

## Redist component repository

def _cuda_component_repository_impl(repository_ctx):
    component_version = repository_ctx.attr.component_version

    write_repo_bazel(repository_ctx)
    _download_redistribution(repository_ctx)

    repository_ctx.template(
        "BUILD",
        repository_ctx.attr.build_file,
        {"{cuda_redist_repo}": repository_ctx.attr.cuda_repo_name},
    )

    lib_versions, lib_soname_versions = _get_lib_versions(repository_ctx)
    repository_ctx.file(
        "version.bzl",
        _version_bzl_content(component_version, lib_versions, lib_soname_versions),
    )

    return repository_ctx.repo_metadata(reproducible = True)

cuda_component_repository = repository_rule(
    implementation = _cuda_component_repository_impl,
    attrs = {
        "build_file": attr.label(mandatory = True),
        "component_version": attr.string(mandatory = True),
        "cuda_version": attr.string(mandatory = True),
        "cuda_repo_name": attr.string(mandatory = True),
        "default_package_metadata": attr.string_list(),
        "sha256": attr.string(),
        "soname_libraries": attr.string_list(),
        "strip_prefix": attr.string(),
        "url": attr.string(mandatory = True),
    },
)
