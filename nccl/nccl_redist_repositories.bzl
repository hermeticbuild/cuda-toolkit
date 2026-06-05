"""Hermetic NCCL repositories initialization."""

load(
    "//cuda:redist_proxy_targets.bzl",
    "REPO_PUBLIC_TARGETS",
)
load(
    "//nccl:nccl_redist_build_defs.bzl",
    "NCCL_BUILD_FILE",
    "NCCL_COMPONENT_REPO_NAME",
    "NCCL_WHEEL_STRIP_PREFIX",
)

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

def _cuda_major_key(cuda_version):
    return "cuda{}".format(cuda_version.split(".")[0])

def _concrete_repo_name(repo_name, platform, cuda_repo_name):
    return "{}__{}__{}".format(
        cuda_repo_name,
        repo_name,
        _PLATFORM_SPECS[platform]["repo_suffix"],
    )

def _wheel_entry(nccl_wheels, nccl_version, cuda_version, platform_key):
    version_entry = nccl_wheels.get(nccl_version)
    if not version_entry:
        fail("Unsupported NCCL version '{}'. Supported versions: {}".format(
            nccl_version,
            sorted(nccl_wheels.keys()),
        ))

    cuda_key = _cuda_major_key(cuda_version)
    cuda_entry = version_entry.get(cuda_key)
    if not cuda_entry:
        fail("NCCL version '{}' does not provide a wheel for CUDA {}".format(
            nccl_version,
            cuda_version,
        ))

    platform_entry = cuda_entry.get(platform_key)
    if not platform_entry:
        return None

    return {
        "url": platform_entry[0],
        "sha256": platform_entry[1],
    }

def nccl_redist_repositories(nccl_wheels, nccl_version, cuda_version, cuda_repo_name, patches = []):
    generated_repos = []
    for platform, platform_spec in _PLATFORM_SPECS.items():
        platform_key = platform_spec["redist_platform_key"]
        wheel_entry = _wheel_entry(
            nccl_wheels = nccl_wheels,
            nccl_version = nccl_version,
            cuda_version = cuda_version,
            platform_key = platform_key,
        )
        if not wheel_entry:
            # buildifier: disable=print
            print("NCCL '{}' is missing for platform '{}' with CUDA {}".format(nccl_version, platform_key, cuda_version))
            continue

        concrete_repo_name = _concrete_repo_name(
            repo_name = NCCL_COMPONENT_REPO_NAME,
            platform = platform,
            cuda_repo_name = cuda_repo_name,
        )
        nccl_component_repository(
            name = concrete_repo_name,
            build_file = Label(NCCL_BUILD_FILE),
            component_version = nccl_version,
            cuda_repo_name = cuda_repo_name,
            patches = patches,
            sha256 = wheel_entry["sha256"],
            strip_prefix = NCCL_WHEEL_STRIP_PREFIX,
            url = wheel_entry["url"],
        )
        generated_repos.append({
            "component_repo_name": NCCL_COMPONENT_REPO_NAME,
            "concrete_repo_name": concrete_repo_name,
            "platform": platform,
            "config_setting": platform_spec["config_setting"],
            "version": nccl_version,
            "targets": REPO_PUBLIC_TARGETS[NCCL_COMPONENT_REPO_NAME],
        })

    return generated_repos

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

def _version_bzl_content(component_version, lib_versions):
    parts = component_version.split(".")
    return """\
VERSION = "{version}"
VERSION_MAJOR = "{version_major}"
VERSION_MINOR = "{version_minor}"
VERSION_PATCH = "{version_patch}"
{lib_versions}
""".format(
        version = component_version,
        version_major = parts[0] if len(parts) > 0 else "",
        version_minor = parts[1] if len(parts) > 1 else "",
        version_patch = parts[2] if len(parts) > 2 else "",
        lib_versions = _format_lib_versions_bzl(lib_versions),
    )

def _download_nccl_wheel(repository_ctx):
    wheel_file = "nccl.zip"
    repository_ctx.download(
        url = repository_ctx.attr.url,
        output = wheel_file,
        sha256 = repository_ctx.attr.sha256,
    )
    repository_ctx.extract(
        archive = wheel_file,
        stripPrefix = repository_ctx.attr.strip_prefix,
    )
    for patch_file in repository_ctx.attr.patches:
        repository_ctx.patch(
            patch_file,
            strip = 1,
        )
    repository_ctx.delete(wheel_file)

def _nccl_component_repository_impl(repository_ctx):
    component_version = repository_ctx.attr.component_version

    _download_nccl_wheel(repository_ctx)

    repository_ctx.template(
        "BUILD",
        repository_ctx.attr.build_file,
        {"{cuda_redist_repo}": repository_ctx.attr.cuda_repo_name},
    )
    repository_ctx.file("version.txt", component_version)

    lib_versions = _get_lib_versions(repository_ctx)
    repository_ctx.file(
        "version.bzl",
        _version_bzl_content(component_version, lib_versions),
    )

    return repository_ctx.repo_metadata(reproducible = True)

nccl_component_repository = repository_rule(
    implementation = _nccl_component_repository_impl,
    attrs = {
        "build_file": attr.label(mandatory = True),
        "component_version": attr.string(mandatory = True),
        "cuda_repo_name": attr.string(mandatory = True),
        "patches": attr.label_list(allow_files = True),
        "sha256": attr.string(mandatory = True),
        "strip_prefix": attr.string(mandatory = True),
        "url": attr.string(mandatory = True),
    },
)
