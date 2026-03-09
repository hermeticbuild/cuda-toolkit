"""Repository rule for hermetic CUDA configuration."""

load(
    "//cuda:redist_proxy_targets.bzl",
    "REPO_PUBLIC_TARGETS",
)

def _proxy_package_name(repo_name):
    return repo_name.removeprefix("cuda_")

def _version_bzl_content(component_version):
    parts = component_version.split(".") if component_version else []
    version_major = parts[0] if len(parts) > 0 else ""
    version_minor = parts[1] if len(parts) > 1 else ""
    version_patch = parts[2] if len(parts) > 2 else ""
    return """\
VERSION = "{version}"
VERSION_MAJOR = "{version_major}"
VERSION_MINOR = "{version_minor}"
VERSION_PATCH = "{version_patch}"
LIB_VERSIONS = {{}}
""".format(
        version = component_version,
        version_major = version_major,
        version_minor = version_minor,
        version_patch = version_patch,
    )

def _render_proxy_build_file(repo_name, target_names):
    lines = [
        "package(default_visibility = [\"//visibility:public\"])",
        "",
    ]

    for target_name in target_names:
        lines.extend([
            "alias(",
            "    name = \"{}\",".format(target_name),
            "    actual = \"@{}//:{}\",".format(repo_name, target_name),
            ")",
            "",
        ])
    return "\n".join(lines)

def _write_proxy_packages(repository_ctx):
    for repo_name in sorted(repository_ctx.attr.component_versions.keys()):
        component_version = repository_ctx.attr.component_versions[repo_name]
        target_names = REPO_PUBLIC_TARGETS.get(repo_name)
        if not target_names:
            continue
        package_name = _proxy_package_name(repo_name)
        repository_ctx.file(
            package_name + "/BUILD.bazel",
            _render_proxy_build_file(
                repo_name = repo_name,
                target_names = target_names,
            ),
        )
        repository_ctx.file(
            package_name + "/version.bzl",
            _version_bzl_content(component_version),
        )

def _cuda_configure_impl(repository_ctx):
    cuda_version = repository_ctx.attr.cuda_version

    repository_ctx.file(
        "cuda/cuda_version.bzl",
        "CUDA_VERSION = \"{}\"".format(cuda_version),
    )
    repository_ctx.template(
        "cuda/BUILD.bazel",
        repository_ctx.attr._cuda_build_file,
    )
    repository_ctx.file(
        "BUILD.bazel",
        "",
    )

    _write_proxy_packages(repository_ctx)

    return repository_ctx.repo_metadata(reproducible = True)

cuda_configure = repository_rule(
    implementation = _cuda_configure_impl,
    attrs = {
        "cuda_version": attr.string(mandatory = True),
        "component_versions": attr.string_dict(default = {}),
        "_cuda_build_file": attr.label(default = Label("//cuda:cuda.BUILD.bazel")),
    },
)
