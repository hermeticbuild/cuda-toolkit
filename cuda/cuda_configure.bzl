"""Repository rule for hermetic CUDA configuration."""

load(
    "//cuda:redist_proxy_targets.bzl",
    "ARCH_REPO_SUFFIX",
    "PROXY_ARCH_CONDITIONS",
    "REPO_PUBLIC_TARGETS",
)

def _concrete_repo_name(repo_prefix, repo_name, arch):
    return "{}_{}__{}".format(repo_prefix, repo_name, ARCH_REPO_SUFFIX[arch])

def _proxy_package_name(repo_name):
    return repo_name.removeprefix("cuda_")

def _version_bzl_content(component_version):
    parts = component_version.split(".") if component_version else []
    version_major = parts[0] if len(parts) > 0 else ""
    version_minor = parts[1] if len(parts) > 1 else ""
    version_patch = parts[2] if len(parts) > 2 else ""
    return """\
IS_PLACEHOLDER = {is_placeholder}
VERSION = "{version}"
VERSION_MAJOR = "{version_major}"
VERSION_MINOR = "{version_minor}"
VERSION_PATCH = "{version_patch}"
LIB_VERSIONS = {{}}
""".format(
        is_placeholder = "False" if component_version else "True",
        version = component_version,
        version_major = version_major,
        version_minor = version_minor,
        version_patch = version_patch,
    )

def _render_proxy_build_file(repo_prefix, repo_name, package_name, target_names, available_arches):
    lines = [
        "package(default_visibility = [\"//visibility:public\"])",
        "",
    ]

    for target_name in target_names:
        select_entries = []
        no_match_error = "@cuda//{}: platform-specific target '{}' unavailable for selected platform".format(
            package_name,
            target_name,
        )
        lines.extend([
            "alias(",
            "    name = \"{}\",".format(target_name),
            "    actual = select({",
        ])
        for arch in sorted(available_arches):
            if arch not in PROXY_ARCH_CONDITIONS:
                continue
            resolved_label = "@@{}//:{}".format(_concrete_repo_name(repo_prefix, repo_name, arch), target_name)
            for config_setting_name in PROXY_ARCH_CONDITIONS[arch]:
                select_entries.append((config_setting_name, resolved_label))

        for (config_setting_name, resolved_label) in select_entries:
            lines.append("        \"{}\": \"{}\",".format(
                config_setting_name,
                resolved_label,
            ))
        lines.extend([
            "    }}, no_match_error = \"{}\"),".format(
                no_match_error,
            ),
            ")",
            "",
        ])
    return "\n".join(lines)

def _write_proxy_packages(repository_ctx):
    for repo_name in sorted(REPO_PUBLIC_TARGETS.keys()):
        component_version = repository_ctx.attr.component_versions.get(repo_name, "")
        if not component_version:
            continue
        available_arches = repository_ctx.attr.component_arches.get(repo_name, [])
        if not available_arches:
            continue
        package_name = _proxy_package_name(repo_name)
        repository_ctx.file(
            "{}/BUILD.bazel".format(package_name),
            _render_proxy_build_file(
                repo_prefix = repository_ctx.name,
                repo_name = repo_name,
                package_name = package_name,
                target_names = REPO_PUBLIC_TARGETS[repo_name],
                available_arches = available_arches,
            ),
        )
        repository_ctx.file(
            "{}/version.bzl".format(package_name),
            _version_bzl_content(component_version),
        )

def _cuda_configure_impl(repository_ctx):
    cuda_version = repository_ctx.attr.cuda_version

    repository_ctx.symlink(
        repository_ctx.attr.build_defs_file,
        "cuda/versions_helper.bzl",
    )
    repository_ctx.file(
        "cuda/cuda_version.bzl",
        "CUDA_VERSION = \"{}\"".format(cuda_version),
    )
    repository_ctx.symlink(
        repository_ctx.attr.cuda_build_file,
        "cuda/BUILD.bazel",
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
        "component_arches": attr.string_list_dict(default = {}),
        "build_defs_file": attr.label(default = Label("//cuda:versions_helper.bzl")),
        "cuda_build_file": attr.label(default = Label("//cuda:cuda.BUILD.bazel")),
    },
)
