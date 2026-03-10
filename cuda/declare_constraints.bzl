
load("@bazel_skylib//lib:selects.bzl", "selects")

def _sanitize_version(version):
    return version.replace(".", "_").replace("-", "_")

def declare_constraints(cuda_versions, registered_versions):

    native.constraint_setting(
        name = "cuda_version",
        default_constraint_value = "cuda_{}".format(_sanitize_version(sorted(registered_versions)[-1])),
    )

    major_to_versions = {}
    for version in sorted(cuda_versions):
        version_key = _sanitize_version(version)
        major = version.split(".")[0]
        versions_for_major = major_to_versions.get(major, [])
        versions_for_major.append(version)
        major_to_versions[major] = versions_for_major
        
        native.constraint_value(
            name = "cuda_{}".format(version_key),
            constraint_setting = ":cuda_version",
        )

        native.config_setting(
            name = "is_cuda_{}".format(version_key),
            # If only one version is registered, we make its config_setting always match
            # This so that users don't have to explicitly add a constraint when they only want one version
            constraint_values = [":cuda_{}".format(version_key)]
        )

    for major in sorted(major_to_versions.keys()):
        selects.config_setting_group(
            name = "is_cuda_{}".format(major),
            match_any = [
                ":is_cuda_{}".format(_sanitize_version(version))
                for version in sorted(major_to_versions[major])
            ],
        )
