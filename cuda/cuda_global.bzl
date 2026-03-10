"""Repository rule for the global curated CUDA repository."""

load("//cuda:redist_proxy_targets.bzl", "REPO_PUBLIC_TARGETS")

def _sanitize_version(version):
    return version.replace(".", "_").replace("-", "_")

def _proxy_package_name(repo_name):
    return repo_name.removeprefix("cuda_")

def _render_selects_bzl(cuda_versions):
    lines = [
        "load(",
        "    \"@cuda_toolkit//cuda:selects_internal.bzl\",",
        "    _if_cuda_version = \"if_cuda_version\",",
        ")",
        "",
        "CUDA_VERSIONS = [",
    ]

    # We only generate this based on the registered versions to minimize the number 
    # of targets that will be created by _if_cuda_version.
    for version in sorted(cuda_versions):
        lines.append("    \"{}\",".format(version))

    lines.extend([
        "]",
        "",
        "def if_cuda_version(version_expr, if_true, if_false = []):",
        "    return _if_cuda_version(CUDA_VERSIONS, version_expr, if_true, if_false)",
    ])

    return "\n".join(lines)

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

        # add //conditions:default to max version
        # So that if users don't set a constraint, they get max version by default.
        max_version = sorted(version_to_redist_repo_name.keys())[-1]
        lines.append("        \"//conditions:default\": \"@{repo}//{package}:{target}\",".format(
            repo = version_to_redist_repo_name[max_version],
            package = package_name,
            target = target_name,
        ))
        lines.extend([
            "    }),",
            ")",
            "",
        ])

    return "\n".join(lines)

def _render_root_constraints_build(available_cuda_versions, registered_cuda_versions):
    return "\n".join([
        "load(\"@cuda_toolkit//cuda:declare_constraints.bzl\", \"declare_constraints\")",
        "",
        "package(default_visibility = [\"//visibility:public\"])",
        "",
        "declare_constraints(" + repr(available_cuda_versions) + ", " + repr(registered_cuda_versions) + ")",
    ])

def _cuda_global_impl(repository_ctx):
    repository_ctx.template(
        "cuda/BUILD.bazel",
        repository_ctx.attr._cuda_build_file,
    )
    repository_ctx.file(
        "cuda/selects.bzl",
        _render_selects_bzl(repository_ctx.attr.registered_cuda_versions),
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
        _render_root_constraints_build(
            repository_ctx.attr.available_cuda_versions,
            repository_ctx.attr.registered_cuda_versions,
        ),
    )
    return repository_ctx.repo_metadata(reproducible = True)

cuda_global = repository_rule(
    implementation = _cuda_global_impl,
    attrs = {
        "available_cuda_versions": attr.string_list(mandatory = True),
        "registered_cuda_versions": attr.string_list(mandatory = True),
        "version_to_redist_repo_name": attr.string_dict(mandatory = True),
        "_cuda_build_file": attr.label(default = Label("//cuda:cuda.BUILD.bazel")),
    },
)
