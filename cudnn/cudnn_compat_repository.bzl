"""Repository rule for the global curated cuDNN repository."""

load("//cudnn:redist_proxy_targets.bzl", "REPO_PUBLIC_TARGETS")

_CUDA_REPO = "@cuda"

def _sanitize_version(version):
    return version.replace(".", "_").replace("-", "_")

def _render_root_build_file():
    return "\n".join([
        "package(default_visibility = [\"//visibility:public\"])",
        "",
    ])

def _render_package_build_file(cuda_version_to_redist_repo_name, default_redist_repo_name):
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

        for version in sorted(cuda_version_to_redist_repo_name.keys()):
            lines.append(
                "        \"{cuda_repo}//:is_cuda_{version}\": \"@{repo}//cudnn:{target}\",".format(
                    cuda_repo = _CUDA_REPO,
                    version = _sanitize_version(version),
                    repo = cuda_version_to_redist_repo_name[version],
                    target = target_name,
                ),
            )

        if default_redist_repo_name:
            lines.append(
                "        \"//conditions:default\": \"@{repo}//cudnn:{target}\",".format(
                    repo = default_redist_repo_name,
                    target = target_name,
                ),
            )

        lines.extend([
            "    }, no_match_error = \"This target is not provided by cuDNN for the selected CUDA version\"),",
            ")",
            "",
        ])

    return "\n".join(lines)

def _cudnn_compat_repository_impl(repository_ctx):
    repository_ctx.file(
        "BUILD.bazel",
        _render_root_build_file(),
    )
    repository_ctx.file(
        "cudnn/BUILD.bazel",
        _render_package_build_file(
            cuda_version_to_redist_repo_name = repository_ctx.attr.cuda_version_to_redist_repo_name,
            default_redist_repo_name = repository_ctx.attr.default_redist_repo_name,
        ),
    )
    return repository_ctx.repo_metadata(reproducible = True)

cudnn_compat_repository = repository_rule(
    implementation = _cudnn_compat_repository_impl,
    attrs = {
        "cuda_version_to_redist_repo_name": attr.string_dict(mandatory = True),
        "default_redist_repo_name": attr.string(),
    },
)
