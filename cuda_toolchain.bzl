load("@bazel_skylib//rules/directory:providers.bzl", "DirectoryInfo")
load("@cuda_toolchain_types//:cuda_toolchain_info.bzl", "CudaToolchainInfo")

def _cuda_toolchain_impl(ctx):
    if len(ctx.files.cuda_path) != 1:
        fail("cuda_path must produce exactly one output")

    cuda_toolchain = CudaToolchainInfo(
        ptxas = ctx.executable.ptxas,
        fatbinary = ctx.executable.fatbinary,
        cuda_path = ctx.files.cuda_path[0],
    )

    toolchain = platform_common.ToolchainInfo(
        cuda = cuda_toolchain,
    )

    return [
        cuda_toolchain,
        toolchain,
    ]

cuda_toolchain = rule(
    implementation = _cuda_toolchain_impl,
    attrs = {
        "cuda_path": attr.label(
            allow_files = True,
            mandatory = True,
        ),
        "ptxas": attr.label(
            executable = True,
            cfg = "exec",
            allow_files = True,
            mandatory = True,
        ),
        "fatbinary": attr.label(
            executable = True,
            cfg = "exec",
            allow_files = True,
            mandatory = True,
        ),
    },
)
