"""Repository rule for the global curated CUDA repository."""

load("//cuda:redist_proxy_targets.bzl", "REPO_PUBLIC_TARGETS")
load("//cuda:versions_helper.bzl", "max_version", "sort_versions")

def _sanitize_version(version):
    return version.replace(".", "_").replace("-", "_")

def _proxy_package_name(repo_name):
    return repo_name.removeprefix("cuda_")

def _render_selects_bzl(cuda_versions):
    ordered_cuda_versions = sort_versions(cuda_versions)
    lines = [
        "load(",
        "    \"@cuda_toolkit//cuda:selects_internal.bzl\",",
        "    _expand_cuda_conditions = \"expand_cuda_conditions\",",
        ")",
        "load(\"@bazel_skylib//lib:selects.bzl\", \"selects\")",
        "",
        "CUDA_VERSIONS = [",
    ]

    # We only generate this based on the registered versions to minimize the number 
    # of targets that will be created by _if_cuda_version.
    for version in ordered_cuda_versions:
        lines.append("    \"{}\",".format(version))

    lines.extend([
        "]",
        "",
        "def if_cuda_version(version_expr, if_true, if_false = []):",
        "    labels = tuple([Label(label) for label in _expand_cuda_conditions(CUDA_VERSIONS, version_expr)])",
        "    if not labels:",
        "        return if_false",
        "    return selects.with_or({",
        "        labels: if_true,",
        "        \"//conditions:default\": if_false,",
        "    })",
    ])

    return "\n".join(lines)

def _render_component_alias_build_file(package_name, target_names, version_to_redist_repo_name):
    ordered_versions = sort_versions(version_to_redist_repo_name.keys())
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

        for version in ordered_versions:
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
        selected_max_version = max_version(ordered_versions)
        lines.append("        \"//conditions:default\": \"@{repo}//{package}:{target}\",".format(
            repo = version_to_redist_repo_name[selected_max_version],
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

def _cuda_compat_repository_impl(repository_ctx):
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

cuda_compat_repository = repository_rule(
    implementation = _cuda_compat_repository_impl,
    attrs = {
        "available_cuda_versions": attr.string_list(mandatory = True),
        "registered_cuda_versions": attr.string_list(mandatory = True),
        "version_to_redist_repo_name": attr.string_dict(mandatory = True),
        "_cuda_build_file": attr.label(default = Label("//cuda:cuda.BUILD.bazel")),
    },
)
