"""Repository rule for a single NVSHMEM version proxy repository."""

load("//nvshmem:redist_proxy_targets.bzl", "REPO_PUBLIC_TARGETS")

_CUDA_REPO = "@@cuda_toolkit++cuda+cuda"
_CUDA_TOOLKIT_REPO = "@@cuda_toolkit+"

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

def _combo_condition_name(cuda_version, platform):
    return "is_cuda_{}_{}".format(cuda_version, platform)

def _render_root_build_file(combo_repo_mappings):
    lines = [
        "load(\"@bazel_skylib//lib:selects.bzl\", \"selects\")",
        "",
        "package(default_visibility = [\"//visibility:public\"])",
        "",
    ]

    for combo_key in sorted(combo_repo_mappings.keys()):
        cuda_version, platform = combo_key.split("|")
        lines.extend([
            "selects.config_setting_group(",
            "    name = \"{}\",".format(_combo_condition_name(cuda_version, platform)),
            "    match_all = [",
            "        \"{}//:is_cuda_{}\",".format(_CUDA_REPO, cuda_version),
            "        \"{}//:{}\",".format(_CUDA_TOOLKIT_REPO, platform),
            "    ],",
            ")",
            "",
        ])

    return "\n".join(lines)

def _render_package_build_file(combo_repo_mappings, version):
    lines = [
        "package(default_visibility = [\"//visibility:public\"])",
        "",
    ]

    for target_name in REPO_PUBLIC_TARGETS["nvshmem"]:
        lines.extend([
            "alias(",
            "    name = \"{}\",".format(target_name),
            "    actual = select({",
        ])

        for combo_key in sorted(combo_repo_mappings.keys()):
            cuda_version, platform = combo_key.split("|")
            repo_name = combo_repo_mappings[combo_key]
            lines.append(
                "        \"//:{}\": \"@{}//:{}\",".format(
                    _combo_condition_name(cuda_version, platform),
                    repo_name,
                    target_name,
                ),
            )

        lines.extend([
            "    }}, no_match_error = \"This target is not provided by NVSHMEM {} for the selected CUDA version and platform\"),".format(version),
            ")",
            "",
        ])

    return "\n".join(lines)

def _nvshmem_redist_repository_impl(repository_ctx):
    repository_ctx.file(
        "BUILD.bazel",
        _render_root_build_file(repository_ctx.attr.combo_repo_mappings),
    )
    repository_ctx.file(
        "version.bzl",
        _version_bzl_content(repository_ctx.attr.version),
    )
    repository_ctx.file(
        "nvshmem/BUILD.bazel",
        _render_package_build_file(
            combo_repo_mappings = repository_ctx.attr.combo_repo_mappings,
            version = repository_ctx.attr.version,
        ),
    )
    repository_ctx.file(
        "nvshmem/version.bzl",
        _version_bzl_content(repository_ctx.attr.version),
    )

    return repository_ctx.repo_metadata(reproducible = True)

nvshmem_redist_repository = repository_rule(
    implementation = _nvshmem_redist_repository_impl,
    attrs = {
        "version": attr.string(mandatory = True),
        "combo_repo_mappings": attr.string_dict(mandatory = True),
    },
)
