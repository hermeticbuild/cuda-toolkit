
"""Repository rule for a single CUDA component proxy repository."""

def _normalize_repo_name(repo_name):
    if repo_name.startswith("@"):
        return repo_name[1:]
    return repo_name


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

def _render_build_file(name, targets, platform_repo_mappings):
    lines = [
        "package(default_visibility = [\"//visibility:public\"])",
        "",
    ]

    for target_name in targets:
        lines.extend([
            "alias(",
            "    name = \"{}\",".format(target_name),
            "    actual = select({",
        ])

        for platform in sorted(platform_repo_mappings.keys()):
            repo_name = _normalize_repo_name(platform_repo_mappings[platform])
            lines.append(
                "        \"{}\": \"@{}//:{}\",".format(
                    platform,
                    repo_name,
                    target_name,
                ),
            )

        lines.extend([
            "    }}, no_match_error = \"@cuda//{{}}: platform-specific target '{{}}' unavailable for selected platform\"),".format(
                name,
                target_name,
            ),
            ")",
            "",
        ])

    return "\n".join(lines)

def _cuda_component_proxy_impl(repository_ctx):
    repository_ctx.file(
        "BUILD.bazel",
        _render_build_file(
            name = repository_ctx.attr.name,
            targets = repository_ctx.attr.targets,
            platform_repo_mappings = repository_ctx.attr.platform_repo_mappings,
        ),
    )
    repository_ctx.file(
        "version.bzl",
        _version_bzl_content(repository_ctx.attr.version),
    )

    return repository_ctx.repo_metadata(reproducible = True)

cuda_component_proxy = repository_rule(
    implementation = _cuda_component_proxy_impl,
    attrs = {
        "version": attr.string(
            doc = """Version of the CUDA component being proxied, used for informational purposes.""",
            mandatory = False,
        ),
        "platform_repo_mappings": attr.string_dict(
            doc = """Mapping of config_setting labels to concrete repository names.""",
            mandatory = True,
        ),
        "targets": attr.string_list(
            doc = """List of public targets to re-export from the proxied repository.""",
            mandatory = True,
        ),
    },
)
