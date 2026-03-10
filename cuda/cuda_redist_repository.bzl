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

def _component_proxy_repo_name(cuda_repo_name, component_repo_name):
    return "{}__{}".format(cuda_repo_name, component_repo_name)

def _render_proxy_build_file(actual_repo_name, target_names):
    lines = [
        "package(default_visibility = [\"//visibility:public\"])",
        "",
    ]

    for target_name in target_names:
        lines.extend([
            "alias(",
            "    name = \"{}\",".format(target_name),
            "    actual = \"@{}//:{}\",".format(actual_repo_name, target_name),
            ")",
            "",
        ])
    return "\n".join(lines)

def _render_placeholder_build_file(target_names, cuda_version):
    lines = [
        "package(default_visibility = [\"//visibility:public\"])",
        "",
    ]

    for target_name in target_names:
        lines.extend([
            "alias(",
            "    name = \"{}\",".format(target_name),
            "    actual = select({",
            "        \"@platforms//:incompatible\": \"unused\",",
            "    }}, no_match_error = \"This target is not provided by CUDA {}\"),".format(cuda_version),
            ")",
            "",
        ])

    return "\n".join(lines)

def _write_proxy_packages(repository_ctx):
    for repo_name in sorted(REPO_PUBLIC_TARGETS.keys()):
        component_version = repository_ctx.attr.available_component_versions.get(repo_name)
        package_name = _proxy_package_name(repo_name)
        proxy_repo_name = repository_ctx.attr.available_component_mappings.get(repo_name)

        build_file_content = _render_placeholder_build_file(
            cuda_version = repository_ctx.attr.cuda_version,
            target_names = REPO_PUBLIC_TARGETS[repo_name],
        )
        if proxy_repo_name:
            build_file_content = _render_proxy_build_file(
                actual_repo_name = proxy_repo_name,
                target_names = REPO_PUBLIC_TARGETS[repo_name],
            )

        repository_ctx.file(
            package_name + "/BUILD.bazel",
            build_file_content,
        )
        repository_ctx.file(
            package_name + "/version.bzl",
            _version_bzl_content(component_version),
        )

def _cuda_redist_repository_impl(repository_ctx):

    _write_proxy_packages(repository_ctx)

    repository_ctx.file("BUILD.bazel", "")
    repository_ctx.file(
        "version.bzl",
        "CUDA_VERSION = \"{}\"".format(repository_ctx.attr.cuda_version),
    )

    return repository_ctx.repo_metadata(reproducible = True)

cuda_redist_repository = repository_rule(
    implementation = _cuda_redist_repository_impl,
    attrs = {
        "cuda_version": attr.string(mandatory = True),
        "available_component_mappings": attr.string_dict(mandatory = True),
        "available_component_versions": attr.string_dict(mandatory = True),
    },
)
