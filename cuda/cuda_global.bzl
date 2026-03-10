"""Repository rule for the global curated CUDA repository."""

load("//cuda:redist_proxy_targets.bzl", "REPO_PUBLIC_TARGETS")

def _sanitize_version(version):
    return version.replace(".", "_").replace("-", "_")

def _proxy_package_name(repo_name):
    return repo_name.removeprefix("cuda_")

def _render_component_alias_build_file(package_name, target_names, version_to_redist_repo_name):
    lines = [
        "package(default_visibility = [\"//visibility:public\"])",
        "",
    ]

    for target_name in target_names:
        lines.extend([
            "alias(",
            "    name = \"{}\",".format(target_name),
            "    actual = select({",
        ])

        for version in sorted(version_to_redist_repo_name.keys()):
            lines.append(
                "        \"//:is_cuda_{version}\": \"@{repo}//{package}:{target}\",".format(
                    version = _sanitize_version(version),
                    repo = version_to_redist_repo_name[version],
                    package = package_name,
                    target = target_name,
                ),
            )

        lines.extend([
            "    }}, no_match_error = \"@cuda//{package}:{target} requires selecting a supported CUDA version\"),".format(
                package = package_name,
                target = target_name,
            ),
            ")",
            "",
        ])

    return "\n".join(lines)

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

    for repo_name in sorted(REPO_PUBLIC_TARGETS.keys()):
        package_name = _proxy_package_name(repo_name)
        repository_ctx.file(
            "{package}/BUILD.bazel".format(package = package_name),
            _render_component_alias_build_file(
                package_name = package_name,
                target_names = REPO_PUBLIC_TARGETS[repo_name],
                version_to_redist_repo_name = repository_ctx.attr.version_to_redist_repo_name,
            ),
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
        "version_to_redist_repo_name": attr.string_dict(mandatory = True),
        "_cuda_build_file": attr.label(default = Label("//cuda:cuda.BUILD.bazel")),
    },
)
