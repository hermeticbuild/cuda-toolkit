"""Pin CUDA releases before executable dependencies enter the exec configuration."""

load("@bazel_lib//lib:copy_to_directory.bzl", "copy_to_directory")
load(":cuda_toolchain.bzl", "cuda_toolchain")
load(":exec_binary.bzl", "exec_binary")

def versioned_toolchains(version_to_repo, default_version):
    """Declare fixed-release implementations and the existing selected aliases."""
    selections = {name: {} for name in ["cuda_toolchain", "cuda_path", "bin/ptxas"]}
    for version, repo in version_to_repo.items():
        prefix = "_cuda_" + version.replace(".", "_")
        nvcc = "@{}//nvcc:".format(repo)
        exec_binary(
            name = prefix + "/bin/ptxas",
            actual = nvcc + "ptxas",
        )
        copy_to_directory(
            name = prefix + "/cuda_path",
            srcs = [
                "@{}//cudart:cuda_header".format(repo),
                prefix + "/bin/ptxas",
                "@{}//{}:libdevice".format(repo, "nvvm" if int(version.split(".")[0]) >= 13 else "nvcc"),
            ],
            include_external_repositories = ["**"],
            # Preserve the existing cuda_path layout despite versioned target names.
            replace_prefixes = {prefix + "/": ""},
        )
        cuda_toolchain(
            name = prefix + "/cuda_toolchain",
            cuda_path = prefix + "/cuda_path",
            ptxas = nvcc + "ptxas",
            fatbinary = nvcc + "fatbinary",
        )
        condition = "//:is_cuda_" + version.replace(".", "_")
        for name, selection in selections.items():
            selection[condition] = prefix + "/" + name
            if version == default_version:
                selection["//conditions:default"] = prefix + "/" + name

    for name, selection in selections.items():
        native.alias(name = name, actual = select(selection))
