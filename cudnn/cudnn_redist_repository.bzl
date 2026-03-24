"""Repository rule for a single CUDA-tagged cuDNN proxy repository."""

load("//cudnn:redist_proxy_targets.bzl", "REPO_PUBLIC_TARGETS")

def _version_bzl_content(component_version):
    parts = component_version.split(".") if component_version else []
    version_major = parts[0] if len(parts) > 0 else ""
    version_minor = parts[1] if len(parts) > 1 else ""
    version_patch = parts[2] if len(parts) > 2 else ""
    version_build = parts[3] if len(parts) > 3 else ""
    return """\
VERSION = "{version}"
VERSION_MAJOR = "{version_major}"
VERSION_MINOR = "{version_minor}"
VERSION_PATCH = "{version_patch}"
VERSION_BUILD = "{version_build}"
LIB_VERSIONS = {{}}
""".format(
        version = component_version,
        version_major = version_major,
        version_minor = version_minor,
        version_patch = version_patch,
        version_build = version_build,
    )

def _render_root_build_file():
    return "\n".join([
        "package(default_visibility = [\"//visibility:public\"])",
        "",
    ])

def _render_package_build_file(platform_repo_mappings, version):
    lines = [
        "package(default_visibility = [\"//visibility:public\"])",
        "",
    ]

    for target_name in REPO_PUBLIC_TARGETS["cudnn"]:
        lines.extend([
            "alias(",
            "    name = \"{}\",".format(target_name),
            "    actual = select({",
        ])

        for config_setting in sorted(platform_repo_mappings.keys()):
            repo_name = platform_repo_mappings[config_setting]
            lines.append(
                "        \"{}\": \"@{}//:{}\",".format(
                    config_setting,
                    repo_name,
                    target_name,
                ),
            )

        lines.extend([
            "    }}, no_match_error = \"This target is not provided by cuDNN {} for the selected CUDA version and platform\"),".format(version),
            ")",
            "",
        ])

    return "\n".join(lines)

def _cudnn_redist_repository_impl(repository_ctx):
    repository_ctx.file(
        "BUILD.bazel",
        _render_root_build_file(),
    )
    repository_ctx.file(
        "version.bzl",
        _version_bzl_content(repository_ctx.attr.version),
    )
    repository_ctx.file(
        "cudnn/BUILD.bazel",
        _render_package_build_file(
            platform_repo_mappings = repository_ctx.attr.platform_repo_mappings,
            version = repository_ctx.attr.version,
        ),
    )
    repository_ctx.file(
        "cudnn/version.bzl",
        _version_bzl_content(repository_ctx.attr.version),
    )

    return repository_ctx.repo_metadata(reproducible = True)

cudnn_redist_repository = repository_rule(
    implementation = _cudnn_redist_repository_impl,
    attrs = {
        "version": attr.string(mandatory = True),
        "platform_repo_mappings": attr.string_dict(mandatory = True),
    },
)
