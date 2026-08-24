"""Repository rule for the global curated CUDA repository."""

load("//cuda:redist_proxy_targets.bzl", "REPO_PUBLIC_TARGETS")
load("//cuda:repository_metadata.bzl", "write_repo_bazel")
load("//cuda:versions_helper.bzl", "max_version", "sort_versions")

_LIBRARY_MODES = [
    "shared",
    "static",
    "system",
]

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

def _render_version_alias(
        lines,
        name,
        package_name,
        target_name,
        ordered_versions,
        version_to_redist_repo_name,
        visibility = None):
    lines.extend([
        "alias(",
        "    name = \"{}\",".format(name),
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

    # If users do not select a CUDA constraint, use the highest registered version.
    selected_max_version = max_version(ordered_versions)
    lines.append("        \"//conditions:default\": \"@{repo}//{package}:{target}\",".format(
        repo = version_to_redist_repo_name[selected_max_version],
        package = package_name,
        target = target_name,
    ))
    lines.append("    }),")
    if visibility:
        lines.append("    visibility = [\"{}\"],".format(visibility))
    lines.extend([
        ")",
        "",
    ])

def _library_mode_targets(target_name, target_names):
    mode_targets = {
        "shared": target_name,
        "static": target_name + "_static",
        "system": target_name + "_system",
    }
    if all([mode_target in target_names for mode_target in mode_targets.values()]):
        return mode_targets
    return None

def _render_library_mode_alias(
        lines,
        target_name,
        mode_targets,
        package_name,
        ordered_versions,
        version_to_redist_repo_name):
    mode_aliases = {}
    for mode in _LIBRARY_MODES:
        mode_alias = "_{}_{}".format(target_name, mode)
        mode_aliases[mode] = mode_alias
        _render_version_alias(
            lines = lines,
            name = mode_alias,
            ordered_versions = ordered_versions,
            package_name = package_name,
            target_name = mode_targets[mode],
            version_to_redist_repo_name = version_to_redist_repo_name,
            visibility = "//visibility:private",
        )

    lines.extend([
        "alias(",
        "    name = \"{}\",".format(target_name),
        "    actual = select({",
    ])
    for mode in _LIBRARY_MODES:
        lines.append(
            "        \"//:library_mode_{mode}\": \":{alias}\",".format(
                alias = mode_aliases[mode],
                mode = mode,
            ),
        )
    lines.extend([
        "    }),",
        ")",
        "",
    ])

def _render_component_alias_build_file(package_name, target_names, version_to_redist_repo_name):
    ordered_versions = sort_versions(version_to_redist_repo_name.keys())
    lines = [
        "package(default_visibility = [\"//visibility:public\"])",
        "",
    ]

    for target_name in target_names:
        mode_targets = _library_mode_targets(target_name, target_names)
        if mode_targets:
            _render_library_mode_alias(
                lines = lines,
                target_name = target_name,
                mode_targets = mode_targets,
                package_name = package_name,
                ordered_versions = ordered_versions,
                version_to_redist_repo_name = version_to_redist_repo_name,
            )
        else:
            _render_version_alias(
                lines = lines,
                name = target_name,
                ordered_versions = ordered_versions,
                package_name = package_name,
                target_name = target_name,
                version_to_redist_repo_name = version_to_redist_repo_name,
            )

    return "\n".join(lines)

def _render_root_constraints_build(available_cuda_versions, registered_cuda_versions):
    lines = [
        "load(\"@bazel_skylib//rules:common_settings.bzl\", \"string_flag\")",
        "load(\"@cuda_toolkit//cuda:declare_constraints.bzl\", \"declare_constraints\")",
        "",
        "package(default_visibility = [\"//visibility:public\"])",
        "",
        "string_flag(",
        "    name = \"library_mode\",",
        "    build_setting_default = \"shared\",",
        "    values = [\"shared\", \"static\", \"system\"],",
        ")",
        "",
    ]
    for mode in _LIBRARY_MODES:
        lines.extend([
            "config_setting(",
            "    name = \"library_mode_{}\",".format(mode),
            "    flag_values = {{\":library_mode\": \"{}\"}},".format(mode),
            ")",
            "",
        ])
    lines.append("declare_constraints(" + repr(available_cuda_versions) + ", " + repr(registered_cuda_versions) + ")")
    return "\n".join(lines)

def _cuda_compat_repository_impl(repository_ctx):
    write_repo_bazel(repository_ctx)
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
        "default_package_metadata": attr.string_list(),
        "registered_cuda_versions": attr.string_list(mandatory = True),
        "version_to_redist_repo_name": attr.string_dict(mandatory = True),
        "_cuda_build_file": attr.label(default = Label("//cuda:cuda.BUILD.bazel")),
    },
)
