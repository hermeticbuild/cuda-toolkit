"""Repository rule for the global curated NVSHMEM repository."""

load("//nvshmem:redist_proxy_targets.bzl", "REPO_PUBLIC_TARGETS")

_CUDA_REPO = "@@cuda_toolkit++cuda+cuda"

def _sanitize_version(version):
    return version.replace(".", "_").replace("-", "_")

def _render_root_build_file(registered_nvshmem_versions, default_cuda_version_to_repo_name):
    lines = [
        "load(\"@bazel_skylib//lib:selects.bzl\", \"selects\")",
        "load(\"@bazel_skylib//rules:common_settings.bzl\", \"string_flag\")",
        "",
        "package(default_visibility = [\"//visibility:public\"])",
        "",
        "string_flag(",
        "    name = \"nvshmem_version\",",
        "    build_setting_default = \"default\",",
        "    visibility = [\"//visibility:public\"],",
        ")",
        "",
        "config_setting(",
        "    name = \"is_nvshmem_default\",",
        "    flag_values = {\":nvshmem_version\": \"default\"},",
        "    visibility = [\"//visibility:public\"],",
        ")",
        "",
    ]

    for version in registered_nvshmem_versions:
        lines.extend([
            "config_setting(",
            "    name = \"is_nvshmem_{}\",".format(_sanitize_version(version)),
            "    flag_values = {\":nvshmem_version\": \"%s\"}," % version,
            "    visibility = [\"//visibility:public\"],",
            ")",
            "",
        ])

    for cuda_version in sorted(default_cuda_version_to_repo_name.keys()):
        lines.extend([
            "selects.config_setting_group(",
            "    name = \"is_nvshmem_default_cuda_{}\",".format(cuda_version),
            "    match_all = [",
            "        \":is_nvshmem_default\",",
            "        \"{}//:is_cuda_{}\",".format(_CUDA_REPO, cuda_version),
            "    ],",
            ")",
            "",
        ])

    return "\n".join(lines)

def _render_package_build_file(registered_nvshmem_versions, version_to_redist_repo_name, default_cuda_version_to_repo_name):
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

        for version in registered_nvshmem_versions:
            lines.append(
                "        \"//:is_nvshmem_{version}\": \"@{repo}//nvshmem:{target}\",".format(
                    version = _sanitize_version(version),
                    repo = version_to_redist_repo_name[version],
                    target = target_name,
                ),
            )

        for cuda_version in sorted(default_cuda_version_to_repo_name.keys()):
            lines.append(
                "        \"//:is_nvshmem_default_cuda_{cuda_version}\": \"@{repo}//nvshmem:{target}\",".format(
                    cuda_version = cuda_version,
                    repo = default_cuda_version_to_repo_name[cuda_version],
                    target = target_name,
                ),
            )

        lines.extend([
            "    }, no_match_error = \"This target is not provided by the selected NVSHMEM version for the active CUDA version\"),",
            ")",
            "",
        ])

    return "\n".join(lines)

def _nvshmem_compat_repository_impl(repository_ctx):
    repository_ctx.file(
        "BUILD.bazel",
        _render_root_build_file(
            registered_nvshmem_versions = repository_ctx.attr.registered_nvshmem_versions,
            default_cuda_version_to_repo_name = repository_ctx.attr.default_cuda_version_to_repo_name,
        ),
    )
    repository_ctx.file(
        "nvshmem/BUILD.bazel",
        _render_package_build_file(
            registered_nvshmem_versions = repository_ctx.attr.registered_nvshmem_versions,
            version_to_redist_repo_name = repository_ctx.attr.version_to_redist_repo_name,
            default_cuda_version_to_repo_name = repository_ctx.attr.default_cuda_version_to_repo_name,
        ),
    )
    return repository_ctx.repo_metadata(reproducible = True)

nvshmem_compat_repository = repository_rule(
    implementation = _nvshmem_compat_repository_impl,
    attrs = {
        "registered_nvshmem_versions": attr.string_list(mandatory = True),
        "version_to_redist_repo_name": attr.string_dict(mandatory = True),
        "default_cuda_version_to_repo_name": attr.string_dict(mandatory = True),
    },
)
