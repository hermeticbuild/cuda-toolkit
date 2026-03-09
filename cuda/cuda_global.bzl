"""Repository rule for the global curated CUDA repository."""

def _sanitize_version(version):
    return version.replace(".", "_").replace("-", "_")

def _render_root_constraints_build(cuda_versions):
    lines = [
        "load(\"@bazel_skylib//lib:selects.bzl\", \"selects\")",
        "",
        "package(default_visibility = [\"//visibility:public\"])",
        "",
        "constraint_setting(",
        "    name = \"cuda_version\",",
        ")",
        "",
    ]

    major_to_versions = {}
    for version in sorted(cuda_versions):
        version_key = _sanitize_version(version)
        major = version.split(".")[0]
        versions_for_major = major_to_versions.get(major, [])
        versions_for_major.append(version)
        major_to_versions[major] = versions_for_major
        lines.extend([
            "constraint_value(",
            "    name = \"cuda_{}\",".format(version_key),
            "    constraint_setting = \":cuda_version\",",
            ")",
            "",
            "config_setting(",
            "    name = \"is_cuda_{}\",".format(version_key),
            "    constraint_values = [\":cuda_{}\"],".format(version_key),
            ")",
            "",
        ])

    for major in sorted(major_to_versions.keys()):
        lines.extend([
            "selects.config_setting_group(",
            "    name = \"is_cuda_{}\",".format(major),
            "    match_any = [",
        ])
        for version in sorted(major_to_versions[major]):
            lines.append("        \":is_cuda_{}\",".format(_sanitize_version(version)))
        lines.extend([
            "    ],",
            ")",
            "",
        ])

    return "\n".join(lines)

def _cuda_global_impl(repository_ctx):
    repository_ctx.template(
        "cuda/BUILD.bazel",
        repository_ctx.attr._cuda_build_file,
    )
    repository_ctx.file(
        "BUILD.bazel",
        _render_root_constraints_build(repository_ctx.attr.cuda_versions),
    )
    return repository_ctx.repo_metadata(reproducible = True)

cuda_global = repository_rule(
    implementation = _cuda_global_impl,
    attrs = {
        "cuda_versions": attr.string_list(mandatory = True),
        "_cuda_build_file": attr.label(default = Label("//cuda:cuda.BUILD.bazel")),
    },
)
